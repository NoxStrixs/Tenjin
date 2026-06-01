import logging
from typing import Callable

from scripts import build as build_cmd
from scripts.args import add_jobs, add_last_build_args
from scripts.config import BuildConfig
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "analyze"

TOOLS = ["tidy", "memcheck", "massif", "callgrind", "flamegraph"]


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Run static analysis and profiling tools")
    parser.add_argument("tool", choices=TOOLS, help="Analysis tool to run")
    add_last_build_args(parser)
    add_jobs(parser)
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    # All analysis runs against release — no sanitizers, minimal debug overhead.
    args.config = "release"
    cfg         = BuildConfig.from_args(args)
    runner      = DockerRunner(cfg)
    _DISPATCH[args.tool](runner, cfg, args)


# ── Tool implementations ─────────────────────────────────────────────────────
def _clang_tidy(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    logger.warning("Configuring for clang-tidy (compile_commands.json)...")
    runner.run([
        "cmake",
        "-S", ".", "-B", cfg.build_dir,
        "-G", "Ninja",
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
        "-DBUILD_TESTS=ON",
        *cfg.cmake_flags,
    ])

    logger.warning("Running clang-tidy...")
    runner.run([
        "bash", "-c",
        f"set -o pipefail; "
        f"find App Service View -name '*.cpp' | "
        f"xargs clang-tidy -p {cfg.build_dir} 2>&1 | "
        f"grep -v 'warnings generated' | "
        f"grep -v 'Suppressed' | "
        f"grep -v 'Use -header-filter'",
    ])


def _memcheck(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    build_cmd.run_cmd(args)
    logger.warning("Running Valgrind memcheck...")
    runner.run([
        "bash", "-c",
        # Run Tenjin briefly (it'll fail on no display, but we still check the
        # static startup path), then every test binary.
        f"for bin in {cfg.build_dir}/bin/Tenjin; do "
        f"  printf '\\n=== memcheck: %s ===\\n' \"$bin\"; "
        f"  valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all "
        f"  --track-origins=yes --error-exitcode=1 \"$bin\" > /dev/null || true; "
        f"done && "
        f"find {cfg.build_dir}/bin -name '*Test*' -type f -executable | while read bin; do "
        f"  printf '\\n=== memcheck: %s ===\\n' \"$bin\"; "
        f"  valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all "
        f"  --track-origins=yes --error-exitcode=1 \"$bin\" > /dev/null; "
        f"done",
    ])


def _make_valgrind(tool: str, extra_flags: str, post_cmd: str = "") -> Callable:
    """Build a runner for any valgrind tool that takes a single output file."""
    def _run(runner: DockerRunner, cfg: BuildConfig, args) -> None:
        build_cmd.run_cmd(args)
        logger.warning(f"Running Valgrind {tool}...")
        post = (
            f"  {post_cmd} {cfg.build_dir}/{tool}.$name.out | head -80; "
            if post_cmd else ""
        )
        runner.run([
            "bash", "-c",
            f"find {cfg.build_dir}/bin -name '*Benchmark*' -type f -executable | while read bin; do "
            f"  name=$(basename $bin); "
            f"  printf '\\n=== {tool}: %s ===\\n' \"$bin\"; "
            f"  valgrind --tool={tool} {extra_flags} "
            f"  --{tool}-out-file={cfg.build_dir}/{tool}.$name.out \"$bin\" > /dev/null; "
            f"{post}"
            f"done",
        ])
    return _run


def _flamegraph(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    build_cmd.run_cmd(args)
    out_dir = f"{cfg.build_dir}/flamegraphs"
    logger.warning("Generating flame graphs...")
    runner.run([
        "bash", "-c",
        f"""
        set -e
        mkdir -p {out_dir}
        find {cfg.build_dir}/bin -name '*Benchmark*' -type f -executable | while read bin; do
            name=$(basename "$bin")
            echo
            echo "=== flamegraph: $bin ==="
            valgrind --tool=callgrind \\
                --callgrind-out-file={out_dir}/callgrind.$name.out \\
                "$bin" > /dev/null 2>&1

            /opt/FlameGraph/stackcollapse-callgrind.pl \\
                {out_dir}/callgrind.$name.out \\
              | /opt/FlameGraph/flamegraph.pl \\
                > {out_dir}/$name.svg

            echo " → {out_dir}/$name.svg"
        done
        """
    ])
    logger.warning(f"Flame graphs written to {out_dir}/")


_DISPATCH = {
    "tidy":       _clang_tidy,
    "memcheck":   _memcheck,
    "massif":     _make_valgrind("massif",    "--pages-as-heap=yes", "ms_print"),
    "callgrind":  _make_valgrind("callgrind", "",                    "callgrind_annotate"),
    "flamegraph": _flamegraph,
}

import logging

from scripts import build as build_cmd
from scripts.args import add_filter, add_jobs, add_target
from scripts.config import BuildConfig
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "benchmark"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Run Google Benchmark binaries")
    # Benchmarks always run in release — debug timings are misleading.
    add_target(parser)
    add_jobs(parser)
    add_filter(parser, help="Regex filter for benchmark names")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    args.config = "release"

    cfg    = BuildConfig.from_args(args)
    runner = DockerRunner(cfg)

    build_cmd.run_cmd(args)

    filter_flag = f"--benchmark_filter={args.filter}" if args.filter else ""

    logger.warning(f"Running benchmarks for {cfg.target}/release...")
    runner.run([
        "bash", "-c",
        # Find every *Benchmark* binary, run it, and stream Google Benchmark
        # console output. Continues on individual failures (a misbehaving
        # benchmark shouldn't gate the rest).
        f"find {cfg.build_dir}/bin -name '*Benchmark*' -type f -executable | "
        f"while read bin; do "
        f"  echo \"\\n=== $bin ===\"; "
        f"  \"$bin\" {filter_flag} --benchmark_format=console; "
        f"done",
    ])

import logging

from scripts.docker import ensure_image, run
from scripts.targets import TARGETS

logger = logging.getLogger(__name__)

NAME = "format"

# Formatting is source-level and target-agnostic. We always use the linux
# image since clang-format lives there.
_IMAGE      = TARGETS["linux"]["image"]
_DOCKERFILE = TARGETS["linux"]["dockerfile"]

# Source roots. Tests / benchmarks included so contributors don't get drift.
_SOURCES = (
    "find App Service View tests benchmarks "
    "  \\( -name '*.cpp' -o -name '*.hpp' -o -name '*.c' -o -name '*.h' \\) "
    "  -not -path '*/build/*'"
)


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Format source files with clang-format")
    parser.add_argument(
        "--check",
        action = "store_true",
        help   = "Check only; exit non-zero if any files need formatting",
    )
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    ensure_image(_IMAGE, _DOCKERFILE)

    if args.check:
        logger.warning("Checking formatting...")
        run(_IMAGE, ["bash", "-c", f"{_SOURCES} | xargs clang-format --dry-run --Werror"])
    else:
        logger.warning("Formatting source files...")
        run(_IMAGE, ["bash", "-c", f"{_SOURCES} | xargs clang-format -i"])

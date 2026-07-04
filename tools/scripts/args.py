import os

from scripts.targets import DEFAULT_TARGET, LOCAL_TARGETS


def add_target(parser, *, default: str = DEFAULT_TARGET) -> None:
    parser.add_argument(
        "--target",
        choices = list(LOCAL_TARGETS),
        default = default,
        help    = f"Local build target / preset (default: {default})",
    )


def add_jobs(parser) -> None:
    parser.add_argument(
        "--jobs",
        type    = int,
        default = os.cpu_count(),
        help    = f"Parallel jobs (default: {os.cpu_count()})",
    )

import os

from scripts.targets import CONFIGS, DEFAULT_CONFIG, DEFAULT_TARGET, TARGETS


def add_target(parser, *, default: str = DEFAULT_TARGET) -> None:
    parser.add_argument(
        "--target",
        choices = list(TARGETS),
        default = default,
        help    = f"Build target (default: {default})",
    )


def add_config(parser,
               *,
               default: str       = DEFAULT_CONFIG,
               choices: list[str] = CONFIGS) -> None:
    parser.add_argument(
        "--config",
        choices = choices,
        default = default,
        help    = f"Build configuration (default: {default})",
    )


def add_jobs(parser) -> None:
    parser.add_argument(
        "--jobs",
        type    = int,
        default = os.cpu_count(),
        help    = "Parallel jobs (default: cpu count)",
    )

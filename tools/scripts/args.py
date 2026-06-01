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


def add_filter(parser, *, help: str = "Regex filter") -> None:
    parser.add_argument("--filter", default="", help=help)


def add_last_build_args(parser) -> None:
    """Default --target/--config to whatever was last built."""
    # Imported lazily to avoid pulling state into modules that don't need it.
    from scripts.state import load as _load_last
    last_target, last_config = _load_last()
    add_target(parser, default=last_target)
    add_config(parser, default=last_config)

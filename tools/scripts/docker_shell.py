import logging

from scripts.args import add_target
from scripts.config import BuildConfig
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "docker-shell"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Open an interactive shell in a build container")
    add_target(parser)
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    cfg    = BuildConfig.from_target(args.target)
    runner = DockerRunner(cfg)
    logger.warning(f"Opening shell in {cfg.image}...")
    runner.shell()

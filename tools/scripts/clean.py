import logging
import shutil

from scripts.config import ROOT

logger = logging.getLogger(__name__)

NAME = "clean"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Remove all local build directories")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    build_root = ROOT / "build"
    if build_root.exists():
        for child in build_root.iterdir():
            if child.is_dir():
                logger.info("Removing %s", child)
                shutil.rmtree(child)
    else:
        logger.info("Nothing to clean")

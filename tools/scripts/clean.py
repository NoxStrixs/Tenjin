import logging
import shutil

from scripts.config import ROOT
from scripts.docker import ensure_image
from scripts.docker import run as docker_run
from scripts.targets import CONFIGS, TARGETS

logger = logging.getLogger(__name__)

NAME = "clean"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Remove build artifacts")
    parser.add_argument(
        "--target",
        choices = list(TARGETS) + ["all"],
        default = "all",
        help    = "Target to clean (default: all)",
    )
    parser.add_argument(
        "--config",
        choices = CONFIGS + ["all"],
        default = "all",
        help    = "Config to clean (default: all)",
    )
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    targets = list(TARGETS) if args.target == "all" else [args.target]
    configs = CONFIGS       if args.config == "all" else [args.config]

    for target_name in targets:
        for config in configs:
            build_dir_abs = ROOT / "build" / f"{target_name}-{config}"
            if not build_dir_abs.exists():
                continue

            rel = build_dir_abs.relative_to(ROOT)
            logger.info(f"Removing {rel}...")
            try:
                shutil.rmtree(build_dir_abs)
            except PermissionError:
                # Docker creates files as root — fall back to deleting them
                # from inside the container.
                logger.info("Permission denied locally — retrying inside Docker...")
                target = TARGETS[target_name]
                ensure_image(target["image"], target["dockerfile"])
                docker_run(
                    target["image"],
                    ["rm", "-rf", str(rel)],
                    as_root=True,
                )

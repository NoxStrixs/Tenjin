import platform
import os
import logging
import shutil
import subprocess

from scripts import state
from scripts.args import add_config, add_jobs, add_target
from scripts.config import BuildConfig, ROOT
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "build"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Configure and build the project")
    add_target(parser)
    add_config(parser)
    add_jobs(parser)
    parser.add_argument(
        "--clean",
        action = "store_true",
        help   = "Remove build directory before configuring",
    )
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    cfg    = BuildConfig.from_args(args)
    runner = DockerRunner(cfg)

    # Defensive: wipe build dir whenever the underlying Docker image changes.
    # Qt's imported targets (e.g. Qt6::qmlimportscanner) cache absolute paths
    # into the build dir; if the image was rebuilt — say with a different
    # QT_HOST_PATH or a fixed toolchain — those paths can point at stale
    # locations. Detecting "image changed" and clearing the cache is the
    # cheapest way to avoid the qmlimportscanner "Permission denied" recurring.
    if cfg.target == "windows":
        if _docker_image_changed(cfg.image, cfg.build_dir_abs):
            logger.info("Docker image changed; wiping build dir")
            args.clean = True

    if args.clean and cfg.build_dir_abs.exists():
        logger.info(f"Cleaning {cfg.build_dir}...")
        # rm -rf runs inside the container so it can clean root-owned files.
        runner.run(["rm", "-rf", cfg.build_dir])

    if not cfg.configured:
        _configure(runner, cfg)

    logger.info(f"Building {cfg.target}/{cfg.config}...")
    runner.run(["cmake", "--build", cfg.build_dir, "--parallel", str(cfg.jobs)])

    state.save(cfg.target, cfg.config)

def _configure(runner, cfg):
    # Dynamically pick the generator based on target and host
    is_mac = platform.system() == "Darwin"
    generator = ["-G", "Xcode"] if (cfg.target == "ios" and is_mac) else ["-G", "Ninja"]

    # If native on macOS, ensure CMAKE_PREFIX_PATH is set
    env = {}
    if is_mac and cfg.target == "ios":
        env["CMAKE_PREFIX_PATH"] = os.environ.get("CMAKE_PREFIX_PATH", "")

    runner.run([
        "cmake", "-S", ".", "-B", cfg.build_dir,
        *generator, *cfg.cmake_flags
    ], env=env)

def _docker_image_changed(image: str, build_dir_abs) -> bool:
    """True if the Docker image ID differs from the one stamped in build_dir."""
    stamp = build_dir_abs / ".image-id"
    try:
        current = subprocess.check_output(
            ["docker", "inspect", "--format={{.Id}}", image],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

    if not stamp.exists():
        build_dir_abs.mkdir(parents=True, exist_ok=True)
        stamp.write_text(current)
        return False

    previous = stamp.read_text().strip()
    if previous != current:
        stamp.write_text(current)
        return True
    return False

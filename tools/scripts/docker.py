import logging
import os
import subprocess
from pathlib import Path

from scripts.config import ROOT

logger = logging.getLogger(__name__)


def _image_exists(image: str) -> bool:
    result = subprocess.run(
        ["docker", "image", "inspect", image],
        capture_output=True,
    )
    return result.returncode == 0


def build_image(image: str, dockerfile: str) -> None:
    logger.warning(f"Building image '{image}' from {dockerfile}...")
    subprocess.run(
        ["docker", "build", "-f", dockerfile, "-t", image, "."],
        cwd   = ROOT,
        check = True,
    )


def ensure_image(image: str, dockerfile: str) -> None:
    """Build image if absent. Idempotent."""
    if not _image_exists(image):
        build_image(image, dockerfile)


def run(image: str,
        cmd: list[str],
        *,
        interactive: bool = False,
        as_root:     bool = False,
        env:         dict[str, str] | None = None) -> None:
    """Run cmd inside image with the repo bind-mounted at /workspace."""
    docker_flags = ["-it"] if interactive else ["--rm"]
    user_flags   = [] if as_root else ["--user", f"{os.getuid()}:{os.getgid()}"]
    env_flags    = []
    for k, v in (env or {}).items():
        env_flags += ["-e", f"{k}={v}"]

    subprocess.run(
        [
            "docker", "run",
            *docker_flags,
            *user_flags,
            *env_flags,
            "-v", f"{ROOT}:/workspace",
            "-w", "/workspace",
            image,
            *cmd,
        ],
        check = True,
    )


def shell(image: str) -> None:
    run(image, ["bash"], interactive=True)

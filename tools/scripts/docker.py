"""Docker-based reproducible builders for Tenjin packaging.

Docker is the preferred build method: a pinned image per target makes local
builds identical to CI and sidesteps host dependency drift ("dependency hell").
This module builds the images and runs the packaging scripts inside them.

Images:
  linux-appimage   Ubuntu 22.04 (glibc 2.35 baseline) + Qt 6.9.3 -> AppImage

Flatpak is NOT built here: its bubblewrap sandbox does not nest reliably inside
Docker-in-WSL2, so package.py builds Flatpak on the host instead.
"""

import logging
import shutil
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parents[2]
DOCKER_DIR = ROOT / "docker"

IMAGES = {
    "linux-appimage": {
        "dockerfile": "linux-appimage.Dockerfile",
        "tag": "tenjin-appimage:latest",
        "script": "build-appimage.sh",
    },
}


def _require_docker() -> None:
    if shutil.which("docker") is None:
        raise RuntimeError(
            "docker not found on PATH. Install Docker (Desktop or engine) and "
            "ensure it is running. Docker is the supported build method.")


def build_image(name: str) -> None:
    """Build the builder image if the Dockerfile changed (Docker layer-caches)."""
    _require_docker()
    spec = IMAGES[name]
    dockerfile = DOCKER_DIR / spec["dockerfile"]
    if not dockerfile.exists():
        raise FileNotFoundError(f"Missing {dockerfile}")
    logger.info("Building image %s (cached layers reused)…", spec["tag"])
    subprocess.run(
        ["docker", "build", "-f", str(dockerfile), "-t", spec["tag"], str(DOCKER_DIR)],
        check=True)


def run_packaging(name: str) -> None:
    """Run the in-container packaging script against the mounted source tree."""
    _require_docker()
    spec = IMAGES[name]
    script = f"/work/docker/{spec['script']}"
    logger.info("Running %s in %s…", spec["script"], spec["tag"])
    # Mount the repo read-write at /work; artifacts land in /work/dist. --rm so
    # the container is discarded; the image (with Qt) persists for reuse.
    subprocess.run(
        [
            "docker", "run", "--rm",
            # AppImage's FUSE mount needs this; --appimage-extract fallback is
            # used inside the script for validation regardless.
            "--device", "/dev/fuse",
            "--cap-add", "SYS_ADMIN",
            "--security-opt", "apparmor:unconfined",
            "-v", f"{ROOT}:/work",
            spec["tag"],
            "bash", script, "/work",
        ],
        check=True)
    logger.info("Artifacts in %s", ROOT / "dist")

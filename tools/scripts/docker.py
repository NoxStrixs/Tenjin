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


def _ensure_dep_volume(image: str, volume: str) -> None:
    """Create the dependency-cache volume and chown it to the build user once.

    A fresh named volume is root-owned; the non-root build user could not write
    FetchContent output into it. A single root-run mkdir+chown fixes ownership
    for all subsequent non-root runs. Idempotent and cheap.
    """
    subprocess.run(
        [
            "docker", "run", "--rm",
            "-v", f"{volume}:/deps",
            image,
            "sh", "-c",
            f"mkdir -p /deps/fetchcontent && chown -R {os.getuid()}:{os.getgid()} /deps",
        ],
        check = True,
    )


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

    # A named volume for dependency downloads/builds (FetchContent: miniz, etc.).
    # Keeping these off the bind-mounted workspace avoids host/VM clock-skew
    # confusing Ninja ("build.ninja still dirty") and caches deps across runs.
    dep_cache_volume = f"tenjin-deps-{image}"
    if not as_root:
        _ensure_dep_volume(image, dep_cache_volume)

    subprocess.run(
        [
            "docker", "run",
            *docker_flags,
            *user_flags,
            *env_flags,
            "-v", f"{ROOT}:/workspace",
            "-v", f"{dep_cache_volume}:/deps",
            "-e", "FETCHCONTENT_BASE_DIR=/deps/fetchcontent",
            "-w", "/workspace",
            image,
            *cmd,
        ],
        check = True,
    )


def shell(image: str) -> None:
    run(image, ["bash"], interactive=True)

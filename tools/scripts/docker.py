"""Docker-based reproducible builders for Tenjin packaging.

Docker is the preferred build method: a pinned image per target makes local
builds identical to CI and sidesteps host dependency drift ("dependency hell").
This module builds the images and runs the packaging scripts inside them.

Images:
  linux-appimage   Ubuntu 22.04 (glibc 2.35 baseline) + Qt 6.9.3 -> AppImage
  windows-mingw    Ubuntu 24.04 + MinGW-w64 cross toolchain    -> .exe + DLLs
  android          Ubuntu 24.04 + SDK/NDK + Qt Android kits    -> unsigned APK

Flatpak is NOT built here: its bubblewrap sandbox does not nest reliably inside
Docker-in-WSL2, so package.py builds Flatpak on the host instead.

Apple targets (macOS/iOS) cannot be containerised: Xcode is macOS-only and its
licence forbids running it outside Apple hardware. Those still need a Mac host
or the CI workflows.

Caveat on windows-mingw: it cross-compiles with GCC, while CI/release ships an
MSVC build. Use it as a fast local check, not as the shipping binary — the two
toolchains differ in C++ ABI, runtime, and diagnostics (the min/max macro and
C2511-style errors CI catches will NOT show up under MinGW).
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
        # AppImage's FUSE runtime needs elevated device access.
        "needs_fuse": True,
    },
    "windows-mingw": {
        "dockerfile": "windows-mingw.Dockerfile",
        "tag": "tenjin-windows:latest",
        "script": "build-windows.sh",
        "needs_fuse": False,
        # ENTRYPOINT-driven: mounts /src + /out rather than the /work convention.
        "entrypoint_style": True,
    },
    "android": {
        "dockerfile": "android.Dockerfile",
        "tag": "tenjin-android:latest",
        "script": "build-android.sh",
        "needs_fuse": False,
        "entrypoint_style": True,
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


def run_packaging(name: str, extra_cmake_args: list[str] | None = None) -> None:
    """Run the in-container packaging script against the mounted source tree.

    extra_cmake_args are appended after the image ENTRYPOINT; the build-*.sh
    scripts forward "$@" to their cmake configure step, so e.g.
    ["-DTENJIN_MICROTEX_SHA=abc123"] reaches CMake.
    """
    _require_docker()
    spec = IMAGES[name]
    extra_cmake_args = extra_cmake_args or []
    logger.info("Running %s in %s…", spec["script"], spec["tag"])

    if spec.get("entrypoint_style"):
        # windows/android images declare an ENTRYPOINT and expect the source at
        # /src and an output mount at /out. Artifacts land in a per-target
        # build/<name>-release/ directory so each platform's output is separate
        # and lives under build/ alongside the native builds.
        out_dir = ROOT / "build" / f"{name}-release"
        out_dir.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "docker", "run", "--rm",
                "-v", f"{ROOT}:/src",
                "-v", f"{out_dir}:/out",
                spec["tag"],
                *extra_cmake_args,
            ],
            check=True)
        logger.info("Artifacts in %s", out_dir)
        return

    script = f"/work/docker/{spec['script']}"
    # Mount the repo read-write at /work; artifacts land in /work/dist. --rm so
    # the container is discarded; the image (with Qt) persists for reuse.
    cmd = ["docker", "run", "--rm"]
    if spec.get("needs_fuse"):
        # AppImage's FUSE mount needs this; --appimage-extract fallback is
        # used inside the script for validation regardless.
        cmd += ["--device", "/dev/fuse",
                "--cap-add", "SYS_ADMIN",
                "--security-opt", "apparmor:unconfined"]
    cmd += ["-v", f"{ROOT}:/work", spec["tag"], "bash", script, "/work"]
    subprocess.run(cmd, check=True)
    logger.info("Artifacts in %s", ROOT / "dist")

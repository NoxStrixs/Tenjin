"""Produce distributable packages locally.

Targets and how they build:
  appimage   Linux AppImage — built in the linux-appimage Docker image
             (reproducible, glibc 2.35 baseline). Preferred Docker path.
  flatpak    Linux Flatpak  — built on the HOST with flatpak-builder (Flatpak's
             sandbox does not nest in Docker-in-WSL2). Requires flatpak +
             flatpak-builder + the org.kde.Sdk//Platform runtimes.
  macos      macOS .app/.dmg — HOST-ONLY, requires macOS + Xcode. Errors on
             non-Darwin hosts (cannot cross-build Apple targets).
  ios        iOS .ipa       — HOST-ONLY, requires macOS + Xcode.

Windows packaging remains CI-driven (native MSVC) or the existing MinGW cross
image; not reworked here.
"""

import logging
import platform
import shutil
import subprocess
from pathlib import Path

from scripts import docker

logger = logging.getLogger(__name__)

NAME = "package"
ROOT = Path(__file__).resolve().parents[2]
DIST = ROOT / "dist"

TARGETS = ("appimage", "flatpak", "windows", "android", "macos", "ios")


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        NAME, help="Build distributable packages (Docker for Linux; host for Apple)")
    parser.add_argument("--target", choices=TARGETS, default="appimage",
                        help="Package format to build")
    parser.add_argument("-D", "--define", action="append", default=[], metavar="VAR=VALUE",
                        dest="defines",
                        help="Extra -D cmake cache entries, forwarded to the build "
                             "(e.g. -D TENJIN_MICROTEX_SHA=<sha>). Repeatable.")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    DIST.mkdir(exist_ok=True)
    # Normalise "VAR=VALUE" into "-DVAR=VALUE" cmake args.
    cmake_args = [a if a.startswith("-D") else f"-D{a}" for a in getattr(args, "defines", [])]
    if args.target == "appimage":
        _appimage()
    elif args.target == "flatpak":
        _flatpak()
    elif args.target == "windows":
        _windows(cmake_args)
    elif args.target == "android":
        _android(cmake_args)
    elif args.target in ("macos", "ios"):
        _apple(args.target)


def _appimage() -> None:
    logger.info("Building Linux AppImage via Docker (Ubuntu 22.04 / Qt 6.9.3)...")
    docker.build_image("linux-appimage")
    docker.run_packaging("linux-appimage")


def _windows(cmake_args=None) -> None:
    # MinGW cross-build: a local smoke test, not the release artifact. MSVC (what
    # CI ships) can't run in a Linux container, and the two toolchains disagree
    # often enough that a green MinGW build does not guarantee a green CI build.
    logger.info("Building Windows .exe via Docker (MinGW-w64 cross / Qt 6.9.3)...")
    logger.warning("MinGW build for local testing only — CI ships the MSVC build. "
                   "MSVC-specific errors (min/max macros, C2511) will not appear here.")
    docker.build_image("windows-mingw")
    docker.run_packaging("windows-mingw", cmake_args or [])


def _android(cmake_args=None) -> None:
    # Android is cross-compiled from Linux in CI too, so this produces the real
    # artifact — just unsigned.
    logger.info("Building Android APK via Docker (SDK 34 / NDK 26 / Qt 6.9.3)...")
    docker.build_image("android")
    docker.run_packaging("android", cmake_args or [])
    logger.info("APK is unsigned — sign with your keystore before installing.")
    logger.info("AppImage written to %s", DIST)


def _flatpak() -> None:
    if shutil.which("flatpak-builder") is None:
        raise RuntimeError(
            "flatpak-builder not found. Install it on the host:\n"
            "  sudo apt install flatpak flatpak-builder\n"
            "  flatpak remote-add --if-not-exists --user flathub "
            "https://flathub.org/repo/flathub.flatpakrepo\n"
            "  flatpak install --user flathub org.kde.Sdk//6.7 org.kde.Platform//6.7\n"
            "(Flatpak builds on the host, not in Docker -- bubblewrap does not "
            "nest reliably in Docker-in-WSL2.)")
    manifest = ROOT / "packaging" / "flatpak" / "app.tenjin.Tenjin.yml"
    build_dir = ROOT / "build" / "flatpak"
    repo = ROOT / "build" / "flatpak-repo"
    logger.info("Building Flatpak on host via flatpak-builder...")
    subprocess.run(
        ["flatpak-builder", "--force-clean", f"--repo={repo}",
         str(build_dir), str(manifest)],
        check=True)
    bundle = DIST / "Tenjin.flatpak"
    subprocess.run(
        ["flatpak", "build-bundle", str(repo), str(bundle), "app.tenjin.Tenjin"],
        check=True)
    logger.info("Flatpak bundle written to %s", bundle)


def _apple(target: str) -> None:
    if platform.system() != "Darwin":
        raise RuntimeError(
            f"{target} packaging requires a macOS host with Xcode. Apple "
            f"platforms cannot be cross-built from {platform.system()}. Run this "
            f"on a Mac, or use the {target}.yml CI workflow.")
    logger.info("Building %s on host (Xcode)...", target)
    preset = "macos" if target == "macos" else "ios"
    build_dir = ROOT / "build" / preset
    subprocess.run(["cmake", "--preset", preset], check=True)
    subprocess.run(["cmake", "--build", str(build_dir), "--config", "Release"],
                   check=True)
    logger.info("Apple build complete; see %s for the app bundle.", build_dir)

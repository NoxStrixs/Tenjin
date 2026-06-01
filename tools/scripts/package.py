"""
`tool package --target {linux,windows,ios}` — produce a shippable artifact.

Linux:    build/<target>-release/packages/Tenjin-<v>-x86_64.AppImage
          build/<target>-release/packages/Tenjin-<v>-Linux-x86_64.deb
Windows:  build/<target>-release/packages/Tenjin-<v>-Setup.exe
          build/<target>-release/packages/Tenjin-<v>-Windows-x86_64.zip
iOS:      build/ios-release/Tenjin.xcodeproj/   (transfer to a Mac, archive there)
"""

import logging

from scripts import build as build_cmd
from scripts.args import add_jobs, add_target
from scripts.config import BuildConfig, ROOT
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "package"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Build and package a distributable")
    add_target(parser)
    add_jobs(parser)
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    # Packaging is always a release build.
    args.config = "release"
    args.clean  = False

    cfg    = BuildConfig.from_args(args)
    runner = DockerRunner(cfg)

    # 1. Build the binaries.
    build_cmd.run_cmd(args)

    # 2. Linux stages an install tree (used by linuxdeploy for the AppImage);
    #    Windows lets CPack run its own install pass (which triggers
    #    windeployqt via cmake/Packaging.cmake), so no manual stage needed.
    if args.target == "linux":
        stage_dir = f"{cfg.build_dir}/stage"
        logger.warning(f"Staging install tree under {stage_dir}...")
        runner.run([
            "cmake", "--install", cfg.build_dir,
            "--prefix", f"/workspace/{stage_dir}",
        ])

    # 3. Dispatch to per-target packager.
    _DISPATCH[args.target](runner, cfg, args)

    # 4. Print artifact locations.
    pkg_dir = ROOT / cfg.build_dir / "packages"
    if pkg_dir.exists():
        logger.warning("Packages:")
        for f in sorted(pkg_dir.iterdir()):
            logger.warning(f"  → {f.relative_to(ROOT)}")


# ─── Linux ───────────────────────────────────────────────────────────────────
def _package_linux(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    pkg_dir   = f"{cfg.build_dir}/packages"
    stage_dir = f"{cfg.build_dir}/stage"

    logger.warning("Building .deb via CPack...")
    runner.run([
        "bash", "-c",
        f"mkdir -p {pkg_dir} && "
        f"cd {cfg.build_dir} && "
        f"cpack -G DEB -B packages",
    ])

    logger.warning("Building AppImage via linuxdeploy...")
    appdir = f"{cfg.build_dir}/AppDir"
    runner.run([
        "bash", "-c",
        f"rm -rf {appdir} && mkdir -p {appdir}/usr && "
        f"cp -a {stage_dir}/. {appdir}/usr/ && "
        f"cp {appdir}/usr/share/applications/tenjin.desktop {appdir}/ && "
        f"cp {appdir}/usr/share/icons/hicolor/256x256/apps/tenjin.png {appdir}/ && "
        f"cd {pkg_dir} && "
        f"OUTPUT=Tenjin-{cfg.target}-x86_64.AppImage "
        f"linuxdeploy "
        f"  --appdir /workspace/{appdir} "
        f"  --executable /workspace/{appdir}/usr/bin/Tenjin "
        f"  --plugin qt "
        f"  --output appimage",
    ])


# ─── Windows ─────────────────────────────────────────────────────────────────
def _package_windows(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    pkg_dir = f"{cfg.build_dir}/packages"

    # CPack runs its own install pass into a private staging tree, which
    # triggers windeployqt-wine via cmake/Packaging.cmake's install(CODE).
    # That produces the self-contained bin/ tree (exe + Qt DLLs + plugins/ +
    # qml/ + MinGW runtime), then NSIS and ZIP package it.
    logger.warning("Building Windows installer + ZIP via CPack (NSIS + ZIP)...")
    runner.run([
        "bash", "-c",
        f"mkdir -p {pkg_dir} && "
        f"cd {cfg.build_dir} && "
        f"cpack -G 'NSIS;ZIP' -B packages",
    ])


# ─── iOS ─────────────────────────────────────────────────────────────────────
def _package_ios(runner: DockerRunner, cfg: BuildConfig, args) -> None:
    xcodeproj = ROOT / cfg.build_dir / "Tenjin.xcodeproj"

    logger.warning("")
    logger.warning("iOS packaging requires Xcode on macOS.")
    logger.warning("")
    logger.warning("  1. Copy the generated project to a Mac:")
    logger.warning(f"       rsync -a {cfg.build_dir}/ user@mac:~/tenjin-build/")
    logger.warning("")
    logger.warning("  2. On the Mac, archive and export:")
    logger.warning("       cd ~/tenjin-build")
    logger.warning("       xcodebuild -project Tenjin.xcodeproj \\")
    logger.warning("                  -scheme Tenjin \\")
    logger.warning("                  -configuration Release \\")
    logger.warning("                  -sdk iphoneos \\")
    logger.warning("                  -archivePath build/Tenjin.xcarchive archive")
    logger.warning("       xcodebuild -exportArchive \\")
    logger.warning("                  -archivePath build/Tenjin.xcarchive \\")
    logger.warning("                  -exportPath  build/ipa \\")
    logger.warning("                  -exportOptionsPlist ../packaging/ios/ExportOptions.plist")
    logger.warning("")

    if not xcodeproj.exists():
        logger.warning(f"  (No Xcode project at {xcodeproj}. Did `tool build --target ios` succeed?)")


_DISPATCH = {
    "linux":   _package_linux,
    "windows": _package_windows,
    "ios":     _package_ios,
}

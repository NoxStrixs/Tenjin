import logging
import os
import shutil
import subprocess

from scripts import state
from scripts.args import add_jobs, add_target
from scripts.config import ROOT
from scripts.targets import CI_ONLY, LOCAL_TARGETS

logger = logging.getLogger(__name__)

NAME = "build"


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        NAME, help="Configure and build locally via CMake presets (Linux/WSL2)")
    add_target(parser)
    add_jobs(parser)
    parser.add_argument("--clean", action="store_true",
                        help="Remove the preset build dir before configuring")
    parser.add_argument("--lint", action="store_true",
                        help="Run qmllint (all_qmllint target) after building to "
                             "catch QML type/property errors before runtime")
    parser.set_defaults(func=run_cmd)


def _qt_prefix() -> dict[str, str]:
    # aqtinstall lays Qt down at $QT_ROOT/<ver>/gcc_64. Honour an explicit
    # CMAKE_PREFIX_PATH if the developer already exported one; otherwise leave
    # it to the preset/toolchain. Reproducible: CI uses the same 6.8.3 kit.
    env = {}
    prefix = os.environ.get("CMAKE_PREFIX_PATH")
    if prefix:
        env["CMAKE_PREFIX_PATH"] = prefix
    return env


def run_cmd(args) -> None:
    if args.target in CI_ONLY:
        logger.error("%s builds in CI only. Run: gh workflow run %s",
                     args.target, CI_ONLY[args.target])
        raise SystemExit(2)

    preset = LOCAL_TARGETS[args.target]
    build_dir = ROOT / "build" / preset

    if args.clean and build_dir.exists():
        logger.info("Cleaning %s", build_dir)
        shutil.rmtree(build_dir)

    env = {**os.environ, **_qt_prefix()}

    if not (build_dir / "build.ninja").exists():
        logger.info("Configuring preset %s", preset)
        subprocess.run(["cmake", "--preset", preset], cwd=ROOT, env=env, check=True)

    logger.info("Building preset %s", preset)
    subprocess.run(
        ["cmake", "--build", "--preset", preset, "--parallel", str(args.jobs)],
        cwd=ROOT, env=env, check=True,
    )

    if args.lint:
        # qt_add_qml_module auto-generates an `all_qmllint` target (Qt 6.x).
        # Running it catches the class of error that only surfaced at runtime
        # before — e.g. a property named `onFoo` colliding with signal-handler
        # syntax, or a referenced type that isn't a registered QML type. Failing
        # the build here turns a Windows-only "not a type" crash into a local,
        # immediate error with a file and line.
        logger.info("Running qmllint (all_qmllint)")
        subprocess.run(
            ["cmake", "--build", "--preset", preset, "--target", "all_qmllint"],
            cwd=ROOT, env=env, check=True,
        )

    state.save(args.target)

import logging
import subprocess

from scripts.config import ROOT

logger = logging.getLogger(__name__)

NAME = "format"

_DIRS = ["App", "Service", "ViewModels", "View"]
_EXTS = ("*.cpp", "*.hpp", "*.c", "*.h")


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Format C/C++ sources with clang-format")
    parser.add_argument("--check", action="store_true",
                        help="Check only; exit non-zero if any file needs formatting")
    parser.set_defaults(func=run_cmd)


def _sources() -> list[str]:
    files: list[str] = []
    for d in _DIRS:
        root = ROOT / d
        if not root.exists():
            continue
        for ext in _EXTS:
            files += [str(p) for p in root.rglob(ext) if "build" not in p.parts]
    return files


def run_cmd(args) -> None:
    files = _sources()
    if not files:
        logger.info("No sources found")
        return
    cmd = ["clang-format"]
    if args.check:
        logger.info("Checking formatting (%d files)...", len(files))
        cmd += ["--dry-run", "--Werror"]
    else:
        logger.info("Formatting %d files...", len(files))
        cmd += ["-i"]
    subprocess.run(cmd + files, cwd=ROOT, check=True)

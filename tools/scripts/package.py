import logging

from scripts.args import add_target

logger = logging.getLogger(__name__)

NAME = "package"

# Local packaging (DEB/AppImage/NSIS/.ipa) is produced by CI on native runners,
# not in the local dev loop. This command is a signpost until the Stage 3
# release/packaging pipeline lands. Trigger a real build with:
#   gh workflow run <linux|windows|macos|ios|android>.yml
_WORKFLOWS = {
    "linux":   "linux.yml",
    "windows": "windows.yml",
    "macos":   "macos.yml",
    "ios":     "ios.yml",
    "android": "android.yml",
}


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        NAME, help="Show how to produce distributable packages (CI-driven)")
    parser.add_argument("--target", choices=list(_WORKFLOWS), default="linux",
                        help="Platform to package")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    wf = _WORKFLOWS[args.target]
    logger.info("Packaging for %s runs in CI. Trigger it with:", args.target)
    logger.info("  gh workflow run %s", wf)

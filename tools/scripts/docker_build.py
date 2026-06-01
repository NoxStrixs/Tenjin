from scripts.docker import build_image
from scripts.targets import BASE_IMAGE, TARGETS

NAME = "docker-build"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Build Docker development images")
    parser.add_argument(
        "--target",
        choices = list(TARGETS) + ["all"],
        default = "all",
        help    = "Image to build (default: all)",
    )
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    # Base image must always exist first — every target FROMs it.
    build_image(BASE_IMAGE["image"], BASE_IMAGE["dockerfile"])

    targets = list(TARGETS) if args.target == "all" else [args.target]
    for name in targets:
        target = TARGETS[name]
        build_image(target["image"], target["dockerfile"])

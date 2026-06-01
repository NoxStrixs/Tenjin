import logging

from scripts import build as build_cmd
from scripts.args import add_filter, add_jobs, add_last_build_args
from scripts.config import BuildConfig
from scripts.runner import DockerRunner

logger = logging.getLogger(__name__)

NAME = "test"


def register(subparsers) -> None:
    parser = subparsers.add_parser(NAME, help="Build and run tests")
    add_last_build_args(parser)
    add_jobs(parser)
    add_filter(parser, help="GTest filter (e.g. 'DatabaseManagerTest.*')")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    cfg    = BuildConfig.from_args(args)
    runner = DockerRunner(cfg)

    build_cmd.run_cmd(args)

    logger.warning(f"Running tests for {cfg.target}/{cfg.config}...")

    cmd = [
        "ctest",
        "--test-dir",      cfg.build_dir,
        "--output-on-failure",
        "--parallel",      str(cfg.jobs),
    ]
    if args.filter:
        cmd += ["--tests-regex", args.filter]

    runner.run(cmd)

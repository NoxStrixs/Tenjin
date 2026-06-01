import platform
import subprocess
import os
from scripts.config import BuildConfig
from scripts.docker import ensure_image
from scripts.docker import run as _run
from scripts.docker import shell as _shell
from scripts.targets import BASE_IMAGE

class DockerRunner:
    """Runs commands in the target's docker image."""
    def __init__(self, cfg: BuildConfig) -> None:
        self.cfg = cfg
        ensure_image(BASE_IMAGE["image"], BASE_IMAGE["dockerfile"])
        ensure_image(cfg.image,           cfg.dockerfile)

    def run(self, cmd: list[str], *, env: dict[str, str] | None = None) -> None:
        _run(self.cfg.image, cmd, env=env)

    def shell(self) -> None:
        _shell(self.cfg.image)

class NativeRunner:
    """Executes commands directly on the host machine."""
    def __init__(self, cfg: BuildConfig) -> None:
        pass

    def run(self, cmd: list[str], *, env: dict[str, str] | None = None) -> None:
        # Merge current process environment with overrides
        full_env = {**os.environ, **(env or {})}
        subprocess.run(cmd, env=full_env, check=True)

    def shell(self) -> None:
        print("Native host environment — already in shell.")

def get_runner(cfg: BuildConfig):
    """Factory: Returns DockerRunner for Linux, NativeRunner for macOS."""
    if platform.system() == "Darwin":
        return NativeRunner(cfg)
    return DockerRunner(cfg)

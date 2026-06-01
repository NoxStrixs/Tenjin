import os
from dataclasses import dataclass, field
from pathlib import Path

from scripts.targets import (
    CONFIG_CMAKE_FLAGS,
    TARGETS,
)

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class BuildConfig:
    target: str
    config: str
    jobs:   int  = field(default_factory=os.cpu_count)
    clean:  bool = False

    @property
    def target_info(self) -> dict:
        return TARGETS[self.target]

    @property
    def image(self) -> str:
        return self.target_info["image"]

    @property
    def dockerfile(self) -> str:
        return self.target_info["dockerfile"]

    @property
    def native(self) -> bool:
        return self.target_info.get("native", False)

    @property
    def build_dir(self) -> str:
        # Relative path — the container sees it under /workspace/.
        return f"build/{self.target}-{self.config}"

    @property
    def build_dir_abs(self) -> Path:
        return ROOT / self.build_dir

    @property
    def configured(self) -> bool:
        # Ninja generator drops build.ninja; Xcode drops *.xcodeproj.
        return ((self.build_dir_abs / "build.ninja").exists()
                or any(self.build_dir_abs.glob("*.xcodeproj")))

    @property
    def cmake_flags(self) -> list[str]:
        flags = list(CONFIG_CMAKE_FLAGS[self.config])

        # Sanitizers only run on native targets. Strip the option if we'd
        # otherwise hand a non-native compiler nonsense flags.
        if not self.native:
            flags = [f for f in flags if not f.startswith("-DSANITIZERS")]

        # Tests and benchmarks are not part of this build tooling; always off.
        flags.append("-DBUILD_TESTS=OFF")
        flags.append("-DBUILD_BENCHMARKS=OFF")

        flags.extend(self.target_info["cmake_args"])
        return flags

    @classmethod
    def from_args(cls, args) -> "BuildConfig":
        return cls(
            target = args.target,
            config = args.config,
            jobs   = getattr(args, "jobs",  os.cpu_count()),
            clean  = getattr(args, "clean", False),
        )

    @classmethod
    def from_target(cls, target: str) -> "BuildConfig":
        return cls(target=target, config="debug")

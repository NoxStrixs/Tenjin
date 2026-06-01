import os
from dataclasses import dataclass, field
from pathlib import Path

from scripts.targets import (
    CONFIG_CMAKE_FLAGS,
    CONFIGS_WITH_BENCHMARKS,
    CONFIGS_WITH_TESTS,
    TARGETS,
)

# scripts/ lives under tools/scripts/, so the repo root is 2 levels up.
ROOT = Path(__file__).resolve().parents[2]


@dataclass
class BuildConfig:
    target: str
    config: str
    jobs:   int  = field(default_factory=os.cpu_count)
    clean:  bool = False

    # ── Target / image ─────────────────────────────────────────────────────
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

    # ── Build directory ────────────────────────────────────────────────────
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

    # ── CMake flags ────────────────────────────────────────────────────────
    @property
    def cmake_flags(self) -> list[str]:
        flags = list(CONFIG_CMAKE_FLAGS[self.config])

        # Sanitizers only run on native targets. Strip the option if we'd
        # otherwise hand a non-native compiler nonsense flags.
        if not self.native:
            flags = [f for f in flags if not f.startswith("-DSANITIZERS")]

        # Tests / benchmarks gated by config, not target — every supported
        # target picks them up uniformly.
        flags.append(
            f"-DBUILD_TESTS={'ON' if self.native and self.config in CONFIGS_WITH_TESTS else 'OFF'}"
        )
        flags.append(
            f"-DBUILD_BENCHMARKS={'ON' if self.native and self.config in CONFIGS_WITH_BENCHMARKS else 'OFF'}"
        )

        flags.extend(self.target_info["cmake_args"])
        return flags

    # ── Constructors ───────────────────────────────────────────────────────
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

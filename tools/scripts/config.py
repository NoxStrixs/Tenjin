import os
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from scripts.targets import (
    CONFIG_CMAKE_FLAGS,
    TARGETS,
)

ROOT = Path(__file__).resolve().parents[2]


_DEFAULTS = {
    "TENJIN_APP_NAME":              "Tenjin",
    "TENJIN_APP_DISPLAY_NAME":      "Tenjin",
    "TENJIN_APP_VERSION":           "0.1.0",
    "TENJIN_BUNDLE_ID":             "app.tenjin.Tenjin",
    "TENJIN_ORG_NAME":              "Tenjin",
    "TENJIN_ORG_DOMAIN":            "tenjin.app",
    "TENJIN_APP_DESCRIPTION":       "Personal vocabulary and spaced-repetition app",
    "TENJIN_APP_KEYWORDS":          "vocabulary;flashcards;learning;languages",
    "TENJIN_APP_CATEGORIES":        "Education;Languages;",
    "TENJIN_IOS_DEPLOYMENT_TARGET": "16.0",
}

@lru_cache(maxsize=1)
def dotenv() -> dict[str, str]:
    values = dict(_DEFAULTS)
    env_path = ROOT / ".env"
    if not env_path.exists():
        return values

    for raw in env_path.read_text().splitlines():
        line = raw.lstrip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        if not key or not key.replace("_", "").isalnum():
            continue
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
            val = val[1:-1]
        values[key] = val
    return values


def app_name()     -> str: return dotenv()["TENJIN_APP_NAME"]
def display_name() -> str: return dotenv()["TENJIN_APP_DISPLAY_NAME"]
def app_version()  -> str: return dotenv()["TENJIN_APP_VERSION"]
def bundle_id()    -> str: return dotenv()["TENJIN_BUNDLE_ID"]


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


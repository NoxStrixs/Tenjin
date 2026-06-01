from configparser import ConfigParser
from pathlib import Path

from scripts.config import ROOT
from scripts.targets import DEFAULT_CONFIG, DEFAULT_TARGET

_STATE_FILE = ROOT / "build" / ".last"
_SECTION    = "last"


def save(target: str, config: str) -> None:
    _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    cfg = ConfigParser()
    cfg[_SECTION] = {"target": target, "config": config}
    with open(_STATE_FILE, "w") as f:
        cfg.write(f)


def load() -> tuple[str, str]:
    if not _STATE_FILE.exists():
        return DEFAULT_TARGET, DEFAULT_CONFIG
    cfg = ConfigParser()
    cfg.read(_STATE_FILE)
    section = cfg[_SECTION] if cfg.has_section(_SECTION) else {}
    return (
        section.get("target", DEFAULT_TARGET),
        section.get("config", DEFAULT_CONFIG),
    )

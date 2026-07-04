from functools import lru_cache
from pathlib import Path

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
        if not line or line.startswith("#") or "=" not in line:
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

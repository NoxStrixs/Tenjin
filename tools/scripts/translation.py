import logging

from scripts.config import ROOT
from scripts.docker import ensure_image, run
from scripts.targets import TARGETS

logger = logging.getLogger(__name__)

NAME = "translation"

# Run inside the linux image -- it has Qt's lupdate/lrelease and pip can
# install argostranslate cleanly. Same pattern as `tool format`.
_IMAGE      = TARGETS["linux"]["image"]
_DOCKERFILE = TARGETS["linux"]["dockerfile"]

# Languages we ship .qm files for. Mirrors TENJIN_UI_LANGUAGES in
# cmake/Translations.cmake. Update both together when adding a locale.
_LANGUAGES = ["ja", "es", "fr", "de", "zh_CN", "pt", "ko", "it", "ru", "ar"]

# Qt locale -> Argos package code (mostly identical).
_ARGOS_CODE = {"zh_CN": "zh", "zh_TW": "zt"}


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        NAME,
        help="Refresh translations: lupdate -> machine-translate via Argos -> lrelease",
    )
    parser.add_argument(
        "--lang",
        action  = "append",
        default = None,
        help    = "Only process this language (repeatable). Default: all.",
    )
    parser.add_argument(
        "--no-translate",
        action = "store_true",
        help   = "Skip Argos; only run lupdate + lrelease.",
    )
    parser.add_argument(
        "--force",
        action = "store_true",
        help   = "Re-translate every entry, even ones already filled.",
    )
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    ensure_image(_IMAGE, _DOCKERFILE)

    langs = args.lang if args.lang else _LANGUAGES
    bad = [l for l in langs if l not in _LANGUAGES]
    if bad:
        logger.error(f"Unknown language(s): {bad}. Known: {_LANGUAGES}")
        raise SystemExit(2)

    # 1. lupdate -- extract qsTr() strings into translations/tenjin_<lang>.ts.
    # We invoke lupdate directly (not via the cmake target) so this
    # command works even before the project has been configured.
    logger.warning("Running lupdate to extract qsTr() strings...")
    (ROOT / "translations").mkdir(exist_ok=True)
    sources = "App Service ViewModels View"
    ts_args = " ".join(f"-ts translations/tenjin_{l}.ts" for l in langs)
    run(_IMAGE, [
        "bash", "-c",
        f"lupdate -locations none -no-obsolete {sources} {ts_args}",
    ])

    # 2. Argos -- machine-translate empty entries. Skipped on --no-translate.
    if not args.no_translate:
        logger.warning("Translating empty entries via Argos...")
        script = _argos_script(langs, force=args.force)
        # The script handles its own pip install. Keeping it inline (heredoc)
        # avoids adding a third file just for ~80 lines of Python.
        run(_IMAGE, ["bash", "-c", f"python3 -c {_shquote(script)}"])
    else:
        logger.info("Skipping Argos translation (--no-translate).")

    # 3. lrelease -- compile .ts -> .qm. Optional: the regular cmake build
    # also runs lrelease via qt_add_translations. Running it here gives
    # immediate feedback that the .ts files are syntactically valid.
    logger.warning("Running lrelease to compile .ts -> .qm...")
    ts_inputs = " ".join(f"translations/tenjin_{l}.ts" for l in langs)
    run(_IMAGE, ["bash", "-c", f"lrelease {ts_inputs}"])

    logger.info(
        f"Done. Refreshed {len(langs)} language(s): {langs}. "
        f"Commit translations/*.ts so CI picks them up."
    )


def _shquote(s: str) -> str:
    # Single-quote for bash -c '...'. Escape embedded single quotes the
    # POSIX-portable way: ' -> '\''
    return "'" + s.replace("'", "'\\''") + "'"


def _argos_script(langs: list[str], force: bool) -> str:
    """The translator. Inlined so we don't ship a fourth file."""
    argos_codes = [_ARGOS_CODE.get(l, l) for l in langs]
    return f'''
import re, subprocess, sys
import xml.etree.ElementTree as ET
from pathlib import Path

LANGS       = {langs!r}
ARGOS_CODES = dict(zip({langs!r}, {argos_codes!r}))
FORCE       = {force!r}
TS_DIR      = Path("/workspace/translations")

try:
    import argostranslate.package, argostranslate.translate
except ImportError:
    print("Installing argostranslate (one-time)...", flush=True)
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "--quiet", "--break-system-packages", "argostranslate"],
    )
    import argostranslate.package, argostranslate.translate

# Determine which languages still need work, so we don't pull a 150MB
# language pack we won't use.
def needs_work(path):
    if FORCE: return True
    try:
        tree = ET.parse(path)
    except (ET.ParseError, FileNotFoundError):
        return False
    for msg in tree.getroot().iter("message"):
        t = msg.find("translation")
        if t is None: continue
        if (not (t.text or "").strip()) or t.get("type") == "unfinished":
            return True
    return False

todo = [l for l in LANGS if needs_work(TS_DIR / f"tenjin_{{l}}.ts")]
if not todo:
    print("All translations complete; nothing to do.")
    sys.exit(0)
print(f"Will translate: {{todo}}", flush=True)

# Install missing Argos packages.
argostranslate.package.update_package_index()
available = argostranslate.package.get_available_packages()
installed = {{(p.from_code, p.to_code) for p in argostranslate.package.get_installed_packages()}}
for l in todo:
    ac = ARGOS_CODES[l]
    if ("en", ac) in installed: continue
    match = next((p for p in available if p.from_code == "en" and p.to_code == ac), None)
    if not match:
        print(f"  [warn] en->{{ac}} not in Argos index, skipping {{l}}", file=sys.stderr)
        continue
    print(f"  installing en->{{ac}}...", flush=True)
    argostranslate.package.install_from_path(match.download())

langs_obj = argostranslate.translate.get_installed_languages()
src       = next((x for x in langs_obj if x.code == "en"), None)

for l in todo:
    p = TS_DIR / f"tenjin_{{l}}.ts"
    if not p.exists():
        print(f"  [skip] {{p}}: not found")
        continue
    ac  = ARGOS_CODES[l]
    dst = next((x for x in langs_obj if x.code == ac), None)
    if not src or not dst:
        print(f"  [skip] {{l}}: en->{{ac}} pkg not installed")
        continue
    tr  = src.get_translation(dst)
    tree = ET.parse(p)
    root = tree.getroot()
    filled = 0
    for msg in root.iter("message"):
        s = msg.find("source")
        t = msg.find("translation")
        if s is None or t is None or not s.text:
            continue
        existing  = (t.text or "").strip()
        unfinish  = t.get("type") == "unfinished"
        if existing and not unfinish and not FORCE:
            continue
        try:
            out = tr.translate(s.text)
        except Exception as e:
            print(f"  [warn] {{s.text[:40]!r}}: {{e}}", file=sys.stderr)
            continue
        # Preserve %1-style placeholders Argos sometimes drops.
        for ph in re.findall(r"%\\d", s.text):
            if ph not in out:
                out = (out + " " + ph).strip()
        t.text = out
        t.attrib.pop("type", None)
        filled += 1
    if filled > 0:
        with p.open("wb") as f:
            f.write(b'<?xml version="1.0" encoding="utf-8"?>\\n')
            f.write(b'<!DOCTYPE TS>\\n')
            tree.write(f, encoding="utf-8", xml_declaration=False)
    print(f"  tenjin_{{l}}.ts: {{filled}} entries filled")

print("Translation pass complete.")
'''


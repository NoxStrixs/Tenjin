#!/usr/bin/env python3
"""Verify (and optionally regenerate) the icon codepoints in TenjinIcons.qml.

The Material Symbols variable font reassigns some legacy Material *Icons*
codepoints, so a codepoint that rendered correctly years ago may now point at a
different glyph (e.g. e5ca was `check` in Material Icons but is unassigned in
Material Symbols; ec1a is `energy_savings_leaf`, not `book_2`). This script is
the single source of truth that keeps TenjinIcons.qml honest.

It cross-checks every glyph declared in TenjinIcons.qml against the official
`.codepoints` index shipped alongside the font:

    name  ->  hex codepoint

A glyph entry in the QML looks like:

    readonly property string words: "\\uf53e"   // book_2

The trailing `// <name>` comment is treated as the *intended* icon name, and we
assert that the font maps that name to exactly the codepoint in the string.

Usage:
    verify_icons.py --check     # exit non-zero on any mismatch (CI default)
    verify_icons.py --fix       # rewrite codepoints to match the .codepoints file

The codepoints file is located automatically next to the bundled font, or via
--codepoints. Download the font + codepoints with the build system, or grab the
file from:
    https://github.com/google/material-design-icons/tree/master/variablefont
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# A QML glyph line:  readonly property string NAME: "\uXXXX"  // icon_name
_GLYPH_RE = re.compile(
    r'readonly\s+property\s+string\s+(?P<prop>\w+)\s*:\s*'
    r'"(?P<glyph>(?:\\u[0-9a-fA-F]{4})+)"'
    r'\s*//\s*(?P<name>[a-z0-9_]+)'
)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _default_qml() -> Path:
    return _repo_root() / "View" / "TenjinIcons.qml"


def _default_codepoints() -> Path | None:
    fonts = _repo_root() / "View" / "fonts"
    for cand in (
        fonts / "MaterialSymbolsOutlined.codepoints",
        fonts / "MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].codepoints",
    ):
        if cand.exists():
            return cand
    found = sorted(fonts.glob("*.codepoints"))
    return found[0] if found else None


def load_codepoints(path: Path) -> dict[str, str]:
    """Parse a `name hex` per-line .codepoints file into {name: 'ffff'}."""
    table: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or " " not in line:
            continue
        name, code = line.split(None, 1)
        table[name.strip()] = code.strip().lower()
    return table


def _glyph_to_hex(glyph: str) -> str:
    """'\\uf53e' -> 'f53e'  (multi-codepoint glyphs joined, though icons are single)."""
    parts = re.findall(r'\\u([0-9a-fA-F]{4})', glyph)
    return "".join(p.lower() for p in parts)


def scan_qml(path: Path) -> list[tuple[str, str, str, str]]:
    """Return list of (property, intended_name, declared_hex, raw_glyph)."""
    out = []
    for m in _GLYPH_RE.finditer(path.read_text(encoding="utf-8")):
        out.append(
            (m["prop"], m["name"], _glyph_to_hex(m["glyph"]), m["glyph"])
        )
    return out


def verify(qml: Path, table: dict[str, str]) -> list[str]:
    """Return a list of human-readable problems (empty == all good)."""
    problems: list[str] = []
    for prop, name, declared, _ in scan_qml(qml):
        if name not in table:
            problems.append(
                f"{prop}: intended icon '{name}' is NOT in the font "
                f"(declared U+{declared})"
            )
            continue
        expected = table[name]
        if declared != expected:
            problems.append(
                f"{prop}: '{name}' should be U+{expected} but is U+{declared}"
            )
    return problems


def fix(qml: Path, table: dict[str, str]) -> int:
    """Rewrite declared codepoints to the font's value. Returns # of changes."""
    text = qml.read_text(encoding="utf-8")
    changes = 0

    def _repl(m: re.Match) -> str:
        nonlocal changes
        name = m["name"]
        if name not in table:
            return m.group(0)  # leave unknown names for the report to flag
        want = table[name]
        if _glyph_to_hex(m["glyph"]) == want:
            return m.group(0)
        changes += 1
        new_glyph = "\\u" + want
        return m.group(0).replace(m["glyph"], new_glyph, 1)

    text = _GLYPH_RE.sub(_repl, text)
    if changes:
        qml.write_text(text, encoding="utf-8")
    return changes


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--qml", type=Path, default=_default_qml())
    ap.add_argument("--codepoints", type=Path, default=None)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--check", action="store_true",
                   help="verify only; non-zero exit on mismatch (default)")
    g.add_argument("--fix", action="store_true",
                   help="rewrite codepoints to match the font")
    args = ap.parse_args(argv)
    return _execute(args)


# ── tool harness integration (tools/tool verify-icons ...) ───────────────────
NAME = "verify-icons"


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        NAME, help="Verify TenjinIcons.qml glyphs against the font .codepoints")
    parser.add_argument("--qml", type=Path, default=_default_qml())
    parser.add_argument("--codepoints", type=Path, default=None)
    grp = parser.add_mutually_exclusive_group()
    grp.add_argument("--check", action="store_true",
                     help="verify only; non-zero exit on mismatch (default)")
    grp.add_argument("--fix", action="store_true",
                     help="rewrite codepoints to match the font")
    parser.set_defaults(func=run_cmd)


def run_cmd(args) -> None:
    rc = _execute(args)
    if rc != 0:
        raise SystemExit(rc)


def _execute(args) -> int:
    cp = args.codepoints or _default_codepoints()
    if cp is None or not cp.exists():
        print("error: .codepoints file not found. Pass --codepoints PATH or "
              "place it in View/fonts/. The build downloads it alongside the "
              "font; see cmake/IconFont.cmake.", file=sys.stderr)
        return 2
    if not args.qml.exists():
        print(f"error: {args.qml} not found", file=sys.stderr)
        return 2

    table = load_codepoints(cp)

    if getattr(args, "fix", False):
        n = fix(args.qml, table)
        print(f"verify_icons: fixed {n} codepoint(s) in {args.qml.name}")

    problems = verify(args.qml, table)
    if problems:
        print(f"verify_icons: {len(problems)} problem(s) in {args.qml.name}:",
              file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1

    n = len(scan_qml(args.qml))
    print(f"verify_icons: OK — all {n} glyph(s) match the font.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

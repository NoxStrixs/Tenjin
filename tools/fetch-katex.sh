#!/usr/bin/env bash
# Fetch the KaTeX distribution and vendor it under View/katex/ so formula
# rendering works fully offline (assets are compiled into the binary via the
# qrc resource declared in View/CMakeLists.txt).
#
# Run once from anywhere:   tools/fetch-katex.sh [version]
# Default version is pinned below; override by passing an arg.
#
# Requires: curl, unzip. Network access to github.com (release tarball).

set -euo pipefail

KATEX_VERSION="${1:-0.16.11}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/../View/katex"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/KaTeX/KaTeX/releases/download/v${KATEX_VERSION}/katex.zip"

echo "Fetching KaTeX v${KATEX_VERSION} ..."
curl -fsSL "$URL" -o "$TMP/katex.zip"

echo "Unpacking ..."
unzip -q "$TMP/katex.zip" -d "$TMP"
# The zip extracts to a top-level 'katex/' directory.

echo "Installing into $DEST ..."
rm -rf "$DEST"
mkdir -p "$DEST"
# Only the runtime assets are needed: the minified JS/CSS and the fonts dir.
cp "$TMP/katex/katex.min.js"  "$DEST/"
cp "$TMP/katex/katex.min.css" "$DEST/"
cp -r "$TMP/katex/fonts"      "$DEST/"

echo "Done. Bundled files:"
find "$DEST" -type f | sed "s#${DEST}/#  katex/#"
echo
echo "Re-run CMake configure so the qrc resource picks these up:"
echo "  cmake -S . -B build   (or your usual configure command)"

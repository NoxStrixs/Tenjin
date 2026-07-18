#!/usr/bin/env bash
# Cross-compile Tenjin for Windows with MinGW-w64 inside the container.
# Mounted: /src (repo, read-only-ish) and /out (artifacts land here).
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/tmp/build-windows}"
OUT_DIR="${OUT_DIR:-/out}"
QT_TARGET="${QT_TARGET:?QT_TARGET not set}"
QT_HOST="${QT_HOST:?QT_HOST not set}"

echo "==> Configuring (MinGW-w64 cross, Qt ${QT_VERSION})"
cmake -S /src -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
    -DCMAKE_FIND_ROOT_PATH="${QT_TARGET}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_PREFIX_PATH="${QT_TARGET}" \
    -DQT_HOST_PATH="${QT_HOST}" \
    -DSANITIZERS="" \
    "$@"

echo "==> Building"
cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo "==> Collecting artifacts"
APPDIR="${OUT_DIR}/Tenjin-windows"
mkdir -p "${APPDIR}"
EXE="$(find "${BUILD_DIR}" -name Tenjin.exe -print -quit)"
if [ -z "${EXE}" ]; then
    echo "ERROR: Tenjin.exe not found under ${BUILD_DIR}" >&2
    exit 1
fi
cp "${EXE}" "${APPDIR}/"

# Resolve the app's DLL dependencies by walking the PE import table with objdump
# and following it recursively — the same principle windeployqt uses, but native
# on Linux, so no Wine is needed (Wine under a cross-build container is heavy and
# fragile). We search the Qt bin dir and the MinGW sysroot; anything found there
# gets copied and its own imports scanned in turn. System DLLs (kernel32, etc.)
# aren't in those dirs, so they're naturally skipped.
OBJDUMP=x86_64-w64-mingw32-objdump
# Directories that hold DLLs we're allowed to bundle.
SEARCH_DIRS=("${QT_TARGET}/bin")
while IFS= read -r d; do SEARCH_DIRS+=("$d"); done < <(
    find / -type d -path "*mingw*/bin" 2>/dev/null | sort -u)

find_dll() {
    local name="$1"
    for d in "${SEARCH_DIRS[@]}"; do
        # case-insensitive: PE import names casing doesn't always match the file
        local hit
        hit="$(find "$d" -maxdepth 1 -iname "$name" -print -quit 2>/dev/null || true)"
        [ -n "$hit" ] && { echo "$hit"; return 0; }
    done
    return 1
}

echo "==> Walking DLL dependencies (objdump)"
declare -A SEEN
walk() {
    local pe="$1"
    local dep
    while IFS= read -r dep; do
        # normalise to lowercase key for the seen-set
        local key="${dep,,}"
        [ -n "${SEEN[$key]:-}" ] && continue
        SEEN[$key]=1
        local src
        if src="$(find_dll "$dep")"; then
            cp -n "$src" "${APPDIR}/" 2>/dev/null || true
            walk "$src"
        fi
    done < <("${OBJDUMP}" -p "$pe" 2>/dev/null \
                 | awk '/DLL Name:/ {print $3}')
}
walk "${APPDIR}/Tenjin.exe"
echo "    bundled $(find "${APPDIR}" -maxdepth 1 -name '*.dll' | wc -l) DLLs"

# Qt plugins aren't PE-imported by the exe (they're loaded at runtime), so
# objdump won't see them — copy the categories the app needs by hand, then walk
# each plugin's own imports too (they can pull extra DLLs).
echo "==> Bundling Qt plugins"
for plugdir in platforms styles imageformats iconengines sqldrivers tls \
               multimedia networkinformation; do
    if [ -d "${QT_TARGET}/plugins/${plugdir}" ]; then
        mkdir -p "${APPDIR}/${plugdir}"
        for p in "${QT_TARGET}/plugins/${plugdir}/"*.dll; do
            [ -f "$p" ] || continue
            cp -n "$p" "${APPDIR}/${plugdir}/"
            walk "$p"   # a plugin may need DLLs the exe didn't
        done
    fi
done

# QML: our own module is compiled in, but Qt's QML modules (QtQuick, Controls,
# etc.) ship as plugin DLLs + qmldir metadata that must sit under a qml/ tree.
# Copy the whole qml dir — coarse but reliable — and walk the plugin imports.
echo "==> Bundling QML modules"
if [ -d "${QT_TARGET}/qml" ]; then
    cp -r "${QT_TARGET}/qml" "${APPDIR}/"
    while IFS= read -r qmlplugin; do
        walk "$qmlplugin"
    done < <(find "${APPDIR}/qml" -name '*.dll')
    # re-copy any newly discovered DLLs that the QML plugins need
    for key in "${!SEEN[@]}"; do
        if src="$(find_dll "$key")"; then cp -n "$src" "${APPDIR}/" 2>/dev/null || true; fi
    done
fi

# Optional NSIS installer. makensis is native on Linux (no Wine), but note the
# CPack Windows config expects a pre-staged install tree (it's built around CI's
# windeployqt step). Locally the reliable deliverable is the folder above with a
# complete DLL set; this NSIS attempt is best-effort convenience. The signed,
# authoritative installer is produced by CI (MSVC + CPack NSIS).
if command -v makensis >/dev/null 2>&1 && [ -f "${BUILD_DIR}/CPackConfig.cmake" ]; then
    echo "==> Attempting NSIS installer (CPack, best-effort)"
    ( cd "${BUILD_DIR}" && cpack -G NSIS -C Release ) \
        && find "${BUILD_DIR}" -maxdepth 2 -name '*.exe' -path '*_CPack_Packages*' \
               -exec cp {} "${OUT_DIR}/" \; 2>/dev/null \
        || echo "    NSIS packaging skipped/failed (expected locally; CI builds the real one)"
fi

echo "==> Done: ${APPDIR}/Tenjin.exe"
echo "    $(find "${APPDIR}" -name '*.dll' | wc -l) DLLs total (exe + plugins + qml)"
echo "    NOTE: MinGW build for local testing. CI ships the MSVC build + signed NSIS."

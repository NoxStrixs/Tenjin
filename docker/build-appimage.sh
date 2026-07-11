#!/usr/bin/env bash
# Build a Tenjin AppImage. Runs INSIDE the linux-appimage Docker container
# (invoked by tools/scripts/docker.py), where Qt, linuxdeploy, and deps are
# already present. Can also run on a host that has the same tools.
#
# Steps: CMake configure+build -> install into a staging prefix -> assemble an
# AppDir -> linuxdeploy (bundles Qt + QML imports) -> emit AppImage -> validate.
set -euo pipefail

ROOT="${1:-/work}"
BUILD_DIR="${ROOT}/build/linux-appimage"
APPDIR="${BUILD_DIR}/AppDir"
OUT_DIR="${ROOT}/dist"

QMAKE="$(command -v qmake6 || command -v qmake)"
export QML_SOURCES_PATHS="${ROOT}/View"

echo "==> Configuring"
cmake -S "${ROOT}" -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DTENJIN_BUILD_GUI=ON

echo "==> Building"
cmake --build "${BUILD_DIR}" --parallel

echo "==> Installing into AppDir"
rm -rf "${APPDIR}"
DESTDIR="${APPDIR}" cmake --install "${BUILD_DIR}"

# The app may install under /opt or /usr depending on CPACK settings; linuxdeploy
# wants a standard /usr layout. Normalize: ensure the binary, .desktop, and icon
# are at usr/bin, usr/share/applications, usr/share/icons/hicolor/*/apps.
BIN="$(find "${APPDIR}" -name Tenjin -type f -perm -u+x | head -1)"
if [ -z "${BIN}" ]; then
    echo "ERROR: Tenjin binary not found in AppDir after install." >&2
    exit 2
fi

DESKTOP="$(find "${APPDIR}" -name 'tenjin.desktop' | head -1)"
ICON="$(find "${APPDIR}" -name 'tenjin.png' -o -name 'Tenjin.png' | head -1)"

echo "==> Running linuxdeploy (bundling Qt runtime + QML imports)"
# The Qt plugin needs QML_SOURCES_PATHS to trace QML imports for a QtQuick app.
export QML_SOURCES_PATHS="${ROOT}/View"
linuxdeploy-x86_64.AppImage \
    --appdir "${APPDIR}" \
    --plugin qt \
    ${DESKTOP:+--desktop-file "${DESKTOP}"} \
    ${ICON:+--icon-file "${ICON}"} \
    --output appimage

mkdir -p "${OUT_DIR}"
IMG="$(ls -1 Tenjin*.AppImage *.AppImage 2>/dev/null | head -1 || true)"
if [ -z "${IMG}" ]; then
    echo "ERROR: linuxdeploy did not produce an AppImage." >&2
    exit 3
fi
mv "${IMG}" "${OUT_DIR}/"
FINAL="${OUT_DIR}/$(basename "${IMG}")"
echo "==> Produced ${FINAL}"

# ── Validation: confirm the bundle actually contains the Qt runtime + plugins ──
echo "==> Validating AppImage contents"
TMP="$(mktemp -d)"
( cd "${TMP}" && "${FINAL}" --appimage-extract >/dev/null 2>&1 )
SQ="${TMP}/squashfs-root"
fail=0
need_lib() {
    if ! find "${SQ}" -name "$1" | grep -q .; then
        echo "  MISSING: $1" >&2; fail=1
    else
        echo "  ok: $1"
    fi
}
need_lib "libQt6Core.so.6"
need_lib "libQt6Gui.so.6"
need_lib "libQt6Quick.so.6"
need_lib "libQt6Qml.so.6"
# Platform plugin — without this the app cannot start ("could not load the Qt
# platform plugin xcb").
if ! find "${SQ}" -path "*platforms/libqxcb.so" | grep -q .; then
    echo "  MISSING: platforms/libqxcb.so (app would fail to start)" >&2; fail=1
else
    echo "  ok: platforms/libqxcb.so"
fi
# QML modules for the app's own module must be bundled.
if ! find "${SQ}" -path "*TenjinView*" -name "*.qml" | grep -q .; then
    echo "  WARNING: TenjinView QML not found in bundle (may be compiled-in)." >&2
fi
rm -rf "${TMP}"

if [ "${fail}" -ne 0 ]; then
    echo "==> VALIDATION FAILED — the AppImage is missing runtime components." >&2
    exit 4
fi
echo "==> Validation passed. AppImage is correctly bundled: ${FINAL}"

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
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}"
EXE="$(find "${BUILD_DIR}" -name Tenjin.exe -print -quit)"
if [ -z "${EXE}" ]; then
    echo "ERROR: Tenjin.exe not found under ${BUILD_DIR}" >&2
    exit 1
fi
cp "${EXE}" "${APPDIR}/"

# ── Deployment via windeployqt (the official Qt tool, run under Wine) ─────────
# windeployqt reads the exe's imports and, via --qmldir + qmlimportscanner,
# resolves the full set of Qt DLLs, plugins (platforms/, styles/, tls/, …) and
# QML modules the app actually uses, copying them next to the exe. This is the
# supported, well-tested deployment path — it replaces the hand-rolled DLL walk
# that kept missing transitive DLLs and the QtQuick.Controls.Basic style plugin.
#   --qmldir /src/View  : scan our QML for imports (QtQuick.Controls, Layouts…)
#   --compiler-runtime  : include the MinGW runtime (libgcc/libstdc++/winpthread)
#   --no-translations   : our translations ship in the qrc already
echo "==> Deploying Qt runtime with windeployqt (under Wine)"
if windeployqt \
        --release \
        --compiler-runtime \
        --no-translations \
        --qmldir /src/View \
        "${APPDIR}/Tenjin.exe" 2>&1 | sed 's/^/    /'; then
    echo "    windeployqt completed"
else
    echo "ERROR: windeployqt failed — see output above" >&2
    exit 1
fi

# The MinGW compiler-runtime DLLs occasionally aren't captured by
# --compiler-runtime when cross-built (windeployqt looks in the MSVC-style
# location). Ensure the three are present as a safety net; harmless if already
# copied by windeployqt.
for rt in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    if [ ! -f "${APPDIR}/${rt}" ]; then
        src="$(find /usr/lib/gcc/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32 \
                    -name "${rt}" -print -quit 2>/dev/null || true)"
        [ -n "${src}" ] && cp "${src}" "${APPDIR}/" && echo "    + ${rt} (runtime safety net)"
    fi
done

echo "==> Done: ${APPDIR}/Tenjin.exe"
echo "    $(find "${APPDIR}" -name '*.dll' | wc -l) DLLs deployed"
echo "==> Top-level files:"
find "${APPDIR}" -maxdepth 1 -type f -printf '    %f\n' 2>/dev/null | sort
echo "==> Platform plugins:"
find "${APPDIR}" -path '*platforms*' -name '*.dll' -printf '    %p\n' 2>/dev/null | sort

# ── NSIS installer via CPack ─────────────────────────────────────────────────
# Stage the fully-deployed tree into the install prefix so CPack packages a
# COMPLETE app (exe + everything windeployqt gathered), not the bare exe that
# install(TARGETS) alone would place. makensis is native Linux — no Wine here.
if command -v makensis >/dev/null 2>&1; then
    echo "==> Building NSIS installer (CPack)"
    STAGE="${BUILD_DIR}/_install"
    rm -rf "${STAGE}"
    cmake --install "${BUILD_DIR}" --prefix "${STAGE}" --config Release 2>/tmp/install.log \
        || { echo "    cmake --install note:"; tail -n 5 /tmp/install.log; }
    STAGED_EXE="$(find "${STAGE}" -name Tenjin.exe -print -quit 2>/dev/null || true)"
    if [ -n "${STAGED_EXE}" ]; then STAGED_BIN="${STAGED_EXE%/*}"; else STAGED_BIN="${STAGE}/bin"; mkdir -p "${STAGED_BIN}"; fi
    cp -rn "${APPDIR}/." "${STAGED_BIN}/"
    if ( cd "${BUILD_DIR}" \
            && cpack -G NSIS \
                     -D CPACK_INSTALL_CMAKE_PROJECTS="" \
                     -D CPACK_INSTALLED_DIRECTORIES="${STAGE};/" \
                     -B "${OUT_DIR}" 2>/tmp/cpack.log ); then
        echo "    NSIS installer written to ${OUT_DIR}:"
        find "${OUT_DIR}" -maxdepth 1 -iname '*.exe' ! -name 'Tenjin.exe' -printf '        %f\n' 2>/dev/null
    else
        echo "    CPack NSIS failed (loose folder above still works):"
        tail -n 20 /tmp/cpack.log 2>/dev/null || true
    fi
fi

echo "==> Build complete."
echo "    Folder:    ${APPDIR}/Tenjin.exe"
echo "    NOTE: MinGW build for local testing. CI ships the MSVC build + signed installer."

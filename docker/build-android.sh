#!/usr/bin/env bash
# Build Tenjin for Android inside the container.
# Mounted: /src (repo) and /out (artifacts land here).
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/tmp/build-android}"
OUT_DIR="${OUT_DIR:-/out}"
QT_TARGET="${QT_TARGET:?QT_TARGET not set}"
QT_HOST="${QT_HOST:?QT_HOST not set}"

echo "==> Configuring (Android arm64-v8a, Qt ${QT_VERSION}, NDK ${ANDROID_NDK_VERSION})"
"${QT_TARGET}/bin/qt-cmake" -S /src -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="${QT_HOST}" \
    -DANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}" \
    -DANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}" \
    -DQT_ANDROID_ABIS="arm64-v8a" \
    -DSANITIZERS="" \
    "$@"

echo "==> Building"
cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo "==> Packaging APK (unsigned)"
cmake --build "${BUILD_DIR}" --target apk

mkdir -p "${OUT_DIR}"
find "${BUILD_DIR}" -name "*.apk" -exec cp {} "${OUT_DIR}/" \;

echo "==> Done. APKs in ${OUT_DIR}:"
ls -la "${OUT_DIR}"/*.apk 2>/dev/null || echo "  (no APK found — check the build log above)"
echo "    NOTE: unsigned. Sign with your keystore before installing on a device:"
echo "      apksigner sign --ks my.keystore --out signed.apk <apk>"

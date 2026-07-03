#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi
: "${TENJIN_APP_NAME:=Tenjin}"
: "${TENJIN_IOS_DEPLOYMENT_TARGET:=16.0}"

QT_ROOT="${QT_ROOT:-$HOME/Qt/6.8.3}"
QT_IOS="$QT_ROOT/ios"
QT_HOST="$QT_ROOT/macos"

if [[ ! -x "$QT_IOS/bin/qt-cmake" ]]; then
    echo "error: qt-cmake not found at $QT_IOS/bin/qt-cmake" >&2
    echo "Install Qt 6.8.3 for iOS, or set QT_ROOT to your Qt path." >&2
    exit 1
fi
if [[ ! -d "$QT_HOST" ]]; then
    echo "error: macOS host Qt not found at $QT_HOST" >&2
    echo "Qt 6.8 needs a desktop Qt of the same version to cross-compile for iOS." >&2
    echo "Install the 'macOS' component of Qt 6.8.3 too." >&2
    exit 1
fi

"$QT_IOS/bin/qt-cmake" -G Xcode -S . -B build-ios \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$TENJIN_IOS_DEPLOYMENT_TARGET" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DMEDIA_SUPPORT=ON \
    -DWEBVIEW_SUPPORT=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCHMARKS=OFF \
    -DSANITIZERS=""

echo
echo "Configured. Next:"
echo "  open build-ios/${TENJIN_APP_NAME}.xcodeproj"
echo "Then in Xcode set your signing Team and press Run with your iPhone selected."


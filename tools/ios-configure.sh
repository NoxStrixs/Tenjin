#!/usr/bin/env bash
# Configure the Tenjin iOS build on a Mac, then open it in Xcode to sign & run
# on your iPhone. Run this ON YOUR MAC (not in Docker — iOS needs Xcode).
#
# Prerequisites on the Mac:
#   - Xcode installed (App Store), opened once to accept the licence.
#   - Qt 6.8.3 for iOS AND for macOS installed (online installer, select both
#     "iOS" and "macOS" under 6.8.3). Adjust QT_ROOT below to your install path.
#
# Usage:
#   ./tools/ios-configure.sh
#   open build-ios/Tenjin.xcodeproj
#   # In Xcode: select the Tenjin target → Signing & Capabilities →
#   #   check "Automatically manage signing", pick your Team (your Apple ID),
#   #   plug in your iPhone, choose it as the run destination, press ▶.
#
# Free Apple ID: the app runs for 7 days, then re-press ▶ in Xcode to renew.
# Paid account ($99/yr): renews for a year.

set -euo pipefail

# Adjust if your Qt is elsewhere (e.g. ~/Qt or /Applications/Qt).
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

"$QT_IOS/bin/qt-cmake" -G Xcode -S . -B build-ios \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DQT_HOST_PATH="$QT_HOST" \
    -DMEDIA_SUPPORT=ON \
    -DWEBVIEW_SUPPORT=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCHMARKS=OFF \
    -DSANITIZERS=""

echo
echo "Configured. Next:"
echo "  open build-ios/Tenjin.xcodeproj"
echo "Then in Xcode set your signing Team and press Run with your iPhone selected."

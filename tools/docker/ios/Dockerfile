# ── tenjin-ios ────────────────────────────────────────────────────────────────
# iOS is special. Producing a runnable .ipa requires Xcode + Apple's signing
# infrastructure, neither of which is available in a Linux Docker container.
#
# This image therefore does NOT produce a working iOS binary. What it does is:
#
#   1. Run cmake --configure with the Qt iOS toolchain to validate the build
#      graph (catches typos in target_link_libraries, missing files, etc.).
#   2. Emit an Xcode project under build/ios-debug/ that the developer copies
#      to a Mac and finishes with `xcodebuild archive` + Xcode signing.
#
# Real iOS packaging happens in scripts/package.py via the macOS path it prints
# when invoked with --target ios.
# ─────────────────────────────────────────────────────────────────────────────
FROM tenjin-base

ARG QT_VERSION=6.8.0

# ── Qt iOS prebuilts + matching macOS host tools (for moc/rcc/qmlimportscanner)
#
# The macOS host kit is the only practical way to get moc/rcc/uic/qmlcachegen
# binaries that can run on Linux inside the iOS configure step. aqtinstall
# ships them under macos/desktop/<ver>/clang_64. They will not execute on
# Linux, so this container can only configure — not build. That's by design.
RUN aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 \
        --outputdir /opt/Qt \
 && aqt install-qt mac ios     ${QT_VERSION} ios \
        --outputdir /opt/Qt    || true

ENV QT_HOST_PATH=/opt/Qt/${QT_VERSION}/gcc_64
ENV QTDIR=/opt/Qt/${QT_VERSION}/ios
ENV CMAKE_PREFIX_PATH=${QTDIR}

WORKDIR /workspace

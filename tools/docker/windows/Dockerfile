# syntax=docker/dockerfile:1.7
# Cross-compile Qt 6.8 QML apps from Linux to Windows x86_64 (MinGW).
# Pattern derived from stateoftheartio/qt6:*-mingw-aqt, updated for Qt 6.8.3.
FROM ubuntu:24.04

ARG QT_VERSION=6.8.3
ARG QT_HOST_ARCH=linux_gcc_64
ARG QT_TARGET_ARCH=win64_mingw
ARG DEBIAN_FRONTEND=noninteractive

# Qt feature modules to install on BOTH host and target SDKs.
#   qtmultimedia  → audio/video playback (MEDIA_SUPPORT)
#   qtwebengine   → web/YouTube embeds (WEBVIEW_SUPPORT). Large; remove if the
#                   app is always built with WEBVIEW_SUPPORT=OFF.
# NOTE: QtWebEngine is NOT available for the MinGW target on Windows (Qt ships
# it for MSVC only). It is installed on the host SDK so a Linux build can use
# WEBVIEW_SUPPORT, but the Windows/MinGW package below omits it — the app must
# be built with WEBVIEW_SUPPORT=OFF for the MinGW target.
ARG QT_MODULES_HOST="qtmultimedia qtwebengine"
ARG QT_MODULES_TARGET="qtmultimedia"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    QT_ROOT=/opt/Qt \
    QT_HOST_PATH=/opt/Qt/${QT_VERSION}/gcc_64 \
    QT_TARGET_PATH=/opt/Qt/${QT_VERSION}/mingw_64 \
    WINEPREFIX=/opt/wineprefix \
    WINEARCH=win64 \
    WINEDEBUG=-all

# ── Base toolchain, MinGW, wine, Python (for aqt), packaging ─────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget xz-utils unzip p7zip-full \
        build-essential ninja-build cmake pkg-config git \
        python3 python3-pip python3-venv \
        gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
        gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix \
        mingw-w64-tools binutils-mingw-w64-x86-64 \
        wine \
        winbind \
        libxkbcommon0 libxcb1 libdbus-1-3 libfontconfig1 libfreetype6 \
        libgl1 libegl1 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 \
        libxcb-keysyms1 libxcb-randr0 libxcb-render0 libxcb-render-util0 \
        libxcb-shape0 libxcb-sync1 libxcb-util1 libxcb-xfixes0 libxcb-xkb1 \
        libpulse0 libasound2t64 \
        nsis \
    && rm -rf /var/lib/apt/lists/*

# POSIX threading variant — Qt 6 requires it.
RUN update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix && \
    update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# ── aqtinstall in an isolated venv (Ubuntu 24.04 has PEP-668) ────────────────
RUN python3 -m venv /opt/aqt-venv && \
    /opt/aqt-venv/bin/pip install --no-cache-dir "aqtinstall>=3.1.18"
ENV PATH="/opt/aqt-venv/bin:${PATH}"

# ── Host (Linux ELF) + target (Windows MinGW) Qt SDKs ────────────────────────
# Host SDK supplies Linux-native qmlimportscanner / moc / rcc / qmlcachegen
# that CMake resolves via QT_HOST_PATH during cross-compile. Feature modules
# (-m ...) supply QtMultimedia/QtWebEngine for both base and QML imports.
RUN aqt install-qt linux desktop ${QT_VERSION} ${QT_HOST_ARCH} \
        --outputdir ${QT_ROOT} \
        -m ${QT_MODULES_HOST} \
    && aqt install-qt windows desktop ${QT_VERSION} ${QT_TARGET_ARCH} \
        --outputdir ${QT_ROOT} \
        -m ${QT_MODULES_TARGET} \
    && chmod -R a+rX ${QT_ROOT}

# ── Pre-init wine prefix so first-build doesn't pay the cost ─────────────────
# Symlink target Qt as C:\Qt so windeployqt.exe's PE loader can resolve
# Qt6Core.dll & friends when inspecting the staged .exe.
RUN mkdir -p ${WINEPREFIX} && \
    wineboot -i && \
    wineserver -w && \
    ln -s ${QT_TARGET_PATH} ${WINEPREFIX}/drive_c/Qt
ENV WINEPATH='C:\\Qt\\bin'

# ── Sanity: host qmlimportscanner exists, target SDK has expected files ──────
# Verify the media modules landed on both SDKs so a missing -m surfaces at
# image-build time rather than mid-compile.
RUN test -x ${QT_HOST_PATH}/libexec/qmlimportscanner && \
    test -f ${QT_TARGET_PATH}/lib/cmake/Qt6/qt.toolchain.cmake && \
    test -f ${QT_TARGET_PATH}/bin/windeployqt.exe && \
    test -f ${QT_TARGET_PATH}/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && \
    test -f ${QT_HOST_PATH}/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && \
    { test -f ${QT_HOST_PATH}/lib/cmake/Qt6WebEngineQuick/Qt6WebEngineQuickConfig.cmake \
      || echo "WARN: QtWebEngine absent on host SDK — WEBVIEW_SUPPORT will be unavailable."; }

# ── Wrappers: callable as `qt-cmake-mingw` / `windeployqt-wine` ──────────────
COPY tools/docker/windows/qt-cmake-mingw    /usr/local/bin/qt-cmake-mingw
COPY tools/docker/windows/windeployqt-wine  /usr/local/bin/windeployqt-wine
RUN chmod +x /usr/local/bin/qt-cmake-mingw /usr/local/bin/windeployqt-wine

WORKDIR /workspace

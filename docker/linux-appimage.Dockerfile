# Reproducible Linux build image for Tenjin AppImage packaging.
#
# Ubuntu 22.04 sets the glibc baseline (2.35): the resulting AppImage runs on
# any distro with glibc >= 2.35 (Ubuntu 22.04+, Fedora 36+, Debian 12+). Qt is
# installed via aqtinstall to pin the exact version CI uses, rather than the
# distro's (much older) Qt. linuxdeploy + its Qt plugin bundle the runtime.
#
# Build the image:   docker build -f docker/linux-appimage.Dockerfile -t tenjin-appimage docker/
# It is invoked by tools/scripts/docker.py; you normally won't call it directly.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_VERSION=6.9.3
ENV QT_ROOT=/opt/qt

# Toolchain, Qt build deps, X/GL libs Qt links against, and AppImage tooling
# prerequisites (FUSE for the runtime; file/desktop-file utils used by
# linuxdeploy). fuse (not fuse3) matches the AppImage runtime's libfuse2 need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ninja-build cmake git curl ca-certificates \
        python3 python3-pip python3-venv \
        libgl1-mesa-dev libegl1-mesa-dev libxkbcommon-dev \
        libxcb1-dev libx11-xcb-dev libxcb-cursor0 libxcb-icccm4 \
        libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 \
        libxcb-shape0 libxcb-xinerama0 libxcb-xkb-dev libfontconfig1 \
        libdbus-1-3 libnss3 libasound2 \
        fuse libfuse2 file desktop-file-utils zsync \
        libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# fontTools + Pillow for the icon/font generation build steps.
RUN pip3 install --no-cache-dir aqtinstall fonttools pillow

# Install Qt (desktop linux_gcc_64) pinned to QT_VERSION. Base is enough for a
# QtQuick app; multimedia is added because the app links it. The arch id is
# The aqt ARCH id is `linux_gcc_64` (Qt 6.7+), but aqt WRITES the kit to a
# `gcc_64` directory (it drops the `linux_` prefix on disk) — so the install arg
# and the path differ. `ln -s` succeeds even on a missing target, so a mismatch
# here yields a dangling `current` symlink and a confusing failure much later;
# the `test -d` guards against exactly that.
RUN python3 -m aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 \
        -m qtmultimedia \
        -O ${QT_ROOT} \
    && test -d ${QT_ROOT}/${QT_VERSION}/gcc_64 \
    && ln -s ${QT_ROOT}/${QT_VERSION}/gcc_64 ${QT_ROOT}/current

ENV CMAKE_PREFIX_PATH=${QT_ROOT}/current
ENV PATH=${QT_ROOT}/current/bin:${PATH}

# linuxdeploy + Qt plugin (pinned continuous release). These bundle Qt libs,
# plugins, and QML imports into the AppDir and emit the AppImage.
RUN mkdir -p /opt/linuxdeploy && cd /opt/linuxdeploy && \
    curl -fL -o linuxdeploy-x86_64.AppImage \
        https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
    curl -fL -o linuxdeploy-plugin-qt-x86_64.AppImage \
        https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && \
    chmod +x *.AppImage
ENV PATH=/opt/linuxdeploy:${PATH}

WORKDIR /work

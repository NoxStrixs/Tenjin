# ── tenjin-linux ──────────────────────────────────────────────────────────────
# Native Linux build target. Builds, tests, and packages Tenjin into both a
# .deb (via cpack) and an AppImage (via linuxdeploy + qt plugin).
# ─────────────────────────────────────────────────────────────────────────────
FROM tenjin-base

ARG QT_VERSION=6.8.0
ARG QT_HOST=linux
ARG QT_ARCH=linux_gcc_64

# ── Build & runtime deps ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Toolchain — clang for sanitizers, GCC for primary build, both kept
    clang \
    clang-format \
    clang-tidy \
    g++ \
    # Test / bench
    libgtest-dev \
    libbenchmark-dev \
    # Profiling / static analysis
    valgrind \
    # AppImage runtime
    libfuse2t64 \
    file \
    desktop-file-utils \
    fakeroot \
    # Qt runtime deps (X11/Wayland)
    libfontconfig1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libgl1 \
    libegl1 \
    libdbus-1-3 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xkb1 \
    && rm -rf /var/lib/apt/lists/*

# ── Qt 6.8 LTS via aqtinstall ─────────────────────────────────────────────────
RUN aqt install-qt ${QT_HOST} desktop ${QT_VERSION} ${QT_ARCH} \
    --modules qtshadertools \
    --outputdir /opt/Qt

ENV QTDIR=/opt/Qt/${QT_VERSION}/gcc_64
ENV PATH=${QTDIR}/bin:${PATH}
ENV LD_LIBRARY_PATH=${QTDIR}/lib
ENV QT_PLUGIN_PATH=${QTDIR}/plugins
ENV QML2_IMPORT_PATH=${QTDIR}/qml
ENV CMAKE_PREFIX_PATH=${QTDIR}

# ── linuxdeploy + Qt plugin (AppImage packagers) ──────────────────────────────
RUN curl -fsSL -o /usr/local/bin/linuxdeploy \
        https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
 && curl -fsSL -o /usr/local/bin/linuxdeploy-plugin-qt \
        https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage \
 && chmod +x /usr/local/bin/linuxdeploy /usr/local/bin/linuxdeploy-plugin-qt

# AppImage tools refuse to run as root unless told to extract first.
ENV APPIMAGE_EXTRACT_AND_RUN=1

# ── FlameGraph (callgrind → SVG) ──────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/brendangregg/FlameGraph /opt/FlameGraph
ENV PATH=/opt/FlameGraph:${PATH}

WORKDIR /workspace

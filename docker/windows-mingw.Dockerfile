# Reproducible Windows build image for Tenjin (cross-compiled from Linux).
#
# Uses MinGW-w64 rather than MSVC: MSVC can't legally or practically run in a
# Linux container, so a local Windows build means the GCC-based toolchain. The
# result is a real .exe + bundled Qt DLLs that run on Windows — good enough for
# local testing without a Windows box. CI still builds the shipping artifact
# with MSVC (windows.yml), so treat this as a fast local check, not the
# release binary: MinGW and MSVC differ in C++ ABI, runtime, and warnings.
#
# Build the image:  docker build -f docker/windows-mingw.Dockerfile -t tenjin-windows docker/
# Invoked by tools/scripts/docker.py; you normally won't call it directly.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_VERSION=6.9.3
ENV QT_ROOT=/opt/qt

# MinGW-w64 cross toolchain + the host tools Qt's build needs. cmake/ninja drive
# the build; python3 + aqtinstall fetch the matching Qt kits.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ninja-build cmake git curl ca-certificates \
        python3 python3-pip python3-venv \
        python3-fonttools python3-pil \
        mingw-w64 mingw-w64-tools \
        p7zip-full \
        # Host Qt tools (moc, rcc, qmlimportscanner, qmltyperegistrar) are Linux
        # binaries that run during the cross-build, so they need Linux runtime
        # libs — qmlimportscanner links libglib, and the Qt libs it loads pull in
        # GL/xcb/fontconfig even though nothing is displayed.
        libglib2.0-0 libgl1 libegl1 libfontconfig1 libdbus-1-3 \
        libxkbcommon0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 \
        libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 \
        libxcb-xinerama0 libxcb-xkb1 \
        # nsis is a native Linux binary, so CPack -G NSIS can build the Windows
        # installer here with no Wine. (DLL bundling is done by walking the PE
        # import table with the mingw objdump, which ships with mingw-w64.)
        nsis \
    && rm -rf /var/lib/apt/lists/*

# aqtinstall needs a venv on 24.04 (PEP 668 externally-managed environment).
RUN python3 -m venv /opt/aqt-venv \
    && /opt/aqt-venv/bin/pip install --no-cache-dir aqtinstall

# Two kits are required:
#   - windows/win64_mingw : the TARGET kit. Note the host argument is `windows`,
#     not `linux` — aqt identifies kits by the platform they RUN on, and these
#     are Windows binaries/libs we link against while cross-compiling.
#   - linux/linux_gcc_64  : the HOST kit, providing moc/rcc/qmltyperegistrar
#     that must execute on the Linux build machine. NOTE the arch id is
#     `linux_gcc_64`, not `gcc_64` — aqt renamed it in Qt 6.7+, and the old name
#     fails with a confusing "packages ['qt_base', ...] were not found" error.
#     This matches .github/workflows/linux.yml (qt-arch: linux_gcc_64).
RUN /opt/aqt-venv/bin/aqt install-qt windows desktop ${QT_VERSION} win64_mingw \
        -O ${QT_ROOT} -m qtmultimedia
RUN /opt/aqt-venv/bin/aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 \
        -O ${QT_ROOT} -m qtmultimedia

# Fail here, with a clear message, rather than deep in a CMake error if a kit
# landed somewhere unexpected. Separate statements (not an ||/&& chain, whose
# left-to-right precedence makes the second check test the wrong exit status).
RUN set -eu; \
    for kit in mingw_64 gcc_64; do \
        if [ ! -d "${QT_ROOT}/${QT_VERSION}/$kit" ]; then \
            echo "ERROR: Qt kit '$kit' missing under ${QT_ROOT}/${QT_VERSION}"; \
            echo "Installed kits:"; ls "${QT_ROOT}/${QT_VERSION}"; \
            exit 1; \
        fi; \
    done

# aqt writes the kit dir WITHOUT the win64_ prefix (win64_mingw -> mingw_64),
# and the linux host kit as gcc_64 (not linux_gcc_64). These are the real
# on-disk paths, matching how .github/workflows/windows.yml resolves QT_WIN
# to .../6.9.3/msvc2022_64 despite passing qt-arch win64_msvc2022_64.
ENV QT_TARGET=${QT_ROOT}/${QT_VERSION}/mingw_64
ENV QT_HOST=${QT_ROOT}/${QT_VERSION}/gcc_64
ENV PATH="${QT_HOST}/bin:${PATH}"

WORKDIR /src
COPY build-windows.sh /usr/local/bin/build-windows.sh
RUN chmod +x /usr/local/bin/build-windows.sh
ENTRYPOINT ["/usr/local/bin/build-windows.sh"]

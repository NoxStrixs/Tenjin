# Reproducible Android build image for Tenjin.
#
# Unlike the Windows image (MinGW stand-in for MSVC), this produces the REAL
# shippable artifact: Android builds are cross-compiled from Linux in CI too, so
# a container build matches what android.yml produces. Output is an unsigned APK
# — sign it locally with your keystore, or let CI handle release signing.
#
# Build the image:  docker build -f docker/android.Dockerfile -t tenjin-android docker/
# Invoked by tools/scripts/docker.py; you normally won't call it directly.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_VERSION=6.9.3
ENV QT_ROOT=/opt/qt
# Pin the SDK/NDK to what CI uses so local and CI builds agree.
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_NDK_VERSION=26.1.10909125
ENV ANDROID_API=34
ENV ANDROID_BUILD_TOOLS=34.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ninja-build cmake git curl unzip ca-certificates \
        python3 python3-pip python3-venv \
        python3-fonttools python3-pil \
        openjdk-17-jdk \
        # Host Qt tools (qmlimportscanner, androiddeployqt, moc/rcc) run on
        # Linux during the cross-build and need these runtime libs — same reason
        # as the Windows image.
        libglib2.0-0 libgl1 libegl1 libfontconfig1 libdbus-1-3 \
        libxkbcommon0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 \
        libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 \
        libxcb-xinerama0 libxcb-xkb1 \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Android command-line tools -> SDK platform, build-tools, and the pinned NDK.
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdline.zip \
        https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q /tmp/cmdline.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm /tmp/cmdline.zip \
    && yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null \
    && ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_API}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "ndk;${ANDROID_NDK_VERSION}" >/dev/null

ENV ANDROID_NDK_ROOT=${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}

RUN python3 -m venv /opt/aqt-venv \
    && /opt/aqt-venv/bin/pip install --no-cache-dir aqtinstall

# Target kit (arm64-v8a) + host kit for moc/rcc/androiddeployqt. Arch ids match
# .github/workflows/android.yml exactly (linux_gcc_64 host, android_arm64_v8a
# target) — `gcc_64` is the pre-6.7 name and fails on 6.9.
RUN /opt/aqt-venv/bin/aqt install-qt linux android ${QT_VERSION} android_arm64_v8a \
        -O ${QT_ROOT} -m qtmultimedia
RUN /opt/aqt-venv/bin/aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 \
        -O ${QT_ROOT} -m qtmultimedia

# Fail fast with a clear message if a kit landed somewhere unexpected.
RUN set -eu; \
    for kit in android_arm64_v8a gcc_64; do \
        if [ ! -d "${QT_ROOT}/${QT_VERSION}/$kit" ]; then \
            echo "ERROR: Qt kit '$kit' missing under ${QT_ROOT}/${QT_VERSION}"; \
            echo "Installed kits:"; ls "${QT_ROOT}/${QT_VERSION}"; \
            exit 1; \
        fi; \
    done

ENV QT_TARGET=${QT_ROOT}/${QT_VERSION}/android_arm64_v8a
# Host kit installs to gcc_64 on disk (aqt drops the linux_ prefix for the
# desktop kit); the android target keeps its full name.
ENV QT_HOST=${QT_ROOT}/${QT_VERSION}/gcc_64

WORKDIR /src
COPY build-android.sh /usr/local/bin/build-android.sh
RUN chmod +x /usr/local/bin/build-android.sh
ENTRYPOINT ["/usr/local/bin/build-android.sh"]

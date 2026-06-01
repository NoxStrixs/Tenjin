# ── tenjin-base ───────────────────────────────────────────────────────────────
# Shared base image. Holds everything platform-independent: CMake, Ninja, git,
# Python, ccache, and pip. Target images (linux, windows, ios) FROM this.
#
# Pinned to Ubuntu 24.04 LTS for a glibc/libstdc++ that's compatible with most
# downstream distros for AppImage builds.
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    curl \
    git \
    ninja-build \
    pkg-config \
    python3 \
    python3-pip \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# pip is externally-managed on Ubuntu 24.04 — break-system-packages is the
# documented escape hatch for container images that don't share the host's
# Python.
RUN pip3 install --break-system-packages --no-cache-dir \
    "aqtinstall>=3.1"

ENV CCACHE_DIR=/ccache
RUN mkdir -p /ccache && chmod 0777 /ccache

WORKDIR /workspace

# Packaging Tenjin locally

Reproducible package builds. Docker is the preferred method (pinned images match
CI and avoid host dependency drift). Apple targets require a macOS host.

| Target     | Command                          | How it builds                              |
|------------|----------------------------------|--------------------------------------------|
| AppImage   | `./tools/tool package --target appimage` | Docker (Ubuntu 22.04, Qt 6.9.3), glibc 2.35 baseline |
| Flatpak    | `./tools/tool package --target flatpak`  | Host `flatpak-builder`, `org.kde.Platform` runtime |
| macOS      | `./tools/tool package --target macos`    | Host only (macOS + Xcode)                  |
| iOS        | `./tools/tool package --target ios`      | Host only (macOS + Xcode)                  |

Artifacts are written to `dist/`.

## AppImage (Docker)

```
./tools/tool package --target appimage
```

Builds the `tenjin-appimage` image on first run (installs Qt via aqtinstall;
cached afterward), then compiles, assembles an AppDir, runs `linuxdeploy` with
its Qt plugin, and **validates** the result — the build fails if the bundle is
missing the Qt runtime or the `xcb` platform plugin (the usual "AppImage won't
launch" cause). The image is built on Ubuntu 22.04 so the AppImage runs on any
distro with glibc ≥ 2.35.

Requirements: Docker running, with `/dev/fuse` available (the run command grants
the needed caps for the AppImage FUSE mount).

## Flatpak (host)

Flatpak is built on the host, not in Docker — its bubblewrap sandbox does not
nest reliably in Docker-in-WSL2. One-time setup:

```
sudo apt install flatpak flatpak-builder
flatpak remote-add --if-not-exists --user flathub \
    https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.kde.Sdk//6.7 org.kde.Platform//6.7
```

Then:

```
./tools/tool package --target flatpak
```

The runtime branch (`6.7`) is set in `packaging/flatpak/app.tenjin.Tenjin.yml`;
verify the current KDE runtime with `flatpak remote-info flathub
org.kde.Platform` and bump if needed.

## Apple (macOS host only)

`macos`/`ios` targets error out on non-Darwin hosts — Apple platforms cannot be
cross-built. On a Mac they drive the `macos`/`ios` CMake presets. Signing and
`.dmg`/`.ipa` packaging use the identity configured in Xcode or the CI workflow.

## Windows

Windows packaging remains CI-driven (native MSVC → NSIS/ZIP). The prior MinGW
cross-compile image can be reintroduced under `docker/` if local Windows builds
are needed.

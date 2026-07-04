# Local build targets. WSL2/Ubuntu and native Linux build here directly via
# CMake presets (no Docker). Windows (MSVC), macOS, iOS, and Android build in
# CI only — trigger their workflows with `gh workflow run`.

QT_VERSION = "6.9.3"

# Maps a local target to its CMake configure/build preset (CMakePresets.json).
LOCAL_TARGETS = {
    "linux-debug":   "linux-debug",
    "linux-release": "linux-release",
}

DEFAULT_TARGET = "linux-debug"

# Targets that only build in CI, with the workflow that builds them.
CI_ONLY = {
    "windows": "windows.yml",
    "macos":   "macos.yml",
    "ios":     "ios.yml",
    "android": "android.yml",
}

QT_VERSION = "6.8.3"

BASE_IMAGE = {
    "image":      "tenjin-base",
    "dockerfile": "tools/docker/base/Dockerfile",
}

TARGETS = {
    "linux": {
        "image":      "tenjin-linux",
        "dockerfile": "tools/docker/linux/Dockerfile",
        "cmake_args": [],
        # native = the container can run the binaries it builds.
        # Sanitizers / tests / benchmarks only meaningful on native targets.
        "native":     True,
        "package_generators": ["DEB", "External"],
    },
    "windows": {
        "image":      "tenjin-windows",
        "dockerfile": "tools/docker/windows/Dockerfile",
        # Canonical Qt 6.8 Linux→Windows MinGW cross-compile.
        #
        # QT_HOST_PATH MUST be a -D cache variable, not an env var: Qt's
        # CMake code calls set(QT_HOST_PATH "" CACHE PATH …) and never reads
        # the environment. Without it, CMake exec's the Windows .exe build
        # of qmlimportscanner on Linux and qt_finalize_target dies with
        # "Failed to scan target ... for QML imports: Permission denied".
        #
        # CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER lets find_program() locate
        # host binaries (cmake, ninja); other modes are ONLY so libraries
        # and packages resolve to the target sysroot.
        "cmake_args": [
            "-DCMAKE_SYSTEM_NAME=Windows",
            f"-DCMAKE_TOOLCHAIN_FILE=/opt/Qt/{QT_VERSION}/mingw_64/lib/cmake/Qt6/qt.toolchain.cmake",
            f"-DQT_HOST_PATH=/opt/Qt/{QT_VERSION}/gcc_64",
            f"-DQT_HOST_PATH_CMAKE_DIR=/opt/Qt/{QT_VERSION}/gcc_64/lib/cmake",
            "-DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++-posix",
            "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER",
            "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY",
            "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY",
            "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY",
            "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
            "-DMEDIA_SUPPORT=ON",
            "-DWEBVIEW_SUPPORT=OFF",
        ],
        "native":     False,
        "package_generators": ["NSIS", "ZIP"],
    },
    "ios": {
        "image":      "tenjin-ios",
        "dockerfile": "tools/docker/ios/Dockerfile",
        # Build only — packaging requires a real Mac. See scripts/package.py.
        "cmake_args": [
            "-DCMAKE_SYSTEM_NAME=iOS",
            "-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0",
            f"-DQT_HOST_PATH=/opt/Qt/{QT_VERSION}/gcc_64",
        ],
        "native":     False,
        "package_generators": [],
    },
}

CONFIGS        = ["debug", "debug-tsan", "release"]
DEFAULT_TARGET = "linux"
DEFAULT_CONFIG = "debug"

CONFIG_CMAKE_FLAGS = {
    "debug": [
        "-DCMAKE_BUILD_TYPE=Debug",
        "-DSANITIZERS=asan,lsan,ubsan",
    ],
    "debug-tsan": [
        "-DCMAKE_BUILD_TYPE=Debug",
        "-DSANITIZERS=tsan",
    ],
    "release": [
        "-DCMAKE_BUILD_TYPE=Release",
    ],
}

# Configs in which tests/benchmarks are wired in. Cross-compiled targets
# always set both to OFF (handled in config.py).
CONFIGS_WITH_TESTS      = {"debug", "debug-tsan", "release"}
CONFIGS_WITH_BENCHMARKS = {"release"}

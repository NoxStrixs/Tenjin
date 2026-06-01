cmake_minimum_required(VERSION 3.22)

project(Tenjin
    VERSION  0.1.0
    LANGUAGES CXX
)

# ─── Project-wide settings ────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD          23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)

# Keep symbols visible only where annotated. Reduces binary size and avoids
# accidental ABI exposure.
set(CMAKE_CXX_VISIBILITY_PRESET     hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Position-independent code — required for any object that might end up in a
# shared library or a deployed Qt plugin.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ─── Build options ────────────────────────────────────────────────────────────
option(BUILD_TESTS      "Build unit tests"        OFF)
option(BUILD_BENCHMARKS "Build microbenchmarks"   OFF)
option(SANITIZERS       "Sanitizers, comma-separated (asan,lsan,tsan,ubsan)" "")
# Rich media: QtMultimedia (audio/video playback). Optional so a lean build can
# omit the FFmpeg backend + codecs.
option(MEDIA_SUPPORT    "Enable audio/video playback (QtMultimedia)" ON)
# Web embeds (YouTube etc.) via QtWebEngine. Heavy (~100MB+); off by default.
option(WEBVIEW_SUPPORT  "Enable web/YouTube embeds (QtWebEngine)" OFF)

include(cmake/Sanitizers.cmake)
include(cmake/Warnings.cmake)

# ─── Qt ───────────────────────────────────────────────────────────────────────
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Sql
)

# Optional media components.
set(TENJIN_MEDIA_COMPONENTS "")
if(MEDIA_SUPPORT)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Multimedia)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::Multimedia)
endif()
if(WEBVIEW_SUPPORT)
    find_package(Qt6 6.8 REQUIRED COMPONENTS WebEngineQuick)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::WebEngineQuick)
endif()

qt_standard_project_setup(REQUIRES 6.8)

# Feature macros + QML files for media, consumed by the View and App targets.
# (The View/CMakeLists.txt links ${TENJIN_MEDIA_COMPONENTS} and adds the media
#  QML files conditionally — see the snippet in the project README.)
set(TENJIN_FEATURE_DEFINITIONS "")
if(MEDIA_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_MEDIA)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_WEBVIEW)
endif()

# ─── Subprojects ──────────────────────────────────────────────────────────────
add_subdirectory(Service)
add_subdirectory(View)
add_subdirectory(App)

if(BUILD_TESTS)
    enable_testing()
    find_package(GTest CONFIG REQUIRED)
    add_subdirectory(tests)
endif()

if(BUILD_BENCHMARKS)
    find_package(benchmark CONFIG REQUIRED)
    add_subdirectory(benchmarks)
endif()

# ─── Packaging ────────────────────────────────────────────────────────────────
include(cmake/Packaging.cmake)

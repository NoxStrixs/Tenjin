cmake_minimum_required(VERSION 3.22)

include(cmake/DotEnv.cmake)
tenjin_dotenv_load("${CMAKE_SOURCE_DIR}/.env")
tenjin_dotenv_default(TENJIN_APP_NAME              "Tenjin")
tenjin_dotenv_default(TENJIN_APP_DISPLAY_NAME      "Tenjin")
tenjin_dotenv_default(TENJIN_APP_VERSION           "0.1.0")
tenjin_dotenv_default(TENJIN_BUNDLE_ID             "app.tenjin.Tenjin")
tenjin_dotenv_default(TENJIN_ORG_NAME              "Tenjin")
tenjin_dotenv_default(TENJIN_ORG_DOMAIN            "tenjin.app")
tenjin_dotenv_default(TENJIN_APP_DESCRIPTION       "Personal vocabulary and spaced-repetition app")
tenjin_dotenv_default(TENJIN_APP_KEYWORDS          "vocabulary;flashcards;learning;languages")
tenjin_dotenv_default(TENJIN_APP_CATEGORIES        "Education;Languages;")
tenjin_dotenv_default(TENJIN_IOS_DEPLOYMENT_TARGET "16.0")
tenjin_dotenv_default(TENJIN_CLOUD_URL             "")

project(Tenjin
    VERSION   ${TENJIN_APP_VERSION}
    # C is required by miniz (Anki .apkg import). Declaring it here validates
    # the C compiler up-front with the active (cross-)toolchain.
    LANGUAGES CXX C
)

set(CMAKE_CXX_STANDARD          23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)
set(CMAKE_CXX_VISIBILITY_PRESET     hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Build options
option(MEDIA_SUPPORT    "Enable audio/video playback (QtMultimedia)" ON)
option(WEBVIEW_SUPPORT  "Enable web/YouTube embeds (QtWebView)"      OFF)
option(TENJIN_DEBUG_UI  "Include debug console drawer in the build"  OFF)
option(TENJIN_BUILD_TESTS "Build the unit test suite"                 OFF)

# SANITIZERS: comma-separated list (asan,lsan,tsan,ubsan,msan). Empty = off.
set(SANITIZERS "" CACHE STRING "Sanitizers to enable")

include(cmake/Sanitizers.cmake)
include(cmake/Warnings.cmake)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2 Sql Network Svg
)

if(MEDIA_SUPPORT)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Multimedia)
endif()
if(WEBVIEW_SUPPORT)
    find_package(Qt6 6.8 REQUIRED COMPONENTS WebView)
endif()

qt_standard_project_setup(REQUIRES 6.8)

# ── miniz: ZIP reader for Anki .apkg import ───────────────────────────────────
# MIT-licensed, no system dependencies. Works on every target including
# iOS/Android static builds. See cmake/Miniz.cmake for the full rationale and
# setup; it produces a `miniz` (and `miniz::miniz`) static target with complete
# usage requirements, so consumers link it with target_link_libraries and CMake
# resolves include paths and link order transitively.
include(cmake/Miniz.cmake)

# Ensure the icon font is present (downloads at configure time if missing).
include(cmake/IconFont.cmake)

# Fetch bundled UI assets (mono font, language-flag SVGs) at configure time.
include(cmake/Assets.cmake)

# Feature compile definitions propagated to all targets
set(TENJIN_FEATURE_DEFINITIONS "")
if(MEDIA_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_MEDIA)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_WEBVIEW)
endif()
if(TENJIN_DEBUG_UI)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_DEBUG_UI)
endif()

# Media components list used by View and App
set(TENJIN_MEDIA_COMPONENTS "")
if(MEDIA_SUPPORT)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::Multimedia)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::WebView)
    if(TARGET Qt6::WebViewQuick)
        list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::WebViewQuick)
    endif()
endif()

# Generated config header
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/TenjinConfig.h.in"
    "${CMAKE_BINARY_DIR}/generated/TenjinConfig.h"
    @ONLY
)
include_directories("${CMAKE_BINARY_DIR}/generated")

add_subdirectory(Service)
add_subdirectory(ViewModels)
add_subdirectory(View)
# Translations.cmake defines the tenjin_configure_translations macro.
# It must be included before add_subdirectory(App) which calls the macro,
# but after View/ViewModels/Service so all targets are visible when the macro runs.
include(cmake/Translations.cmake)

add_subdirectory(App)

if(TENJIN_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

include(cmake/Packaging.cmake)

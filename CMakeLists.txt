cmake_minimum_required(VERSION 3.25)

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

# Resolve canonical version + git identity (semver core, build hash, versionCode).
include(cmake/Version.cmake)
tenjin_resolve_version()

set(CMAKE_CXX_STANDARD          23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)
set(CMAKE_CXX_VISIBILITY_PRESET     hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Build options
option(MEDIA_SUPPORT    "Enable audio/video playback (QtMultimedia)" ON)
option(WEBVIEW_SUPPORT  "Enable web/YouTube embeds (QtWebView)"      OFF)
option(TTS_SUPPORT      "Enable native text-to-speech pronunciation"      ON)
option(TENJIN_DEBUG_UI  "Include debug console drawer in the build"  OFF)
# Escape hatch: the aqt Qt iOS kit links a static FFmpeg media plugin without
# its libs. App/CMakeLists whitelists only the Darwin plugin to avoid that. If a
# given kit still force-links FFmpeg, set this ON to drop QtMultimedia on iOS
# entirely (loses in-entry audio/video playback on iOS only; every other
# platform keeps it). Off by default so the whitelist is tried first.
option(IOS_DISABLE_MEDIA "Force-disable QtMultimedia on iOS (FFmpeg workaround)" OFF)
if((IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS") AND IOS_DISABLE_MEDIA)
    set(MEDIA_SUPPORT OFF)
    message(STATUS "Tenjin iOS: MEDIA_SUPPORT forced OFF (IOS_DISABLE_MEDIA).")
endif()
option(TENJIN_BUILD_GUI "Build the QML GUI application"              ON)

# SANITIZERS: comma-separated list (asan,lsan,tsan,ubsan,msan). Empty = off.
set(SANITIZERS "" CACHE STRING "Sanitizers to enable")

include(cmake/Sanitizers.cmake)
include(cmake/Warnings.cmake)
include(cmake/StaticAnalysis.cmake)
include(cmake/Vendor.cmake)

find_package(Qt6 6.9 REQUIRED COMPONENTS
    Core Concurrent Gui Qml Network Sql
)

if(TENJIN_BUILD_GUI)
    find_package(Qt6 6.9 REQUIRED COMPONENTS
        Quick QuickControls2 Svg
    )
endif()

if(TENJIN_BUILD_GUI AND MEDIA_SUPPORT)
    find_package(Qt6 6.9 REQUIRED COMPONENTS Multimedia)
endif()
if(TENJIN_BUILD_GUI AND WEBVIEW_SUPPORT)
    find_package(Qt6 6.9 REQUIRED COMPONENTS WebView)
endif()
if(TENJIN_BUILD_GUI AND TTS_SUPPORT)
    # TTS is now implemented with each platform's native speech API
    # (AVSpeechSynthesizer, Android TextToSpeech, System.Speech, spd-say) — no
    # QtTextToSpeech / qtspeech module dependency. Nothing to find here; the
    # per-platform backend TU is selected in ViewModels/CMakeLists.txt.
endif()

qt_standard_project_setup(REQUIRES 6.9)

# ── miniz: ZIP reader for Anki .apkg import ───────────────────────────────────
# MIT-licensed, no system dependencies. Works on every target including
# iOS/Android static builds. Produces a `miniz` (miniz::miniz) static target
# with complete usage requirements.
include(cmake/Miniz.cmake)

# Validate vendored UI assets — only when building the GUI.
if(TENJIN_BUILD_GUI)
    include(cmake/IconFont.cmake)
    include(cmake/Assets.cmake)
endif()

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

# Generated config header (carries version core, git hash, versionCode).
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/TenjinConfig.h.in"
    "${CMAKE_BINARY_DIR}/generated/TenjinConfig.h"
    @ONLY
)
include_directories("${CMAKE_BINARY_DIR}/generated")

add_subdirectory(Service)
add_subdirectory(ViewModels)

if(TENJIN_BUILD_GUI)
    add_subdirectory(View)
    # Translations.cmake defines the tenjin_configure_translations macro.
    # Included after View/ViewModels/Service so all targets are visible, and
    # before add_subdirectory(App) which calls the macro.
    include(cmake/Translations.cmake)

    add_subdirectory(App)
endif()

include(cmake/Packaging.cmake)

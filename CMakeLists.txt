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

project(Tenjin
    VERSION  ${TENJIN_APP_VERSION}
    LANGUAGES CXX
)

include(cmake/Translations.cmake)

# Settings
set(CMAKE_CXX_STANDARD          23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)

# Keep symbols visible only where annotated.
# Reduces binary size and avoids accidental ABI exposure.
set(CMAKE_CXX_VISIBILITY_PRESET     hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Required for any object that might end up in a shared library or a deployed Qt plugin.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Build options
option(SANITIZERS       "Sanitizers, comma-separated (asan,lsan,tsan,ubsan)" "")
option(MEDIA_SUPPORT    "Enable audio/video playback (QtMultimedia)" ON)
option(WEBVIEW_SUPPORT  "Enable web/YouTube embeds (QtWebView)" OFF)

include(cmake/Sanitizers.cmake)
include(cmake/Warnings.cmake)

# Qt
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Sql
    LabsPlatform
)

set(TENJIN_MEDIA_COMPONENTS "")
if(MEDIA_SUPPORT)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Multimedia)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::Multimedia)
endif()
if(WEBVIEW_SUPPORT)
    # QtWebView ships in two parts on Qt 6.8: the core module (C++ API —
    # QtWebView::initialize) and the Quick integration that registers the
    # QML type. Both need linking for the embed to actually work.
    find_package(Qt6 6.8 REQUIRED COMPONENTS WebView)
    list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::WebView)
    # WebViewQuick is the QML plugin half. On some Qt distributions it's a
    # separate target; on others it's rolled into WebView. Probe before linking.
    if(TARGET Qt6::WebViewQuick)
        list(APPEND TENJIN_MEDIA_COMPONENTS Qt6::WebViewQuick)
    endif()
endif()

qt_standard_project_setup(REQUIRES 6.8)

# Feature macros and QML files for media, consumed by the View and App targets.
set(TENJIN_FEATURE_DEFINITIONS "")
if(MEDIA_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_MEDIA)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND TENJIN_FEATURE_DEFINITIONS TENJIN_WEBVIEW)
endif()

# Generated config header
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/TenjinConfig.h.in"
    "${CMAKE_BINARY_DIR}/generated/TenjinConfig.h"
    @ONLY
)
# Make the generated dir visible to any target that wants it
include_directories("${CMAKE_BINARY_DIR}/generated")

# Subprojects
add_subdirectory(Service)
add_subdirectory(ViewModels)
add_subdirectory(View)
add_subdirectory(App)

# Packaging
include(cmake/Packaging.cmake)

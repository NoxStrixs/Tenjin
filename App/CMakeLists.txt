qt_add_executable(Tenjin
    WIN32
    MANUAL_FINALIZATION
    src/main.cpp
)

tenjin_configure_translations(${TENJIN_APP_NAME})

# Monotonic build number for store submission (Apple CFBundleVersion, Android
# versionCode). Defaults to the git-derived TENJIN_VERSION_CODE so re-uploads
# never collide; can be overridden explicitly on the CMake command line.
if(NOT DEFINED TENJIN_BUILD_NUMBER)
    set(TENJIN_BUILD_NUMBER "${TENJIN_VERSION_CODE}")
endif()

set_target_properties(Tenjin PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    OUTPUT_NAME              "${TENJIN_APP_NAME}"
)

target_link_libraries(Tenjin
    PRIVATE
        TenjinViewplugin
        TenjinView
        TenjinViewModels
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Svg
        Qt6::Sql
        tenjin_warnings
        tenjin_sanitizers
)

target_include_directories(Tenjin PRIVATE src)

# Static plugin linkage. On a STATIC Qt (iOS always; Android/desktop only when
# Qt was built static) the image-format, SQL-driver and QML-module plugins must
# be linked into the executable. On a SHARED Qt they load dynamically and
# linking the static plugin targets would be a duplicate-symbol error.
#
# QT6_IS_SHARED_LIBS_BUILD is exported by find_package(Qt6) and is the
# authoritative, OS-independent discriminator — unlike "IOS OR ANDROID", which
# wrongly fired on Android's shared Qt and broke the link.
if(NOT QT6_IS_SHARED_LIBS_BUILD)
    target_link_libraries(Tenjin PRIVATE
        Qt6::QSQLiteDriverPlugin
        Qt6::QJpegPlugin
        Qt6::QGifPlugin
        Qt6::QSvgPlugin
        Qt6::QICOPlugin
    )
endif()

if(MEDIA_SUPPORT)
    target_link_libraries(Tenjin PRIVATE Qt6::Multimedia)
endif()

if(WIN32)
    # DwmSetWindowAttribute (dark title bar). winId() is public on
    # QQuickWindow; only dwmapi is required.
    target_link_libraries(Tenjin PRIVATE dwmapi)

    # Executable icon: generated at configure time from the single canonical
    # icon source (the 1024 master shared with iOS/macOS), so no binary .ico is
    # committed (§4). A generated .rc points rc.exe at the built .ico. Cosmetic,
    # so any generation failure warns and skips rather than failing the build.
    include(${CMAKE_SOURCE_DIR}/cmake/GenerateIcons.cmake)
    set(_tenjin_icon_src
        "${CMAKE_SOURCE_DIR}/App/ios/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
    set(_tenjin_ico "${CMAKE_BINARY_DIR}/generated/tenjin.ico")
    tenjin_generate_win_ico("${_tenjin_icon_src}" "${_tenjin_ico}" _tenjin_ico_ok)

    if(_tenjin_ico_ok)
        # rc references the icon by absolute path so it resolves regardless of
        # the .rc's own location.
        set(_tenjin_rc "${CMAKE_BINARY_DIR}/generated/tenjin.rc")
        file(TO_NATIVE_PATH "${_tenjin_ico}" _tenjin_ico_native)
        string(REPLACE "\\" "\\\\" _tenjin_ico_rc "${_tenjin_ico_native}")

        # VERSIONINFO populates the Explorer "Details" tab and helps SmartScreen
        # reputation. Version fields come from the project version; the comma
        # form (a,b,c,0) is required by the binary FILEVERSION/PRODUCTVERSION.
        set(_v_major ${PROJECT_VERSION_MAJOR})
        set(_v_minor ${PROJECT_VERSION_MINOR})
        set(_v_patch ${PROJECT_VERSION_PATCH})
        set(_v_comma "${_v_major},${_v_minor},${_v_patch},0")
        set(_v_dot   "${_v_major}.${_v_minor}.${_v_patch}.0")

        file(WRITE "${_tenjin_rc}"
"IDI_ICON1 ICON \"${_tenjin_ico_rc}\"

#include <winver.h>

VS_VERSION_INFO VERSIONINFO
 FILEVERSION ${_v_comma}
 PRODUCTVERSION ${_v_comma}
 FILEFLAGSMASK 0x3fL
 FILEFLAGS 0x0L
 FILEOS VOS__WINDOWS32
 FILETYPE VFT_APP
 FILESUBTYPE 0x0L
BEGIN
    BLOCK \"StringFileInfo\"
    BEGIN
        BLOCK \"040904b0\"
        BEGIN
            VALUE \"CompanyName\", \"Tenjin Maintainers\"
            VALUE \"FileDescription\", \"Tenjin — spaced-repetition vocabulary\"
            VALUE \"FileVersion\", \"${_v_dot}\"
            VALUE \"InternalName\", \"Tenjin\"
            VALUE \"OriginalFilename\", \"Tenjin.exe\"
            VALUE \"ProductName\", \"Tenjin\"
            VALUE \"ProductVersion\", \"${_v_dot}\"
            VALUE \"LegalCopyright\", \"Copyright (c) 2026 Tenjin Maintainers\"
        END
    END
    BLOCK \"VarFileInfo\"
    BEGIN
        VALUE \"Translation\", 0x409, 1200
    END
END
")
        target_sources(Tenjin PRIVATE "${_tenjin_rc}")
    else()
        message(WARNING
            "Windows executable icon skipped (see prior warning). The exe will "
            "have the default icon.")
    endif()
endif()

if(ANDROID)
    set_target_properties(Tenjin PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_VERSION_NAME       "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE       "${TENJIN_VERSION_CODE}"
        QT_ANDROID_MIN_SDK_VERSION    "26"
        QT_ANDROID_TARGET_SDK_VERSION "34"
        QT_ANDROID_PACKAGE_NAME       "${TENJIN_BUNDLE_ID}"
    )
endif()

# Force-link the static QML-module plugins. Two mechanisms, belt-and-braces,
# because on a static iOS build the scanner alone has proven unreliable when the
# QML lives in a linked module (TenjinView) rather than the executable:
#
#   1. qt_import_qml_plugins runs qmlimportscanner and links what it finds.
#   2. An EXPLICIT fallback list of the QtQuick module plugins the app imports,
#      linked directly, so a scanner miss can never leave a module "not
#      installed" at runtime. On a shared Qt these targets don't exist, so the
#      block is gated on static-ness. Duplicate links are harmless (CMake dedups).
if(COMMAND qt_import_qml_plugins)
    qt_import_qml_plugins(Tenjin)
    # Also scan the QML module target directly — its imports are what actually
    # pull in QtQuick.*, and scanning only the executable can miss them.
    if(TARGET TenjinView)
        qt_import_qml_plugins(TenjinView)
    endif()
endif()

if(NOT QT6_IS_SHARED_LIBS_BUILD)
    # Explicit fallback: link the static plugin for every QML module the app
    # imports. These target names are stable in Qt 6.8. If a module is added to
    # a .qml import, add its plugin here too.
    set(_TENJIN_QML_PLUGIN_TARGETS
        Qt6::qtquick2plugin                 # QtQuick
        Qt6::quicklayoutsplugin             # QtQuick.Layouts
        Qt6::qquickwindowplugin             # QtQuick.Window
        Qt6::qtquickcontrols2basicstyleplugin   # QtQuick.Controls.Basic
        Qt6::qtquickcontrols2plugin         # QtQuick.Controls
        Qt6::qtquicktemplates2plugin        # QtQuick.Templates
        Qt6::qmlplugin                      # QtQml
        Qt6::modelsplugin                   # QtQml.Models
        Qt6::qtquickdialogsplugin           # QtQuick.Dialogs
    )
    foreach(_p IN LISTS _TENJIN_QML_PLUGIN_TARGETS)
        if(TARGET ${_p})
            target_link_libraries(Tenjin PRIVATE ${_p})
        endif()
    endforeach()
endif()

# Platform/iconengine/imageformat plugins are only needed (and only exist as
# static targets) on a static Qt. Gate on static-ness, not OS.
if(NOT QT6_IS_SHARED_LIBS_BUILD)
    qt_import_plugins(Tenjin
        INCLUDE_BY_TYPE platforms
        INCLUDE_BY_TYPE iconengines
        INCLUDE_BY_TYPE imageformats
    )
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_sources(Tenjin PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets"
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/PrivacyInfo.xcprivacy"
    )
    set_source_files_properties(
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources
    )
    # PrivacyInfo.xcprivacy must sit at the bundle root (not Resources/).
    set_source_files_properties(
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/PrivacyInfo.xcprivacy"
        PROPERTIES MACOSX_PACKAGE_LOCATION .
    )

    set(_TENJIN_IOS_PLIST_TEMPLATE "")
    foreach(_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info_plist.in"
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist.in"
        "${CMAKE_SOURCE_DIR}/App/ios/Info_plist.in"
    )
        if(EXISTS "${_candidate}")
            set(_TENJIN_IOS_PLIST_TEMPLATE "${_candidate}")
            break()
        endif()
    endforeach()
    if(NOT _TENJIN_IOS_PLIST_TEMPLATE)
        message(FATAL_ERROR "iOS Info.plist template not found.")
    endif()

    configure_file(
        "${_TENJIN_IOS_PLIST_TEMPLATE}"
        "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        @ONLY
    )

    set_target_properties(Tenjin PROPERTIES
        MACOSX_BUNDLE                               TRUE
        MACOSX_BUNDLE_INFO_PLIST                   "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        MACOSX_BUNDLE_BUNDLE_NAME                  "${TENJIN_APP_DISPLAY_NAME}"
        MACOSX_BUNDLE_BUNDLE_VERSION               "${TENJIN_BUILD_NUMBER}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING         "${PROJECT_VERSION}"
        MACOSX_BUNDLE_GUI_IDENTIFIER               "${TENJIN_BUNDLE_ID}"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER  "${TENJIN_BUNDLE_ID}"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${TENJIN_IOS_DEPLOYMENT_TARGET}"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY     "1,2"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED      "NO"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED       "NO"
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS     "${CMAKE_CURRENT_SOURCE_DIR}/ios/Tenjin.entitlements"
    )

    if(DEFINED APPLE_TEAM_ID)
        set_target_properties(Tenjin PROPERTIES
            XCODE_ATTRIBUTE_DEVELOPMENT_TEAM      "${APPLE_TEAM_ID}"
            XCODE_ATTRIBUTE_CODE_SIGN_STYLE       "Automatic"
            XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "YES"
            XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED  "YES"
        )
    endif()

    if(MEDIA_SUPPORT)
        # Tenjin only PLAYS audio/video (no recording/transcoding), so on iOS
        # the native AVFoundation backend (QDarwinMediaPlugin) is sufficient and
        # preferred. The aqt-installed Qt iOS kit links the static FFmpeg media
        # plugin (libQt6FFmpegMediaPluginImpl.a) but does NOT ship the FFmpeg
        # libraries it depends on, so every av_*/swr_*/sws_* symbol is undefined
        # at link. Exclude the FFmpeg plugin and import the Darwin one instead.
        qt_import_plugins(Tenjin
            INCLUDE Qt6::QDarwinMediaPlugin
            EXCLUDE Qt6::QFFmpegMediaPlugin
        )
    endif()
endif()

qt_finalize_executable(Tenjin)

install(TARGETS Tenjin
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Linux/macOS: CMake-driven deploy. Windows deliberately excluded — windeployqt
# in the Windows workflow owns the full self-contained bin\ tree (exe + Qt DLLs
# + plugins\ + qml\), which reliably deploys the imported QtQuick.Controls.Basic
# QML payload that the CMake script leaves empty for a STATIC app module.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    # Translations ship in the qrc; --no-translations avoids duplicating Qt's.
    qt_generate_deploy_qml_app_script(
        TARGET               Tenjin
        OUTPUT_SCRIPT        deploy_script
        DEPLOY_TOOL_OPTIONS  --no-translations
    )
    install(SCRIPT ${deploy_script})
endif()

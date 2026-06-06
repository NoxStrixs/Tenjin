qt_add_executable(Tenjin
    WIN32
    MANUAL_FINALIZATION
    src/main.cpp
)

set_target_properties(Tenjin PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    OUTPUT_NAME              "${TENJIN_APP_NAME}"
)

target_link_libraries(Tenjin
    PRIVATE
        TenjinViewModels
        TenjinViewplugin
        Qt6::Quick
        Qt6::QuickControls2
        tenjin_warnings
        tenjin_sanitizers
)

target_include_directories(Tenjin PRIVATE src)

# On a STATIC Qt build (iOS) the QSQLITE driver is a plugin that must be compiled into the binary.
if(TARGET Qt6::QSQLiteDriverPlugin)
    target_link_libraries(Tenjin PRIVATE Qt6::QSQLiteDriverPlugin)
endif()

# iOS static plugin imports.
# On a STATIC Qt build (always the case on iOS) the linker dead-strips any
# plugin not referenced from the executable's compiled code. QML module plugins
# are referenced only by name from QML source at runtime, so the linker drops
# them.
# Reference: Qt Wiki "Qt for iOS known issues" (QTBUG-35195) and forum.qt.io
# topics 153384 / 156448.
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    if(COMMAND qt_import_qml_plugins)
        qt_import_qml_plugins(Tenjin)
    endif()
    qt_import_plugins(Tenjin
        INCLUDE_BY_TYPE platforms
        INCLUDE_BY_TYPE iconengines
        INCLUDE_BY_TYPE imageformats
    )
    qt_finalize_executable(Tenjin)
    # Explicitly link the QML module plugin targets we know the UI imports.
    # Explicit links guarantee the plugins survive dead-stripping.
    foreach(_qmlplug
        # QtQuick core
        Qt6::qmlqquick2plugin
        Qt6::qtquick2plugin
        Qt6::quickplugin
        # QtQuick.Layouts
        Qt6::qquicklayoutsplugin
        Qt6::qtquicklayoutsplugin
        # QtQuick.Controls + Basic style
        Qt6::qtquickcontrols2plugin
        Qt6::qquickcontrols2plugin
        Qt6::qtquickcontrols2basicstyleplugin
        Qt6::qquickcontrols2basicstyleplugin
        Qt6::QQuickControls2BasicStylePlugin
        Qt6::qtquickcontrols2implplugin
        Qt6::qtquicktemplates2plugin
        Qt6::qquicktemplates2plugin
        # QtQuick.Dialogs
        Qt6::qtquickdialogs2plugin
        Qt6::qtquickdialogs2quickimplplugin
        Qt6::qquickdialogs2plugin
        Qt6::qquickdialogs2quickimplplugin
        Qt6::quickdialogs2plugin
        Qt6::quickdialogs2quickimplplugin
        Qt6::qtquickdialogsplugin
        Qt6::qtlabsplatformplugin
        Qt6::quicklabsplatformplugin
        # QtQml / Models
        Qt6::qmlplugin
        Qt6::qmlmodelsplugin
        Qt6::modelsplugin
        Qt6::qtqmlmodelsplugin
        Qt6::qmlfolderlistmodelplugin
        Qt6::qtlabsfolderlistmodelplugin
        # QtMultimedia
        Qt6::quickmultimediaplugin
        Qt6::multimediaquickplugin
        # QtWebView QML plugin
        Qt6::declarative_webviewplugin
        Qt6::qtwebviewplugin
        Qt6::webviewquickplugin
    )
        if(TARGET ${_qmlplug})
            target_link_libraries(Tenjin PRIVATE ${_qmlplug})
            message(STATUS "${TENJIN_APP_NAME} iOS: linked QML plugin ${_qmlplug}")
        endif()
    endforeach()

    # Diagnostic: list every QML plugin target Qt actually defines.
    get_property(_all_targets DIRECTORY "${CMAKE_SOURCE_DIR}" PROPERTY IMPORTED_TARGETS)
    message(STATUS "${TENJIN_APP_NAME} iOS: (see Qt plugin import scan results in build log)")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # CFBundleVersion must be a monotonically increasing build number.
    # Apple and AltStore reject re-installs with the same build number.
    if(NOT DEFINED TENJIN_BUILD_NUMBER)
        set(TENJIN_BUILD_NUMBER "1")
    endif()

    # The app icon asset catalog.
    # Adding it to the target's sources lets Xcode compile it into the bundle.
    # The matching name is set by XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME.
    target_sources(Tenjin PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets"
    )
    set_source_files_properties(
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources
    )

    # Info.plist is generated from a template so the .env can drive the
    # bundle identity.
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist.in"
        "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        @ONLY
    )

    set_target_properties(Tenjin PROPERTIES
        MACOSX_BUNDLE                              TRUE
        MACOSX_BUNDLE_INFO_PLIST                   "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        MACOSX_BUNDLE_BUNDLE_NAME                  "${TENJIN_APP_DISPLAY_NAME}"
        MACOSX_BUNDLE_BUNDLE_VERSION               "${TENJIN_BUILD_NUMBER}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING         "${PROJECT_VERSION}"
        MACOSX_BUNDLE_GUI_IDENTIFIER               "${TENJIN_BUNDLE_ID}"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER  "${TENJIN_BUNDLE_ID}"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${TENJIN_IOS_DEPLOYMENT_TARGET}"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY     "1,2"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
        # Default to "no team / sign later" so an unsigned device build succeeds
        # in CI; AltStore/Sideloadly/Xcode apply the real identity afterwards.
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED      "NO"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED       "NO"
    )

    # If you build & sign locally in Xcode, pass -DAPPLE_TEAM_ID=XXXXXXXXXX to
    # flip on automatic signing with your Apple ID team.
    if(DEFINED APPLE_TEAM_ID)
        set_target_properties(Tenjin PROPERTIES
            XCODE_ATTRIBUTE_DEVELOPMENT_TEAM          "${APPLE_TEAM_ID}"
            XCODE_ATTRIBUTE_CODE_SIGN_STYLE           "Automatic"
            XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED     "YES"
            XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED      "YES"
        )
    endif()

    # QtMultimedia on iOS uses FFmpeg as its media backend, but the
    # Qt installer does NOT auto-link the FFmpeg frameworks.
    # See: https://doc.qt.io/qt-6/qt-add-ios-ffmpeg-libraries.html
    if(MEDIA_SUPPORT)
        if(CMAKE_VERSION VERSION_LESS "3.28")
            message(FATAL_ERROR
                "iOS + MEDIA_SUPPORT=ON needs CMake >= 3.28 for qt_add_ios_ffmpeg_libraries. "
                "Either upgrade CMake, or configure with -DMEDIA_SUPPORT=OFF for iOS.")
        endif()
        if(COMMAND qt_add_ios_ffmpeg_libraries)
        else()
            message(FATAL_ERROR
                "qt_add_ios_ffmpeg_libraries is not available — Qt 6.8+ is required "
                "for iOS media support, or set -DMEDIA_SUPPORT=OFF.")
        endif()
    endif()
endif()

# Windows: install and windeployqt handled entirely in cmake/Packaging.cmake.
# Linux/macOS use the standard install and Qt deploy script.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    install(TARGETS Tenjin
        BUNDLE  DESTINATION .
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
    qt_generate_deploy_qml_app_script(
        TARGET               Tenjin
        OUTPUT_SCRIPT        deploy_script
        DEPLOY_TOOL_OPTIONS  --no-compiler-runtime --no-translations
    )
    install(SCRIPT ${deploy_script})
endif()


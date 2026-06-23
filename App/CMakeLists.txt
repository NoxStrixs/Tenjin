qt_add_executable(Tenjin
    WIN32
    MANUAL_FINALIZATION
    src/main.cpp
)

tenjin_configure_translations(${TENJIN_APP_NAME})

if(NOT DEFINED TENJIN_BUILD_NUMBER)
    set(TENJIN_BUILD_NUMBER "1")
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

# SQLite driver: on static Qt builds (iOS, Android) the plugin must be
# explicitly imported via Q_IMPORT_PLUGIN in main.cpp AND linked here.
# On macOS and Linux with shared Qt the driver loads dynamically at runtime —
# linking the static plugin target would cause a duplicate-symbol linker error.
if(IOS OR ANDROID OR QT_FEATURE_static)
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

if(ANDROID)
    set_target_properties(Tenjin PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_VERSION_NAME       "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE       "${TENJIN_BUILD_NUMBER}"
        QT_ANDROID_MIN_SDK_VERSION    "26"
        QT_ANDROID_TARGET_SDK_VERSION "34"
        QT_ANDROID_PACKAGE_NAME       "${TENJIN_BUNDLE_ID}"
    )
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    if(COMMAND qt_import_qml_plugins)
        qt_import_qml_plugins(Tenjin)
    endif()
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
        if(CMAKE_VERSION VERSION_LESS "3.28")
            message(FATAL_ERROR "iOS + MEDIA_SUPPORT=ON needs CMake >= 3.28")
        endif()
        if(COMMAND qt_add_ios_ffmpeg_libraries)
            qt_add_ios_ffmpeg_libraries(Tenjin)
        else()
            message(FATAL_ERROR "qt_add_ios_ffmpeg_libraries is not available.")
        endif()
    endif()
endif()

qt_finalize_executable(Tenjin)

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

# Packaging via CPack. Windows builds natively with MSVC (static /MT runtime,
# set in the preset), so Qt deployment is handled by windeployqt in the Windows
# CI workflow, not here. This file defines the desktop entry (Linux) and the
# CPack generator configuration (DEB + NSIS/ZIP). AppImage (Linux), .dmg
# (macOS), .ipa (iOS), and .aab/.apk (Android) are produced by their platform
# workflows; artifact naming is plain Tenjin-<version>-<platform>.<ext>.

include(GNUInstallDirs)

# ── Linux desktop entry ───────────────────────────────────────────────────────
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    configure_file(
        "${CMAKE_SOURCE_DIR}/packaging/linux/tenjin.desktop.in"
        "${CMAKE_BINARY_DIR}/generated/tenjin.desktop"
        @ONLY
    )
    install(FILES "${CMAKE_BINARY_DIR}/generated/tenjin.desktop"
            DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES "${CMAKE_SOURCE_DIR}/packaging/linux/tenjin.png"
            DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps)
endif()

# ── CPack common ──────────────────────────────────────────────────────────────
set(CPACK_PACKAGE_NAME              "${TENJIN_APP_NAME}")
set(CPACK_PACKAGE_VENDOR            "${TENJIN_ORG_NAME}")
set(CPACK_PACKAGE_VERSION           "${PROJECT_VERSION}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${TENJIN_APP_DESCRIPTION}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${TENJIN_APP_NAME}")
set(CPACK_PACKAGE_CONTACT           "${TENJIN_ORG_NAME} Maintainers <hello@${TENJIN_ORG_DOMAIN}>")
set(CPACK_RESOURCE_FILE_LICENSE     "${CMAKE_SOURCE_DIR}/LICENSE")
# Plain, store-clean artifact name (no build hash).
string(TOLOWER "${CMAKE_SYSTEM_NAME}" _tenjin_sys_lower)
set(CPACK_PACKAGE_FILE_NAME         "${TENJIN_APP_NAME}-${PROJECT_VERSION}-${_tenjin_sys_lower}")
set(CPACK_VERBATIM_VARIABLES        ON)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CPACK_GENERATOR "DEB")
    string(TOLOWER "${TENJIN_APP_NAME}" _tenjin_lower)
    set(CPACK_PACKAGING_INSTALL_PREFIX  "/opt/${_tenjin_lower}")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_DEBIAN_PACKAGE_SECTION    "education")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY   "optional")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS    "libc6, libstdc++6, libgcc-s1")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS  ON)
    set(CPACK_DEB_COMPONENT_INSTALL     OFF)

elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    # Native MSVC build. NSIS installer + portable ZIP. The install tree is
    # assembled by the Windows workflow's windeployqt step; CPack packages it.
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_EXECUTABLES_DIRECTORY ".")
    set(CPACK_PACKAGE_EXECUTABLES        "${TENJIN_APP_NAME}" "${TENJIN_APP_DISPLAY_NAME}")
    set(CPACK_NSIS_MUI_FINISHPAGE_RUN    "${TENJIN_APP_NAME}.exe")
    set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "${TENJIN_APP_NAME}SpacedRepetitionApp")
    set(CPACK_NSIS_PACKAGE_NAME          "${TENJIN_APP_DISPLAY_NAME}")
    set(CPACK_NSIS_DISPLAY_NAME          "${TENJIN_APP_DISPLAY_NAME}")
    set(CPACK_NSIS_HELP_LINK             "https://${TENJIN_ORG_DOMAIN}")
    set(CPACK_NSIS_URL_INFO_ABOUT        "https://${TENJIN_ORG_DOMAIN}")
    set(CPACK_NSIS_CONTACT               "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_NSIS_MODIFY_PATH           OFF)
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    # Installer/uninstaller wizard icon and the Add/Remove Programs icon, from
    # the same generated .ico as the exe (single source). Only set when the
    # icon was generated (App/CMakeLists.txt writes it to generated/tenjin.ico).
    if(EXISTS "${CMAKE_BINARY_DIR}/generated/tenjin.ico")
        set(CPACK_NSIS_MUI_ICON        "${CMAKE_BINARY_DIR}/generated/tenjin.ico")
        set(CPACK_NSIS_MUI_UNIICON     "${CMAKE_BINARY_DIR}/generated/tenjin.ico")
        set(CPACK_NSIS_INSTALLED_ICON_NAME "${TENJIN_APP_NAME}.exe")
    endif()
    # Exe + qt.conf sit at install ROOT (windeployqt stage\bin flattened via
    # CPACK_INSTALLED_DIRECTORIES). qt.conf Prefix=. resolves plugins\ and qml\
    # relative to the launch working dir, so the shortcut MUST set workdir to
    # $INSTDIR or a Start-Menu launch reports "no platform plugin".
    # CreateShortCut: link target params icon idx showmode hotkey workdir
    set(CPACK_NSIS_CREATE_ICONS_EXTRA "
        SetShellVarContext all
        CreateShortCut '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}\\\\${TENJIN_APP_DISPLAY_NAME}.lnk' '\$INSTDIR\\\\${TENJIN_APP_NAME}.exe' '' '\$INSTDIR\\\\${TENJIN_APP_NAME}.exe' 0 SW_SHOWNORMAL '' '\$INSTDIR'
    ")
    set(CPACK_NSIS_DELETE_ICONS_EXTRA "
        SetShellVarContext all
        Delete '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}\\\\${TENJIN_APP_DISPLAY_NAME}.lnk'
        RMDir  '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}'
    ")
endif()

include(CPack)

# Windows: a self-contained install tree assembled by windeployqt (run under
#   wine64), then packaged as an NSIS installer + portable ZIP via CPack.
# Linux:   .deb via CPack + AppImage via linuxdeploy (driven from package.py).

include(GNUInstallDirs)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    find_program(WINDEPLOYQT_WINE windeployqt-wine)
    if(NOT WINDEPLOYQT_WINE)
        message(WARNING
            "windeployqt-wine not on PATH — Qt runtime will NOT be deployed. "
            "Build inside the tenjin-windows Docker image.")
    endif()

    set(_TENJIN_QML_DIR "${CMAKE_SOURCE_DIR}/View")
    set(_TENJIN_EXE     "${CMAKE_BINARY_DIR}/bin/${TENJIN_APP_NAME}.exe")

    # MinGW runtime DLLs: windeployqt is ran with --no-compiler-runtime
    # because under wine it can't reliably locate the Ubuntu cross-toolchain's
    # runtime, so we stage them ourselves.
    set(_MINGW_RUNTIME "")
    foreach(_dll
        /usr/lib/gcc/x86_64-w64-mingw32/13-posix/libgcc_s_seh-1.dll
        /usr/lib/gcc/x86_64-w64-mingw32/13-posix/libstdc++-6.dll
        /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll
    )
        if(EXISTS "${_dll}")
            list(APPEND _MINGW_RUNTIME "${_dll}")
        endif()
    endforeach()

    install(CODE "
        set(_bindir \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}\")
        file(MAKE_DIRECTORY \"\${_bindir}\")

        # 1. Stage the executable (file(COPY) sidesteps the install(TARGETS)
        #    .exe-suffix bug for cross-compiled PE binaries).
        message(STATUS \"Staging ${TENJIN_APP_NAME}.exe -> \${_bindir}\")
        file(COPY \"${_TENJIN_EXE}\" DESTINATION \"\${_bindir}\")

        # 2. Stage MinGW runtime DLLs.
        foreach(_rt ${_MINGW_RUNTIME})
            file(COPY \"\${_rt}\" DESTINATION \"\${_bindir}\")
        endforeach()

        # 3. Run windeployqt on the staged exe. It writes Qt DLLs next to the
        #    exe and creates plugins/ and qml/ subfolders in the same dir.
        set(_exe \"\${_bindir}/${TENJIN_APP_NAME}.exe\")
        if(NOT EXISTS \"\${_exe}\")
            message(FATAL_ERROR \"Staged executable missing: \${_exe}\")
        endif()
        message(STATUS \"Running windeployqt (wine) on \${_exe}\")
        execute_process(
            COMMAND \"${WINDEPLOYQT_WINE}\"
                --release
                --qmldir \"${_TENJIN_QML_DIR}\"
                --no-translations
                --no-system-d3d-compiler
                --no-opengl-sw
                --no-compiler-runtime
                --verbose 1
                \"\${_exe}\"
            RESULT_VARIABLE _rc
        )
        if(NOT _rc EQUAL 0)
            message(FATAL_ERROR \"windeployqt failed (exit \${_rc})\")
        endif()
    ")
endif()

# Linux desktop entry
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # Generate the desktop file in the build tree from packaging/linux/tenjin.desktop.in
    # then install it. The filename on disk stays "tenjin.desktop" so existing
    # menu indexes don't re-register.
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

# CPack
set(CPACK_PACKAGE_NAME              "${TENJIN_APP_NAME}")
set(CPACK_PACKAGE_VENDOR            "${TENJIN_ORG_NAME}")
set(CPACK_PACKAGE_VERSION           ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${TENJIN_APP_DESCRIPTION}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${TENJIN_APP_NAME}")
set(CPACK_PACKAGE_CONTACT           "${TENJIN_ORG_NAME} Maintainers <hello@${TENJIN_ORG_DOMAIN}>")
set(CPACK_RESOURCE_FILE_LICENSE     ${CMAKE_SOURCE_DIR}/LICENSE)
set(CPACK_PACKAGE_FILE_NAME
    "${TENJIN_APP_NAME}-${PROJECT_VERSION}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
set(CPACK_VERBATIM_VARIABLES        ON)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CPACK_GENERATOR "DEB")
    # Lowercased app name for the install prefix — Debian convention.
    string(TOLOWER "${TENJIN_APP_NAME}" _tenjin_lower)
    set(CPACK_PACKAGING_INSTALL_PREFIX  "/opt/${_tenjin_lower}")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_DEBIAN_PACKAGE_SECTION    "education")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY   "optional")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS    "libc6, libstdc++6, libgcc-s1")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS  ON)
    set(CPACK_DEB_COMPONENT_INSTALL     OFF)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CPACK_GENERATOR "NSIS;ZIP")

    # The whole install tree lives under bin/; tell NSIS the launchable exe is
    # there so Start Menu / desktop shortcuts point at it.
    set(CPACK_NSIS_EXECUTABLES_DIRECTORY "bin")
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

    # Start Menu shortcut (install and uninstall).
    set(CPACK_NSIS_CREATE_ICONS_EXTRA "
        SetShellVarContext all
        CreateShortCut '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}\\\\${TENJIN_APP_DISPLAY_NAME}.lnk' '\$INSTDIR\\\\bin\\\\${TENJIN_APP_NAME}.exe'
    ")
    set(CPACK_NSIS_DELETE_ICONS_EXTRA "
        SetShellVarContext all
        Delete '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}\\\\${TENJIN_APP_DISPLAY_NAME}.lnk'
        RMDir  '\$SMPROGRAMS\\\\${TENJIN_APP_DISPLAY_NAME}'
    ")
endif()

include(CPack)


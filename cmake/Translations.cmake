include_guard(GLOBAL)

macro(tenjin_configure_translations TARGET_NAME)
    set(TENJIN_UI_LANGUAGES
        ja es fr de zh_CN pt ko it ru ar
        CACHE STRING "ISO 639-1 codes to ship UI translations for.")

    find_package(Qt6 6.8 QUIET COMPONENTS LinguistTools)
    if(NOT Qt6LinguistTools_FOUND)
        message(WARNING "Tenjin i18n: Qt6 LinguistTools not found; UI will be English-only.")
    else()
        set(_ts_files)
        foreach(lang IN LISTS TENJIN_UI_LANGUAGES)
            list(APPEND _ts_files "${CMAKE_SOURCE_DIR}/translations/tenjin_${lang}.ts")
        endforeach()

        # qt_add_translations(), when called without SOURCE_TARGETS, normally
        # defers its auto-detection of translatable targets to the end of the
        # top-level directory scope (so it can see every target in the
        # project). That deferral is incompatible with OUTPUT_TARGETS below
        # -- the output variable can't be populated until the deferred call
        # actually runs -- so we replicate the auto-detection ourselves,
        # synchronously, right now. By the time this macro runs (from
        # App/CMakeLists.txt, added last in the root CMakeLists.txt),
        # Service/ViewModels/View have already defined their targets, so
        # scanning from CMAKE_SOURCE_DIR picks up the same set of targets
        # qt_add_translations would have found on its own.
        qt_collect_translation_source_targets(_i18n_source_targets DIRECTORY "${CMAKE_SOURCE_DIR}")

        # On a STATIC Qt build (iOS is always static) qt_add_translations()'s
        # RESOURCE_PREFIX embedding creates an extra resource target (here:
        # "${TARGET_NAME}_${TARGET_NAME}_translations") that ends up owning
        # the *same* generated .qm files as the "${TARGET_NAME}_lrelease"
        # custom command. Under the Xcode "new build system" a generated
        # file's custom command may only be attached to multiple targets if
        # one of them is a dependency of the other(s) -- otherwise CMake's
        # Xcode generator fails with:
        #   "The custom command generating .../tenjin_xx.qm is attached to
        #    multiple targets ... but none of these is a common dependency
        #    of the other(s). This is not allowed by the Xcode 'new build
        #    system'."
        # OUTPUT_TARGETS lets us capture that extra resource target so we
        # can add the missing dependency edge ourselves. On non-static (Qt
        # shared-library) builds -- macOS, Linux, Windows -- no extra target
        # is created and this is a no-op.
        set(_i18n_output_targets)
        qt_add_translations(${TARGET_NAME}
            SOURCE_TARGETS  ${_i18n_source_targets}
            TS_FILES        ${_ts_files}
            RESOURCE_PREFIX "/i18n"
            LUPDATE_OPTIONS -locations none -no-obsolete
            OUTPUT_TARGETS  _i18n_output_targets
        )
        if(_i18n_output_targets)
            add_dependencies(${_i18n_output_targets} ${TARGET_NAME}_lrelease)
        endif()

        message(STATUS "Tenjin i18n: Translation pipeline attached successfully to ${TARGET_NAME}")
    endif()
endmacro()

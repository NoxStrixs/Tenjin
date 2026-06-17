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

        # Safely called inside the exact directory context where the target exists
        qt_add_translations(${TARGET_NAME}
            TS_FILES        ${_ts_files}
            RESOURCE_PREFIX "/i18n"
            LUPDATE_OPTIONS -locations none -no-obsolete
        )
        message(STATUS "Tenjin i18n: Translation pipeline attached successfully to ${TARGET_NAME}")
    endif()
endmacro()

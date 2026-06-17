include_guard(GLOBAL)

set(TENJIN_UI_LANGUAGES
    ja es fr de zh_CN pt ko it ru ar
    CACHE STRING "ISO 639-1 codes to ship UI translations for.")

find_package(Qt6 6.8 QUIET COMPONENTS LinguistTools)
if(NOT Qt6LinguistTools_FOUND)
    message(WARNING
        "Tenjin i18n: Qt6 LinguistTools not found; UI will be English-only. "
        "Install the qttranslations / linguist component of Qt.")
    return()
endif()

# Define absolute paths so that regardless of where this file is included,
# the translation source files are accurately targeted.
set(_ts_files)
foreach(lang IN LISTS TENJIN_UI_LANGUAGES)
    list(APPEND _ts_files "${CMAKE_SOURCE_DIR}/translations/tenjin_${lang}.ts")
endforeach()

# qt_add_translations creates its own underlying target to build the .qm files.
# By feeding it the absolute paths, we don't need any extra manual lifecycle hooks.
qt_add_translations(${TENJIN_APP_NAME}
    TS_FILES        ${_ts_files}
    RESOURCE_PREFIX "/i18n"
    LUPDATE_OPTIONS -locations none -no-obsolete
)

message(STATUS "Tenjin i18n: Successfully configured translation pipeline for target ${TENJIN_APP_NAME}")

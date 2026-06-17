# cmake/Translations.cmake
#
# Wires the .ts -> .qm pipeline into the build:
#   * lupdate extracts qsTr() strings from QML+C++ into translations/*.ts
#   * lrelease compiles .ts -> .qm at build time
#   * qt_add_translations embeds the .qm files in the app's qrc under /i18n

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

# Use paths relative to the source directory so the CMake Xcode generator
# correctly deduplicates the .qm generation custom commands.
set(_ts_files)
foreach(lang IN LISTS TENJIN_UI_LANGUAGES)
    list(APPEND _ts_files "translations/tenjin_${lang}.ts")
endforeach()

# Embeds .qm files in ${TENJIN_APP_NAME}'s qrc under /i18n.
qt_add_translations(${TENJIN_APP_NAME}
    TS_FILES        ${_ts_files}
    RESOURCE_PREFIX "/i18n"
    LUPDATE_OPTIONS -locations none -no-obsolete
)

message(STATUS "Tenjin i18n: ${TENJIN_UI_LANGUAGES}")

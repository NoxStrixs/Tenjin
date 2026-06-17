include_guard(GLOBAL)

set(TENJIN_UI_LANGUAGES
    ja es fr de zh_CN pt ko it ru ar
    CACHE STRING "ISO 639-1 codes to ship UI translations for.")

find_package(Qt6 6.8 QUIET COMPONENTS LinguistTools)
if(NOT Qt6LinguistTools_FOUND)
    message(WARNING
        "Tenjin i18n: Qt6 LinguistTools not found; UI will be English-only. ")
    return()
endif()

set(_ts_files)
foreach(lang IN LISTS TENJIN_UI_LANGUAGES)
    list(APPEND _ts_files "translations/tenjin_${lang}.ts")
endforeach()

# OMIT_FROM_ALL stops default global rules from conflicting on Xcode
qt_add_translations(${TENJIN_APP_NAME}
    TS_FILES        ${_ts_files}
    RESOURCE_PREFIX "/i18n"
    OMIT_FROM_ALL
    LUPDATE_OPTIONS -locations none -no-obsolete
)

# Explicitly wire lrelease to compile relative paths during the executable target's build pass
qt_add_lrelease(${TENJIN_APP_NAME}
    TS_FILES ${_ts_files}
)

message(STATUS "Tenjin i18n safely configured for Xcode target: ${TENJIN_APP_NAME}")

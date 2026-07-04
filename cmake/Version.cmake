# Single source of truth for version data.
#
# Canonical version = project(VERSION major.minor.patch) in the root CMakeLists.
# From it we derive:
#   TENJIN_VERSION            major.minor.patch          (plain semver core)
#   TENJIN_GIT_HASH           git describe --tags --dirty (build identity)
#   TENJIN_VERSION_STRING     major.minor.patch+<hash>    (display / logs)
#   TENJIN_VERSION_CODE       monotonic integer           (Android versionCode)
#
# Store fields (iOS CFBundleShortVersionString, Android versionName) use the
# plain TENJIN_VERSION; the +hash form is display-only and never submitted.

function(tenjin_resolve_version)
    set(_ver "${PROJECT_VERSION}")
    if(NOT _ver)
        message(FATAL_ERROR "tenjin_resolve_version: project(VERSION) is unset")
    endif()

    find_package(Git QUIET)
    set(_hash "nogit")
    set(_count "0")

    if(Git_FOUND AND EXISTS "${CMAKE_SOURCE_DIR}/.git")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" describe --tags --dirty --always
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE _hash
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(NOT _hash)
            set(_hash "nogit")
        endif()

        # Monotonic build counter for Android versionCode.
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE _count
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(NOT _count)
            set(_count "0")
        endif()
    endif()

    # Android versionCode must be a positive, strictly increasing integer.
    # Encode as MMmmppNNNN-ish via commit count so every landed commit bumps it.
    math(EXPR _code
        "${PROJECT_VERSION_MAJOR} * 1000000 + ${PROJECT_VERSION_MINOR} * 10000 + ${PROJECT_VERSION_PATCH} * 100 + (${_count} % 100)")

    set(TENJIN_VERSION        "${_ver}"                  PARENT_SCOPE)
    set(TENJIN_GIT_HASH       "${_hash}"                 PARENT_SCOPE)
    set(TENJIN_VERSION_STRING "${_ver}+${_hash}"         PARENT_SCOPE)
    set(TENJIN_VERSION_CODE   "${_code}"                 PARENT_SCOPE)

    message(STATUS "Tenjin version: ${_ver}+${_hash} (code ${_code})")
endfunction()

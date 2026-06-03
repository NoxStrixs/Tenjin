function(tenjin_dotenv_load _path)
    if(NOT EXISTS "${_path}")
        message(STATUS "DotEnv: no file at ${_path} — skipping (defaults will apply).")
        return()
    endif()

    set_property(
        DIRECTORY APPEND
        PROPERTY CMAKE_CONFIGURE_DEPENDS "${_path}"
    )

    file(STRINGS "${_path}" _lines)
    set(_count 0)
    foreach(_line IN LISTS _lines)
        # Trim leading whitespace
        string(REGEX REPLACE "^[ \t]+" "" _line "${_line}")

        # Skip blanks and comments.
        if("${_line}" STREQUAL "")
            continue()
        endif()
        if(_line MATCHES "^#")
            continue()
        endif()

        # KEY = value form
        if(NOT _line MATCHES "^([A-Za-z_][A-Za-z0-9_]*)[ \t]*=(.*)$")
            message(WARNING "DotEnv: skipping malformed line: ${_line}")
            continue()
        endif()

        set(_key "${CMAKE_MATCH_1}")
        set(_value "${CMAKE_MATCH_2}")

        # Strip ONE pair of surrounding quotes
        string(REGEX REPLACE "^[ \t]+" "" _value "${_value}")
        string(REGEX REPLACE "[ \t]+$" "" _value "${_value}")
        if(_value MATCHES "^\"(.*)\"$")
            set(_value "${CMAKE_MATCH_1}")
        elseif(_value MATCHES "^'(.*)'$")
            set(_value "${CMAKE_MATCH_1}")
        endif()

        set(${_key} "${_value}" PARENT_SCOPE)
        math(EXPR _count "${_count} + 1")
    endforeach()

    message(STATUS "DotEnv: loaded ${_count} variable(s) from ${_path}.")
endfunction()


# Apply a default to a variable if it is currently undefined or empty.
function(tenjin_dotenv_default _key _default)
    if(NOT DEFINED ${_key} OR "${${_key}}" STREQUAL "")
        set(${_key} "${_default}" PARENT_SCOPE)
    endif()
endfunction()


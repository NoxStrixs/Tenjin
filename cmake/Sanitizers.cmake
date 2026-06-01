# ─── Sanitizers ───────────────────────────────────────────────────────────────
# Emits an interface target `tenjin_sanitizers` that other targets can link
# against to inherit -fsanitize=… flags. The set is parsed from the comma-
# separated SANITIZERS option (e.g. -DSANITIZERS=asan,lsan,ubsan).
#
# Combinations that don't work (tsan + asan, msan + asan) are rejected. msan is
# clang-only; we still set the flag and let the toolchain complain if absent.

add_library(tenjin_sanitizers INTERFACE)

if(SANITIZERS)
    string(REPLACE "," ";" _sanitizers "${SANITIZERS}")

    if("tsan" IN_LIST _sanitizers AND ("asan" IN_LIST _sanitizers OR "lsan" IN_LIST _sanitizers))
        message(FATAL_ERROR "TSan is mutually exclusive with ASan/LSan")
    endif()

    set(_flags "")
    foreach(s IN LISTS _sanitizers)
        if(s STREQUAL "asan")
            list(APPEND _flags -fsanitize=address)
        elseif(s STREQUAL "lsan")
            list(APPEND _flags -fsanitize=leak)
        elseif(s STREQUAL "tsan")
            list(APPEND _flags -fsanitize=thread)
        elseif(s STREQUAL "ubsan")
            list(APPEND _flags -fsanitize=undefined)
        elseif(s STREQUAL "msan")
            list(APPEND _flags -fsanitize=memory)
        else()
            message(WARNING "Unknown sanitizer '${s}' — ignoring")
        endif()
    endforeach()

    if(_flags)
        # Frame pointers improve stack traces from sanitizer reports.
        list(APPEND _flags -fno-omit-frame-pointer)
        target_compile_options(tenjin_sanitizers INTERFACE ${_flags})
        target_link_options   (tenjin_sanitizers INTERFACE ${_flags})
        message(STATUS "Sanitizers enabled: ${_sanitizers}")
    endif()
endif()

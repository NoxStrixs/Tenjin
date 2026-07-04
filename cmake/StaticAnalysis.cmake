# Optional static-analysis integration. Off by default so normal builds stay
# fast; enable with -DTENJIN_ENABLE_CLANG_TIDY=ON / -DTENJIN_ENABLE_CPPCHECK=ON.
# Ruleset tightening is deferred to the dead-code sweep; this wires the runners.

option(TENJIN_ENABLE_CLANG_TIDY "Run clang-tidy during compilation" OFF)
option(TENJIN_ENABLE_CPPCHECK   "Run cppcheck during compilation"   OFF)

if(TENJIN_ENABLE_CLANG_TIDY)
    find_program(CLANG_TIDY_EXE NAMES clang-tidy)
    if(CLANG_TIDY_EXE)
        # .clang-tidy at the repo root supplies the checks.
        set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_EXE}" CACHE STRING "" FORCE)
        message(STATUS "clang-tidy: ${CLANG_TIDY_EXE}")
    else()
        message(WARNING "TENJIN_ENABLE_CLANG_TIDY=ON but clang-tidy not found")
    endif()
endif()

if(TENJIN_ENABLE_CPPCHECK)
    find_program(CPPCHECK_EXE NAMES cppcheck)
    if(CPPCHECK_EXE)
        set(CMAKE_CXX_CPPCHECK
            "${CPPCHECK_EXE}"
            "--enable=warning,performance,portability"
            "--inline-suppr"
            "--std=c++23"
            "--error-exitcode=1"
            "--suppress=missingIncludeSystem"
            CACHE STRING "" FORCE)
        message(STATUS "cppcheck: ${CPPCHECK_EXE}")
    else()
        message(WARNING "TENJIN_ENABLE_CPPCHECK=ON but cppcheck not found")
    endif()
endif()

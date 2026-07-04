# Hermetic dependency vendoring (Linux-kernel model: in-tree, pinned exact rev).
#
# All third-party C++ libraries are fetched at configure time, pinned to an
# exact commit, and built from source into the tree. No system packages are
# consulted (fully reproducible across all five toolchains, including the
# iOS/Android sandboxes). Only permissive licenses are permitted
# (MIT / BSD / Apache-2.0 / BSL-1.0 / zlib) — no copyleft, no fees.

include_guard(GLOBAL)
include(FetchContent)

# Force fully hermetic resolution: never fall back to find_package/system libs.
set(FETCHCONTENT_TRY_FIND_PACKAGE_MODE NEVER CACHE STRING "" FORCE)

set(TENJIN_VENDOR_ALLOWED_LICENSES "MIT;BSD-2-Clause;BSD-3-Clause;Apache-2.0;BSL-1.0;Zlib")

# tenjin_vendor(<name>
#     GIT_REPOSITORY <url>
#     GIT_TAG        <tag>      # human-readable release tag
#     GIT_SHA        <sha>      # exact commit, pinned for reproducibility
#     LICENSE        <spdx>     # must be in TENJIN_VENDOR_ALLOWED_LICENSES
#     [SOURCE_SUBDIR <dir>])
#
# Declares and makes the dependency available. Pinning by GIT_SHA guarantees the
# tree is byte-identical regardless of tag movement.
function(tenjin_vendor NAME)
    cmake_parse_arguments(V "" "GIT_REPOSITORY;GIT_TAG;GIT_SHA;LICENSE;SOURCE_SUBDIR" "" ${ARGN})

    if(NOT V_LICENSE)
        message(FATAL_ERROR "tenjin_vendor(${NAME}): LICENSE is required")
    endif()
    if(NOT V_LICENSE IN_LIST TENJIN_VENDOR_ALLOWED_LICENSES)
        message(FATAL_ERROR
            "tenjin_vendor(${NAME}): license '${V_LICENSE}' is not permitted. "
            "Allowed: ${TENJIN_VENDOR_ALLOWED_LICENSES}")
    endif()
    if(NOT V_GIT_SHA)
        message(FATAL_ERROR "tenjin_vendor(${NAME}): GIT_SHA is required for reproducible pinning")
    endif()

    set(_subdir_arg "")
    if(V_SOURCE_SUBDIR)
        set(_subdir_arg SOURCE_SUBDIR "${V_SOURCE_SUBDIR}")
    endif()

    FetchContent_Declare(${NAME}
        GIT_REPOSITORY "${V_GIT_REPOSITORY}"
        GIT_TAG        "${V_GIT_SHA}"       # pin to exact SHA, not movable tag
        GIT_SHALLOW    FALSE
        ${_subdir_arg}
    )
    FetchContent_MakeAvailable(${NAME})
    message(STATUS "Vendored ${NAME} @ ${V_GIT_TAG} (${V_GIT_SHA}) [${V_LICENSE}]")
endfunction()

# ── Example declaration (pattern only — no new dependency added in Stage 1) ───
# miniz remains as-is (cmake/Miniz.cmake) until the Stage 4 dedup pass. When a
# real FOSS library is introduced, declare it like this:
#
# tenjin_vendor(nlohmann_json
#     GIT_REPOSITORY https://github.com/nlohmann/json.git
#     GIT_TAG        v3.11.3
#     GIT_SHA        9cca280a4d0ccf0c08f47a99aa71d1b0e52f8d03
#     LICENSE        MIT)
# target_link_libraries(<target> PRIVATE nlohmann_json::nlohmann_json)

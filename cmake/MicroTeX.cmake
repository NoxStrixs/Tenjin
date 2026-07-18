# MicroTeX.cmake — MicroTeX (LaTeX math typesetting) as a clean STATIC target.
#
# MicroTeX is an MIT-licensed, embeddable LaTeX math renderer. It parses LaTeX
# into a box model and draws through an abstract Graphics2D interface, so the
# host supplies the drawing backend — for Tenjin that's QPainter
# (ViewModels/src/MicroTexGraphics_qt.cpp).
#
# Why we build it ourselves rather than add_subdirectory(MicroTeX):
#   * Upstream's CMake is built around a SHARED library with a runtime-loaded
#     graphics backend (see upstream issue #130). iOS forbids dynamic loading of
#     app code and requires static linking, so that model is unusable for us.
#     Compiling the sources directly into a static target sidesteps it entirely.
#   * Its CMakeLists declares its own project(), builds demos/samples, and pulls
#     GTK/Cairo or Gdiplus depending on platform — none of which we want, and
#     which break cross-compilation (same failure mode documented in Miniz.cmake).
#   * We need the parent toolchain's flags (C++23, -Werror settings, iOS/Android
#     sysroots) applied consistently.
#
# Fonts/resources: MicroTeX loads its res/ tree (TrueType fonts + XML symbol,
# parser and mapping tables, ~2 MB) from a FILESYSTEM path at runtime — see
# LaTeX::init(res_root_path) and `extern std::string RES_BASE` in common.h. This
# module bundles res/ into Qt resources at :/microtex/res; FormulaItem extracts
# it to a writable directory on first run and passes that path to init(), which
# is what allows it to work inside the iOS sandbox.

include_guard(GLOBAL)
# Vendor.cmake is already included by the root CMakeLists before this module, but
# include it explicitly (absolute path; it has include_guard(GLOBAL) so this is a
# no-op) so the module doesn't depend on include order.
include(FetchContent)
include("${CMAKE_CURRENT_LIST_DIR}/Vendor.cmake")

# Pinned to an exact commit by tenjin_vendor (a movable branch would make builds
# irreproducible). To update: bump both TAG and SHA together after testing.
set(TENJIN_MICROTEX_TAG "master" CACHE STRING
    "MicroTeX release tag this SHA corresponds to (documentation only).")
set(TENJIN_MICROTEX_SHA "0e3707f6dafebb121d98b53c64364d16fefe481d" CACHE STRING
    "MicroTeX commit to vendor (refs/heads/master as tested). Override with -D to bump.")

# The SHA above pins refs/heads/master as of the commit this was tested against.
# master moves, so to update MicroTeX: get the new commit and bump the pin —
#
#   git ls-remote https://github.com/NanoMichael/MicroTeX.git master
#
# then set TENJIN_MICROTEX_SHA here, or override for a one-off with
# -DTENJIN_MICROTEX_SHA=<sha>. The guard below stays so a blanked SHA fails loudly
# rather than silently tracking a moving branch.
if(NOT TENJIN_MICROTEX_SHA)
    message(FATAL_ERROR
        "MicroTeX: TENJIN_MICROTEX_SHA is empty.\n"
        "Vendoring pins dependencies to an exact commit (cmake/Vendor.cmake). "
        "Restore the pin in cmake/MicroTeX.cmake or pass -DTENJIN_MICROTEX_SHA=<sha>.\n"
        "Current upstream master:  "
        "git ls-remote https://github.com/NanoMichael/MicroTeX.git master")
endif()

# Declared through tenjin_vendor so MicroTeX gets the same treatment as every
# other third-party library: license checked against the allow-list (MIT is
# permitted), pinned to an exact SHA, built from source in-tree, and never
# resolved from system packages.
#
# SOURCE_SUBDIR points at a directory that doesn't exist so the source is
# downloaded WITHOUT configuring MicroTeX's own CMakeLists — that would build a
# shared library plus demos and re-run compiler detection. We compile the
# sources ourselves below (same approach as cmake/Miniz.cmake).
tenjin_vendor(microtex
    GIT_REPOSITORY https://github.com/NanoMichael/MicroTeX.git
    GIT_TAG        ${TENJIN_MICROTEX_TAG}
    GIT_SHA        ${TENJIN_MICROTEX_SHA}
    LICENSE        MIT
    SOURCE_SUBDIR  _tenjin_no_cmake
)

# Resolve the fetched source directory explicitly. FetchContent_MakeAvailable
# runs inside tenjin_vendor(), so ${microtex_SOURCE_DIR} isn't reliably visible
# here through normal scoping; FetchContent_GetProperties reads FetchContent's
# global bookkeeping and works from any scope. Cache it so the resource function
# (called later from ViewModels/CMakeLists.txt, a different scope) can reuse it.
FetchContent_GetProperties(microtex)
if(NOT microtex_SOURCE_DIR)
    message(FATAL_ERROR
        "MicroTeX: could not resolve the fetched source directory. "
        "The clone may have failed — check the FetchContent output above.")
endif()
set(TENJIN_MICROTEX_SOURCE_DIR "${microtex_SOURCE_DIR}"
    CACHE INTERNAL "MicroTeX fetched source tree")

# MicroTeX's core lives under src/ (parser, box model, atoms, fonts, utils).
# The platform graphics backends live in src/platform/* — we exclude ALL of them
# and supply our own QPainter backend in the ViewModels layer instead. Samples
# and the memory-check main() are excluded too (they define main()).
file(GLOB_RECURSE _microtex_srcs CONFIGURE_DEPENDS
    "${TENJIN_MICROTEX_SOURCE_DIR}/src/*.cpp")
list(FILTER _microtex_srcs EXCLUDE REGEX "/src/platform/")
list(FILTER _microtex_srcs EXCLUDE REGEX "/samples?/")
list(FILTER _microtex_srcs EXCLUDE REGEX "/test/")

if(NOT _microtex_srcs)
    message(FATAL_ERROR
        "MicroTeX: no sources found under ${TENJIN_MICROTEX_SOURCE_DIR}/src. "
        "The fetch may have failed or the upstream layout changed — check "
        "whether src/ was renamed and update cmake/MicroTeX.cmake.")
endif()

add_library(microtex STATIC ${_microtex_srcs})
add_library(MicroTeX::microtex ALIAS microtex)

# MicroTeX's common.h does #include "config.h", which upstream GENERATES from
# config.h.in during its own CMake/meson configure. Because we deliberately skip
# their build system (see above), nothing produces it and every TU fails on the
# missing include. Generate a minimal one ourselves into the build tree.
#
# The flags below mirror the defaults upstream sets for a release build:
#   HAVE_LOG       - parse-tree logging to stdout; off in a shipped app.
#   GRAPHICS_DEBUG - draws box outlines over formulas; off.
# If a future upstream config.h.in grows required entries, this file is where to
# add them (compare against ${TENJIN_MICROTEX_SOURCE_DIR}/config.h.in).
set(_microtex_cfg_dir "${CMAKE_BINARY_DIR}/microtex-config")
file(MAKE_DIRECTORY "${_microtex_cfg_dir}")
file(WRITE "${_microtex_cfg_dir}/config.h"
"// Generated by Tenjin's cmake/MicroTeX.cmake — do not edit.
// Replaces the config.h that MicroTeX's own build system would emit.
#ifndef CONFIG_H_INCLUDED
#define CONFIG_H_INCLUDED

// Logging/debug drawing disabled for shipped builds.
/* #undef HAVE_LOG */
/* #undef GRAPHICS_DEBUG */

// We supply our own QPainter backend rather than any bundled platform one.
/* #undef BUILD_GTK */
/* #undef BUILD_QT */
/* #undef BUILD_WIN32 */
/* #undef BUILD_SKIA */

#endif  // CONFIG_H_INCLUDED
")

target_include_directories(microtex SYSTEM PUBLIC
    "${_microtex_cfg_dir}")

# MicroTeX's XML parsers (res/parser/*.h) #include <tinyxml2.h>. Upstream's own
# CMake provides it; since we bypass that build, we vendor tinyxml2 ourselves. It
# is Zlib-licensed and has a clean, well-behaved CMake, so unlike MicroTeX it can
# be built through its own build system — no bypass needed.
#
# SHA is intentionally empty — same reasoning as MicroTeX's: a reproducibility
# pin must be a commit you've actually built, not a guess. Fill it from:
#   git ls-remote https://github.com/leethomason/tinyxml2.git 10.0.0
# (10.0.0 is the current stable tag; use whatever you test against.)
set(TENJIN_TINYXML2_SHA "321ea883b7190d4e85cae5512a12e5eaa8f8731f" CACHE STRING
    "tinyxml2 commit to vendor (tag 10.0.0, as tested). Override with -D to bump.")
if(NOT TENJIN_TINYXML2_SHA)
    message(FATAL_ERROR
        "MicroTeX: TENJIN_TINYXML2_SHA is empty. Restore the pin in "
        "cmake/MicroTeX.cmake or pass -DTENJIN_TINYXML2_SHA=<sha>.")
endif()
# tinyxml2's CMake honours BUILD_SHARED_LIBS and can default to a shared lib,
# which breaks the iOS static-link requirement and complicates deployment
# elsewhere. Force static for the duration of this vendor call, then restore.
set(_tenjin_saved_bsl "${BUILD_SHARED_LIBS}")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
tenjin_vendor(tinyxml2
    GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
    GIT_TAG        10.0.0
    GIT_SHA        ${TENJIN_TINYXML2_SHA}
    LICENSE        Zlib
)
set(BUILD_SHARED_LIBS "${_tenjin_saved_bsl}" CACHE BOOL "" FORCE)
# tinyxml2's CMake defines the target `tinyxml2` (namespaced alias
# tinyxml2::tinyxml2 exists in recent releases). Prefer the alias, fall back to
# the bare target if this tinyxml2 version predates it.
if(TARGET tinyxml2::tinyxml2)
    target_link_libraries(microtex PRIVATE tinyxml2::tinyxml2)
elseif(TARGET tinyxml2)
    target_link_libraries(microtex PRIVATE tinyxml2)
else()
    message(FATAL_ERROR
        "MicroTeX: tinyxml2 was vendored but neither tinyxml2::tinyxml2 nor "
        "tinyxml2 target exists — check the upstream target name for this tag.")
endif()

# Headers are included as "graphic/graphic.h", "latex.h", "render.h" — i.e.
# relative to src/. SYSTEM so upstream headers don't trip Tenjin's warnings.
target_include_directories(microtex SYSTEM PUBLIC
    "${TENJIN_MICROTEX_SOURCE_DIR}/src")

# MicroTeX is C++17 code and does NOT build under C++23: string_utils.h uses the
# std::not1 / std::unary_negate idiom (with argument_type), which was deprecated
# in C++17 and REMOVED from the standard library by C++23. Tenjin builds at
# -std=c++23 globally, and target_compile_features(... cxx_std_17) only sets a
# *minimum* — the target still inherits the parent's higher standard. Pin the
# actual language standard on the target so it compiles as C++17 regardless of
# the global setting. This is safe: MicroTeX is self-contained and exposes its
# API through headers we include as C++23 in our own TUs (the ABI is unaffected
# by the standard used to compile MicroTeX's .cpp files).
set_target_properties(microtex PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
)

# NOTE: do NOT define HAVE_LOG / GRAPHICS_DEBUG here, not even to 0. MicroTeX
# tests them with #ifdef (see common.h), so `HAVE_LOG=0` would still count as
# defined and switch logging ON — plus it would pull in <cxxabi.h>, which isn't
# available on MSVC. Leaving them undefined is what disables them; config.h
# above documents this explicitly.

# MicroTeX is third-party: do not apply Tenjin's -Werror/-Wshadow sweep to it,
# or every upstream warning becomes our build failure. Silence its noise while
# keeping our own targets strict.
if(MSVC)
    target_compile_options(microtex PRIVATE /W0)
else()
    target_compile_options(microtex PRIVATE -w)
endif()

# Position-independent so it can link into the Android shared lib.
set_target_properties(microtex PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    CXX_VISIBILITY_PRESET hidden
)

message(STATUS "Tenjin: MicroTeX vendored as static target "
               "(${TENJIN_MICROTEX_SOURCE_DIR}, tag ${TENJIN_MICROTEX_TAG})")

# ── Runtime resources (fonts + symbol/parser tables, ~2 MB) ──────────────────
#
# MicroTeX loads res/ from a FILESYSTEM path at runtime (LaTeX::init(path), and
# `extern std::string RES_BASE` in common.h). Qt resources aren't real files, so
# FormulaItem extracts :/microtex/res into AppDataLocation on first run and
# hands MicroTeX that path — which is also what makes this work inside the iOS
# sandbox, where nothing next to the executable is writable.
#
# res/ ships with the vendored source rather than being committed separately:
# cmake/Assets.cmake's "committed, not downloaded" rule covers hand-picked UI
# assets (the mono font, flag SVGs), while third-party library payloads follow
# cmake/Vendor.cmake's in-tree-pinned-rev model. Pinning by exact SHA keeps the
# resource bytes reproducible, which is what that rule is protecting.
function(tenjin_microtex_add_resources target)
    if(NOT EXISTS "${TENJIN_MICROTEX_SOURCE_DIR}/res")
        message(FATAL_ERROR
            "MicroTeX: res/ not found at ${TENJIN_MICROTEX_SOURCE_DIR}/res — math "
            "rendering cannot initialise without it.")
    endif()

    file(GLOB_RECURSE _res_files RELATIVE "${TENJIN_MICROTEX_SOURCE_DIR}/res"
         "${TENJIN_MICROTEX_SOURCE_DIR}/res/*")
    # Strip the build files that ship alongside the data; only the fonts/XML are
    # needed at runtime.
    list(FILTER _res_files EXCLUDE REGEX "meson\\.build$")
    list(FILTER _res_files EXCLUDE REGEX "\\.res\\.h$")

    set(_qrc_paths "")
    foreach(_f IN LISTS _res_files)
        list(APPEND _qrc_paths "${TENJIN_MICROTEX_SOURCE_DIR}/res/${_f}")
        set_source_files_properties("${TENJIN_MICROTEX_SOURCE_DIR}/res/${_f}"
            PROPERTIES QT_RESOURCE_ALIAS "${_f}")
    endforeach()

    qt_add_resources(${target} "microtex_res"
        PREFIX "/microtex/res"
        BASE   "${TENJIN_MICROTEX_SOURCE_DIR}/res"
        FILES  ${_qrc_paths}
    )
    list(LENGTH _res_files _n)
    message(STATUS "Tenjin: bundling ${_n} MicroTeX resource files into :/microtex/res")
endfunction()

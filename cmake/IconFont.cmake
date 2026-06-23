# IconFont.cmake — guarantee Material Symbols Outlined is available at build.
#
# Sets:
#   TENJIN_ICON_FONT_DIR   directory containing the font
#   TENJIN_ICON_FONT_FILE  absolute path to MaterialSymbolsOutlined.ttf
#
# Resolution order:
#   1. If View/fonts/MaterialSymbolsOutlined.ttf already exists AND validates as
#      a real TrueType file, use it (vendored / cached).
#   2. Otherwise download from a list of mirrors at configure time, unless
#      TENJIN_NO_FONT_DOWNLOAD is set (offline / hermetic builds).
#
# Policy:
#   The previous behaviour (warn-and-continue when the font is missing) shipped
#   binaries whose icon glyphs silently fell back to system fonts. On Windows
#   that floods the log with DirectWrite CreateFontFaceFromHDC() failures and
#   every icon renders as tofu. We therefore make a missing font a HARD ERROR
#   for release-style builds. Set TENJIN_REQUIRE_ICON_FONT=OFF to opt out
#   (e.g. a Debug build with no network), in which case the app shows a visible
#   "icon font missing" banner at runtime instead of a broken UI.
#
# License: SIL Open Font License 1.1 (OFL-1.1). Redistributable.

set(TENJIN_ICON_FONT_DIR  "${CMAKE_SOURCE_DIR}/View/fonts")
set(TENJIN_ICON_FONT_FILE "${TENJIN_ICON_FONT_DIR}/MaterialSymbolsOutlined.ttf")

# Require the font by default for everything except explicit Debug builds.
if(NOT DEFINED TENJIN_REQUIRE_ICON_FONT)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(TENJIN_REQUIRE_ICON_FONT OFF)
    else()
        set(TENJIN_REQUIRE_ICON_FONT ON)
    endif()
endif()

# Mirrors, tried in order. The first is the canonical Google repo; the second
# is the jsDelivr CDN mirror of the same file (useful where raw.githubusercontent
# is blocked by a corporate proxy or rate-limited in CI).
set(_TENJIN_FONT_URLS
    "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.ttf"
    "https://cdn.jsdelivr.net/gh/google/material-design-icons@master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.ttf"
)

# Optional integrity pin. Leave empty to skip (Google updates the VF in place,
# so a hard pin would break periodically); when set, a mismatch is fatal.
set(TENJIN_ICON_FONT_SHA256 "" CACHE STRING
    "Expected SHA-256 of MaterialSymbolsOutlined.ttf (empty = no check)")

# ── helper: validate a candidate file is a real TTF ──────────────────────────
function(_tenjin_font_is_valid out_var path)
    set(${out_var} FALSE PARENT_SCOPE)
    if(NOT EXISTS "${path}")
        return()
    endif()
    file(SIZE "${path}" _sz)
    if(_sz LESS 1000000)            # a valid VF is several MB; HTML error pages are tiny
        return()
    endif()
    # TrueType magic: 00 01 00 00  (also accept 'true'/'OTTO' just in case).
    file(READ "${path}" _magic LIMIT 4 HEX)
    if(_magic STREQUAL "00010000" OR _magic STREQUAL "74727565" OR _magic STREQUAL "4f54544f")
        if(TENJIN_ICON_FONT_SHA256)
            file(SHA256 "${path}" _got)
            if(NOT _got STREQUAL TENJIN_ICON_FONT_SHA256)
                message(FATAL_ERROR
                    "Icon font SHA-256 mismatch.\n  expected ${TENJIN_ICON_FONT_SHA256}\n  got      ${_got}")
            endif()
        endif()
        set(${out_var} TRUE PARENT_SCOPE)
    endif()
endfunction()

# ── helper: fetch the .codepoints index next to the font (best-effort) ───────
# Tiny (~60 KB); enables tools/scripts/verify_icons.py to validate glyphs
# offline. Never fatal — a missing index only disables that check.
function(_tenjin_fetch_codepoints)
    set(_cp "${TENJIN_ICON_FONT_DIR}/MaterialSymbolsOutlined.codepoints")
    if(EXISTS "${_cp}" OR TENJIN_NO_FONT_DOWNLOAD)
        return()
    endif()
    set(_urls
        "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.codepoints"
        "https://cdn.jsdelivr.net/gh/google/material-design-icons@master/variablefont/MaterialSymbolsOutlined%5BFILL,GRAD,opsz,wght%5D.codepoints"
    )
    foreach(_url IN LISTS _urls)
        file(DOWNLOAD "${_url}" "${_cp}"
            STATUS _st TLS_VERIFY ON INACTIVITY_TIMEOUT 30)
        list(GET _st 0 _code)
        if(_code EQUAL 0)
            file(SIZE "${_cp}" _sz)
            if(_sz GREATER 1000)
                message(STATUS "Tenjin icon codepoints: fetched (${_sz} bytes)")
                return()
            endif()
        endif()
        file(REMOVE "${_cp}")
    endforeach()
endfunction()

# 1. Already present and valid?
_tenjin_font_is_valid(_have "${TENJIN_ICON_FONT_FILE}")
if(_have)
    message(STATUS "Tenjin icon font: using ${TENJIN_ICON_FONT_FILE}")
    _tenjin_fetch_codepoints()
    return()
endif()

# 2. Offline mode: do not download.
if(TENJIN_NO_FONT_DOWNLOAD)
    if(TENJIN_REQUIRE_ICON_FONT)
        message(FATAL_ERROR
            "Icon font missing and TENJIN_NO_FONT_DOWNLOAD is set.\n"
            "  Vendor MaterialSymbolsOutlined.ttf into View/fonts/ before building,\n"
            "  or configure with -DTENJIN_REQUIRE_ICON_FONT=OFF for a degraded build.")
    endif()
    message(WARNING "Icon font missing (offline). Runtime banner will be shown.")
    return()
endif()

# 3. Download, trying each mirror until one validates.
file(MAKE_DIRECTORY "${TENJIN_ICON_FONT_DIR}")
set(_ok FALSE)
foreach(_url IN LISTS _TENJIN_FONT_URLS)
    message(STATUS "Tenjin icon font: downloading from ${_url}")
    file(DOWNLOAD "${_url}" "${TENJIN_ICON_FONT_FILE}"
        STATUS _st TLS_VERIFY ON INACTIVITY_TIMEOUT 30)
    list(GET _st 0 _code)
    if(_code EQUAL 0)
        _tenjin_font_is_valid(_ok "${TENJIN_ICON_FONT_FILE}")
        if(_ok)
            file(SIZE "${TENJIN_ICON_FONT_FILE}" _dlsz)
            message(STATUS "Tenjin icon font: downloaded and validated (${_dlsz} bytes)")
            break()
        endif()
    endif()
    file(REMOVE "${TENJIN_ICON_FONT_FILE}")
endforeach()

if(NOT _ok)
    if(TENJIN_REQUIRE_ICON_FONT)
        message(FATAL_ERROR
            "Icon font could not be obtained from any mirror.\n"
            "  Vendor MaterialSymbolsOutlined.ttf into View/fonts/ manually,\n"
            "  or configure with -DTENJIN_REQUIRE_ICON_FONT=OFF for a degraded build.")
    endif()
    message(WARNING "Icon font download failed; runtime banner will be shown.")
    return()
endif()

_tenjin_fetch_codepoints()

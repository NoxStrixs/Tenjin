# IconFont.cmake — locate the VENDORED Material Symbols Outlined font.
#
# Sets:
#   TENJIN_ICON_FONT_DIR        directory containing the font
#   TENJIN_ICON_FONT_FILE       absolute path to MaterialSymbolsOutlined.ttf
#   TENJIN_ICON_CODEPOINTS_FILE absolute path to the matching .codepoints
#
# POLICY: the icon font and its .codepoints are VENDORED — committed into the
# repository under View/fonts/ — not downloaded at build time. This is the
# professional standard for App Store / Play Store pipelines:
#   * Reproducible: the exact glyph table ships with the source, so codepoints
#     never drift mid-release (Material Symbols reassigns codepoints over time,
#     e.g. `search` moved e8b6 -> ef7a; an unpinned download silently breaks
#     glyphs and fails CI verify-icons).
#   * Offline / hermetic: no configure-time network, no CDN flakiness, no
#     proxy/firewall failures in CI or on developer machines.
#   * Auditable: the binary is reviewed and version-controlled like any asset.
#
# To update the font deliberately (NOT automatically):
#   1. Download the variable TTF + .codepoints from the official source:
#        https://github.com/google/material-design-icons/tree/master/variablefont
#      Files (rename the TTF):
#        MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf
#            -> View/fonts/MaterialSymbolsOutlined.ttf
#        MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].codepoints
#            -> View/fonts/MaterialSymbolsOutlined.codepoints
#   2. Run:  tools/tool verify-icons --fix     (realigns TenjinIcons.qml glyphs)
#   3. Commit both files and the updated TenjinIcons.qml together.
#
# License: SIL Open Font License 1.1 (OFL-1.1). Redistributable; keep the OFL
# license text alongside the font (View/fonts/OFL.txt).

set(TENJIN_ICON_FONT_DIR        "${CMAKE_SOURCE_DIR}/View/fonts")
set(TENJIN_ICON_FONT_FILE       "${TENJIN_ICON_FONT_DIR}/MaterialSymbolsOutlined.ttf")
set(TENJIN_ICON_CODEPOINTS_FILE "${TENJIN_ICON_FONT_DIR}/MaterialSymbolsOutlined.codepoints")

if(NOT EXISTS "${TENJIN_ICON_FONT_FILE}")
    message(FATAL_ERROR
        "Vendored icon font missing:\n"
        "    ${TENJIN_ICON_FONT_FILE}\n"
        "This font is a required, committed asset. See cmake/IconFont.cmake and "
        "View/fonts/README.md for how to obtain and place it. It is intentionally "
        "NOT downloaded at build time.")
endif()

file(SIZE "${TENJIN_ICON_FONT_FILE}" _tenjin_font_size)
if(_tenjin_font_size LESS 1000000)
    message(FATAL_ERROR
        "Vendored icon font is too small (${_tenjin_font_size} bytes) — it is "
        "likely a Git LFS pointer or a truncated/corrupt file rather than the "
        "real TTF (expected > 1 MB). Ensure View/fonts/MaterialSymbolsOutlined.ttf "
        "is the actual font binary.")
endif()

message(STATUS "Tenjin icon font: vendored (${_tenjin_font_size} bytes)")

if(EXISTS "${TENJIN_ICON_CODEPOINTS_FILE}")
    message(STATUS "Tenjin icon codepoints: present (verify-icons enabled)")
else()
    message(WARNING
        "Icon .codepoints not found at ${TENJIN_ICON_CODEPOINTS_FILE}. "
        "verify-icons cannot validate glyph names without it; commit the matching "
        ".codepoints file alongside the font.")
endif()

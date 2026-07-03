# Assets.cmake — validate VENDORED UI assets (mono font, language-flag SVGs).
#
# Consistent with cmake/IconFont.cmake: all bundled binaries are committed into
# the repository, not downloaded at build time. This keeps every target (iOS,
# Android, Arch, Windows, macOS) reproducible and offline-buildable, which is
# required for reliable store-submission pipelines.
#
#   JetBrains Mono   OFL-1.1   View/fonts/JetBrainsMono-{Regular,Bold}.ttf
#   lipis/flag-icons MIT       View/flags/<iso2>.svg  (mapped subset only)
#
# To update: replace the files in-place, keep the flag set in sync with
# tools/scripts/gen_lang_flags.py, and commit. See the per-directory READMEs.

set(TENJIN_FONTS_DIR "${CMAKE_SOURCE_DIR}/View/fonts")
set(TENJIN_FLAGS_DIR "${CMAKE_SOURCE_DIR}/View/flags")

# ── Monospace font (required) ────────────────────────────────────────────────
foreach(_mono JetBrainsMono-Regular.ttf JetBrainsMono-Bold.ttf)
    if(NOT EXISTS "${TENJIN_FONTS_DIR}/${_mono}")
        message(FATAL_ERROR
            "Vendored mono font missing: View/fonts/${_mono}\n"
            "It is a required, committed asset (Platform.fontMono / code & "
            "timestamp text). See View/fonts/README.md.")
    endif()
endforeach()

# ── Language-flag SVGs (required subset) ─────────────────────────────────────
# Must match _TENJIN_FLAG_CODES below and the table in gen_lang_flags.py.
set(TENJIN_FLAG_CODES
    gb us jp es mx fr de it pt br ru kr cn tw sa)

set(_missing_flags "")
foreach(_c IN LISTS TENJIN_FLAG_CODES)
    if(NOT EXISTS "${TENJIN_FLAGS_DIR}/${_c}.svg")
        list(APPEND _missing_flags "${_c}.svg")
    endif()
endforeach()
if(_missing_flags)
    message(FATAL_ERROR
        "Vendored language-flag SVGs missing from View/flags/: ${_missing_flags}\n"
        "These are required, committed assets. See View/flags/README.md.")
endif()

message(STATUS "Tenjin assets: mono font + ${CMAKE_MATCH_COUNT} flags vendored OK")

# Assets.cmake — fetch bundled UI assets at configure time (mono font, flags).
#
# Mirrors cmake/IconFont.cmake: assets land in the source tree (View/fonts,
# View/flags), are git-ignored, and CI caches them. All are FOSS and bundled
# only (no OS libraries), so they satisfy the iOS/Android sandbox constraints.
#
#   JetBrains Mono   OFL-1.1   (timestamps, code, formula source)
#   lipis/flag-icons MIT       (language picker flags, mapped subset only)
#
# Set TENJIN_NO_ASSET_DOWNLOAD for offline/hermetic builds; place the files
# manually per View/fonts/README.md and View/flags/README.md.

set(TENJIN_FONTS_DIR "${CMAKE_SOURCE_DIR}/View/fonts")
set(TENJIN_FLAGS_DIR "${CMAKE_SOURCE_DIR}/View/flags")

# ── helper: download to dest unless present; validate min size ───────────────
function(_tenjin_fetch_asset dest min_bytes)
    # remaining args = mirror URLs, tried in order
    if(EXISTS "${dest}")
        return()
    endif()
    if(TENJIN_NO_ASSET_DOWNLOAD)
        message(WARNING "Asset missing and TENJIN_NO_ASSET_DOWNLOAD set: ${dest}")
        return()
    endif()
    get_filename_component(_dir "${dest}" DIRECTORY)
    file(MAKE_DIRECTORY "${_dir}")
    foreach(_url IN LISTS ARGN)
        file(DOWNLOAD "${_url}" "${dest}"
            STATUS _st TLS_VERIFY ON INACTIVITY_TIMEOUT 30)
        list(GET _st 0 _code)
        if(_code EQUAL 0)
            file(SIZE "${dest}" _sz)
            if(_sz GREATER ${min_bytes})
                return()
            endif()
        endif()
        file(REMOVE "${dest}")
    endforeach()
    message(WARNING "Failed to fetch asset: ${dest}")
endfunction()

# ── JetBrains Mono (Regular + Bold) ──────────────────────────────────────────
# Pinned tag for reproducibility; update deliberately.
set(_TENJIN_JBM_TAG "v2.304")
_tenjin_fetch_asset("${TENJIN_FONTS_DIR}/JetBrainsMono-Regular.ttf" 50000
    "https://github.com/JetBrains/JetBrainsMono/raw/${_TENJIN_JBM_TAG}/fonts/ttf/JetBrainsMono-Regular.ttf"
    "https://cdn.jsdelivr.net/gh/JetBrains/JetBrainsMono@${_TENJIN_JBM_TAG}/fonts/ttf/JetBrainsMono-Regular.ttf")
_tenjin_fetch_asset("${TENJIN_FONTS_DIR}/JetBrainsMono-Bold.ttf" 50000
    "https://github.com/JetBrains/JetBrainsMono/raw/${_TENJIN_JBM_TAG}/fonts/ttf/JetBrainsMono-Bold.ttf"
    "https://cdn.jsdelivr.net/gh/JetBrains/JetBrainsMono@${_TENJIN_JBM_TAG}/fonts/ttf/JetBrainsMono-Bold.ttf")

# ── Flag SVGs (lipis/flag-icons) — mapped subset only ────────────────────────
# Keep this list in sync with tools/scripts/gen_lang_flags.py / the C++ map.
set(_TENJIN_FLAG_CODES
    gb us jp es mx fr de it pt br ru kr cn tw sa)
set(_TENJIN_FI_TAG "7.5.0")
foreach(_c IN LISTS _TENJIN_FLAG_CODES)
    _tenjin_fetch_asset("${TENJIN_FLAGS_DIR}/${_c}.svg" 200
        "https://github.com/lipis/flag-icons/raw/v${_TENJIN_FI_TAG}/flags/4x3/${_c}.svg"
        "https://cdn.jsdelivr.net/gh/lipis/flag-icons@${_TENJIN_FI_TAG}/flags/4x3/${_c}.svg")
endforeach()

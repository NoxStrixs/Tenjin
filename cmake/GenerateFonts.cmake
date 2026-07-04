# Generate subsetted UI fonts from committed Noto masters (single source of
# truth for the shipped glyph set). Produces two families in a fallback cascade:
#
#   NotoSansTenjin      Latin/Cyrillic/Greek + Arabic + Hebrew + Thai
#                       (Noto Sans + Noto Sans Arabic merged, then subset)
#   NotoSansTenjinCJK   CJK (Noto Sans CJK SC subset)
#
# QML uses "NotoSansTenjin, NotoSansTenjinCJK" so glyph matching cascades to CJK
# for han/kana/hangul. Subsetting keeps size shippable on mobile; --layout-
# features='*' preserves Arabic contextual joining (mandatory, else Arabic
# renders disconnected). Requires fonttools (pip install fonttools).
#
# Masters committed to View/fonts/ (see View/fonts/README.md for download):
#   NotoSans-Regular.ttf        NotoSans-Bold.ttf
#   NotoSansArabic-Regular.ttf  NotoSansArabic-Bold.ttf
#   NotoSansCJKsc-Regular.otf   NotoSansCJKsc-Bold.otf
#
# Any missing master or absent fonttools warns and skips (the app falls back to
# system fonts for the affected scripts), matching the icon-font policy.

include_guard(GLOBAL)

# Unicode ranges for the 11 UI locales (en es fr de zh_CN pt ko it ru ar + ja
# kana). Basic Latin + Latin-1 + Latin Ext-A/B, Cyrillic, Greek, Arabic,
# Hebrew, Thai, punctuation, currency. CJK handled by the separate CJK subset.
set(_TENJIN_LATIN_UNICODES
    "U+0000-00FF,U+0100-017F,U+0180-024F,U+0250-02AF,U+0300-036F,U+0370-03FF,U+0400-04FF,U+0590-05FF,U+0600-06FF,U+0E00-0E7F,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2200-22FF")
# CJK: Hiragana, Katakana, Hangul syllables/jamo, CJK Unified (common),
# fullwidth forms.
set(_TENJIN_CJK_UNICODES
    "U+3000-303F,U+3040-309F,U+30A0-30FF,U+3130-318F,U+AC00-D7AF,U+4E00-9FFF,U+FF00-FFEF")

# tenjin_subset_font(<in_ttf> <out_ttf> <unicodes> <out_success>)
function(_tenjin_subset_font IN OUT UNICODES SUCCESS_VAR)
    set(${SUCCESS_VAR} FALSE PARENT_SCOPE)
    if(NOT EXISTS "${IN}")
        message(WARNING "Font master missing: ${IN} — subset skipped (see View/fonts/README.md).")
        return()
    endif()
    if(EXISTS "${OUT}" AND NOT "${IN}" IS_NEWER_THAN "${OUT}")
        set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
        return()
    endif()
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -m fontTools.subset
            "${IN}"
            "--unicodes=${UNICODES}"
            "--layout-features=*"
            "--notdef-outline"
            "--recalc-bounds"
            "--output-file=${OUT}"
        RESULT_VARIABLE _rc
        ERROR_VARIABLE  _err
    )
    if(NOT _rc EQUAL 0)
        message(WARNING "Font subset failed for ${IN}: ${_err}")
        return()
    endif()
    message(STATUS "Subset font: ${OUT}")
    set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
endfunction()

# tenjin_generate_ui_fonts(<fonts_src_dir> <out_dir> <out_list_var>)
# out_list_var receives absolute paths of successfully generated subsets.
function(tenjin_generate_ui_fonts SRC_DIR OUT_DIR OUT_LIST)
    set(_generated "")
    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(NOT Python3_Interpreter_FOUND)
        message(WARNING "Python3 not found — UI font subsetting skipped (system fonts used).")
        set(${OUT_LIST} "" PARENT_SCOPE)
        return()
    endif()

    # Verify fonttools is importable before attempting subsets.
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -c "import fontTools"
        RESULT_VARIABLE _ft_rc ERROR_QUIET)
    if(NOT _ft_rc EQUAL 0)
        message(WARNING "fonttools not installed (pip install fonttools) — UI font subsetting skipped.")
        set(${OUT_LIST} "" PARENT_SCOPE)
        return()
    endif()

    file(MAKE_DIRECTORY "${OUT_DIR}")

    # Latin+Arabic family: subset Noto Sans and Noto Sans Arabic separately, then
    # merge per weight. (Merging two subsets is smaller/faster than merging full
    # masters.) Falls back to Latin-only if Arabic master is absent.
    foreach(_w Regular Bold)
        set(_latin_in  "${SRC_DIR}/NotoSans-${_w}.ttf")
        set(_arabic_in "${SRC_DIR}/NotoSansArabic-${_w}.ttf")
        set(_latin_sub "${OUT_DIR}/_latin-${_w}.ttf")
        set(_arabic_sub "${OUT_DIR}/_arabic-${_w}.ttf")
        set(_merged    "${OUT_DIR}/NotoSansTenjin-${_w}.ttf")

        _tenjin_subset_font("${_latin_in}" "${_latin_sub}" "${_TENJIN_LATIN_UNICODES}" _latin_ok)
        _tenjin_subset_font("${_arabic_in}" "${_arabic_sub}" "U+0600-06FF,U+0750-077F,U+FB50-FDFF,U+FE70-FEFF" _arabic_ok)

        if(_latin_ok AND _arabic_ok)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}" -m fontTools.merge
                    "${_latin_sub}" "${_arabic_sub}" "--output-file=${_merged}"
                RESULT_VARIABLE _mrc ERROR_VARIABLE _merr)
            if(_mrc EQUAL 0)
                list(APPEND _generated "${_merged}")
            else()
                message(WARNING "Font merge failed (${_w}): ${_merr}; using Latin-only.")
                file(RENAME "${_latin_sub}" "${_merged}")
                list(APPEND _generated "${_merged}")
            endif()
        elseif(_latin_ok)
            file(RENAME "${_latin_sub}" "${_merged}")
            list(APPEND _generated "${_merged}")
        endif()
    endforeach()

    # CJK family.
    foreach(_w Regular Bold)
        set(_cjk_in  "${SRC_DIR}/NotoSansCJKsc-${_w}.otf")
        set(_cjk_out "${OUT_DIR}/NotoSansTenjinCJK-${_w}.otf")
        _tenjin_subset_font("${_cjk_in}" "${_cjk_out}" "${_TENJIN_CJK_UNICODES}" _cjk_ok)
        if(_cjk_ok)
            list(APPEND _generated "${_cjk_out}")
        endif()
    endforeach()

    set(${OUT_LIST} "${_generated}" PARENT_SCOPE)
endfunction()

# Generate subsetted UI fonts from committed Noto masters (single source of
# truth for the shipped glyph set). Produces two families in a fallback cascade:
#
#   NotoSansTenjin      Latin/Cyrillic/Greek + Arabic + Hebrew + Thai
#                       (Noto Sans VF + Noto Sans Arabic VF, instanced per
#                        weight, subset, then merged)
#   NotoSansTenjinCJK   CJK (Noto Sans CJK SC subset)
#
# QML uses "NotoSansTenjin, NotoSansTenjinCJK" so glyph matching cascades to CJK
# for han/kana/hangul. Subsetting keeps size shippable on mobile; --layout-
# features='*' preserves Arabic contextual joining (mandatory). Requires
# fonttools (pip install fonttools).
#
# Masters committed to View/fonts/ (see View/fonts/README.md):
#   NotoSans-VF.ttf         (variable: wght 100-900)
#   NotoSansArabic-VF.ttf   (variable: wght 100-900)
#   NotoSansCJKsc-Regular.otf   NotoSansCJKsc-Bold.otf   (static)
#
# The Latin/Arabic masters are VARIABLE fonts: we instance wght=400 (Regular)
# and wght=700 (Bold) with fontTools.varLib.instancer before subsetting. Any
# missing master or absent fonttools warns and skips (system-font fallback).

include_guard(GLOBAL)

# Unicode ranges for the 11 UI locales. Latin+Cyrillic+Greek+Arabic+Hebrew+Thai
# in the primary family; CJK in the separate subset.
set(_TENJIN_LATIN_UNICODES
    "U+0000-00FF,U+0100-017F,U+0180-024F,U+0250-02AF,U+0300-036F,U+0370-03FF,U+0400-04FF,U+0590-05FF,U+0600-06FF,U+0E00-0E7F,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2200-22FF")
set(_TENJIN_ARABIC_UNICODES
    "U+0600-06FF,U+0750-077F,U+08A0-08FF,U+FB50-FDFF,U+FE70-FEFF")
set(_TENJIN_CJK_UNICODES
    "U+3000-303F,U+3040-309F,U+30A0-30FF,U+3130-318F,U+AC00-D7AF,U+4E00-9FFF,U+FF00-FFEF")

# _tenjin_instance_subset(<vf_in> <out> <wght> <unicodes> <success_var>)
# Instances a variable font at the given weight, then subsets it, in one pass.
function(_tenjin_instance_subset IN OUT WGHT UNICODES SUCCESS_VAR)
    set(${SUCCESS_VAR} FALSE PARENT_SCOPE)
    if(NOT EXISTS "${IN}")
        message(WARNING "Font master missing: ${IN} — skipped (see View/fonts/README.md).")
        return()
    endif()
    if(EXISTS "${OUT}" AND NOT "${IN}" IS_NEWER_THAN "${OUT}")
        set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
        return()
    endif()
    set(_tmp "${OUT}.instance.ttf")
    # Instance the weight axis AND drop the width axis to its default so the
    # result is a fully static instance (the Noto masters are [wdth,wght]
    # two-axis VFs; pinning only wght would leave a partial VF with wdth still
    # variable, shipping unnecessary fvar/gvar tables). wdth=100 is the Noto
    # default (normal width).
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -m fontTools.varLib.instancer
            "${IN}" "wght=${WGHT}" "wdth=100" "--output=${_tmp}"
        RESULT_VARIABLE _irc ERROR_VARIABLE _ierr)
    if(NOT _irc EQUAL 0)
        message(WARNING "Font instancing failed for ${IN} @wght=${WGHT}: ${_ierr}")
        return()
    endif()
    # Subset the static instance.
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -m fontTools.subset
            "${_tmp}" "--unicodes=${UNICODES}" "--layout-features=*"
            "--notdef-outline" "--recalc-bounds" "--output-file=${OUT}"
        RESULT_VARIABLE _src ERROR_VARIABLE _serr)
    file(REMOVE "${_tmp}")
    if(NOT _src EQUAL 0)
        message(WARNING "Font subset failed for ${IN}: ${_serr}")
        return()
    endif()
    set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
endfunction()

# _tenjin_subset_static(<in> <out> <unicodes> <success_var>) — for CJK OTF.
function(_tenjin_subset_static IN OUT UNICODES SUCCESS_VAR)
    set(${SUCCESS_VAR} FALSE PARENT_SCOPE)
    if(NOT EXISTS "${IN}")
        message(WARNING "Font master missing: ${IN} — skipped (see View/fonts/README.md).")
        return()
    endif()
    if(EXISTS "${OUT}" AND NOT "${IN}" IS_NEWER_THAN "${OUT}")
        set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
        return()
    endif()
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -m fontTools.subset
            "${IN}" "--unicodes=${UNICODES}" "--layout-features=*"
            "--notdef-outline" "--recalc-bounds" "--output-file=${OUT}"
        RESULT_VARIABLE _rc ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(WARNING "Font subset failed for ${IN}: ${_err}")
        return()
    endif()
    set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
endfunction()

# Rewrite the OpenType `name` table so the internal family is NOT "Noto Sans".
# OFL 1.1's Reserved Font Name clause forbids modified versions from using the
# reserved name ("Noto"); our instanced+subset+merged fonts are modified, so
# they must carry an independent family name. QML resolves the family from the
# loaded font (FontLoader.font.family), so the app picks this up automatically.
#   name IDs rewritten: 1/16 (family), 4 (full), 6 (postscript), 3 (unique).
function(_tenjin_rename_family FONT NEWFAMILY)
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -c "
import sys
from fontTools.ttLib import TTFont
path, fam = sys.argv[1], sys.argv[2]
f = TTFont(path)
name = f['name']
ps = fam.replace(' ', '')
for rec in name.names:
    nid = rec.nameID
    if nid in (1, 16):
        rec.string = fam
    elif nid == 4:
        rec.string = fam
    elif nid == 6:
        rec.string = ps
    elif nid == 3:
        rec.string = ps
f.save(path)
" "${FONT}" "${NEWFAMILY}"
        RESULT_VARIABLE _rc ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
        message(WARNING "Font family rename failed for ${FONT}: ${_err}")
    endif()
endfunction()

function(tenjin_generate_ui_fonts SRC_DIR OUT_DIR OUT_LIST)
    set(_generated "")
    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(NOT Python3_Interpreter_FOUND)
        message(WARNING "Python3 not found — UI font subsetting skipped (system fonts used).")
        set(${OUT_LIST} "" PARENT_SCOPE)
        return()
    endif()
    execute_process(COMMAND "${Python3_EXECUTABLE}" -c "import fontTools"
        RESULT_VARIABLE _ft_rc ERROR_QUIET)
    if(NOT _ft_rc EQUAL 0)
        message(WARNING "fonttools not installed (pip install fonttools) — UI font subsetting skipped.")
        set(${OUT_LIST} "" PARENT_SCOPE)
        return()
    endif()

    file(MAKE_DIRECTORY "${OUT_DIR}")

    set(_latin_vf  "${SRC_DIR}/NotoSans-VF.ttf")
    set(_arabic_vf "${SRC_DIR}/NotoSansArabic-VF.ttf")

    # Regular=400, Bold=700.
    foreach(_pair "Regular:400" "Bold:700")
        string(REPLACE ":" ";" _pp "${_pair}")
        list(GET _pp 0 _w)
        list(GET _pp 1 _wght)

        set(_latin_sub  "${OUT_DIR}/_latin-${_w}.ttf")
        set(_arabic_sub "${OUT_DIR}/_arabic-${_w}.ttf")
        set(_merged     "${OUT_DIR}/NotoSansTenjin-${_w}.ttf")

        _tenjin_instance_subset("${_latin_vf}"  "${_latin_sub}"  "${_wght}" "${_TENJIN_LATIN_UNICODES}"  _latin_ok)
        _tenjin_instance_subset("${_arabic_vf}" "${_arabic_sub}" "${_wght}" "${_TENJIN_ARABIC_UNICODES}" _arabic_ok)

        if(_latin_ok AND _arabic_ok)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}" -m fontTools.merge
                    "${_latin_sub}" "${_arabic_sub}" "--output-file=${_merged}"
                RESULT_VARIABLE _mrc ERROR_VARIABLE _merr)
            if(_mrc EQUAL 0)
                _tenjin_rename_family("${_merged}" "TenjinSans")
                list(APPEND _generated "${_merged}")
            else()
                message(WARNING "Font merge failed (${_w}): ${_merr}; Latin-only.")
                file(RENAME "${_latin_sub}" "${_merged}")
                _tenjin_rename_family("${_merged}" "TenjinSans")
                list(APPEND _generated "${_merged}")
            endif()
        elseif(_latin_ok)
            file(RENAME "${_latin_sub}" "${_merged}")
            _tenjin_rename_family("${_merged}" "TenjinSans")
            list(APPEND _generated "${_merged}")
        endif()
    endforeach()

    # CJK static OTFs.
    foreach(_w Regular Bold)
        set(_cjk_in  "${SRC_DIR}/NotoSansCJKsc-${_w}.otf")
        set(_cjk_out "${OUT_DIR}/NotoSansTenjinCJK-${_w}.otf")
        _tenjin_subset_static("${_cjk_in}" "${_cjk_out}" "${_TENJIN_CJK_UNICODES}" _cjk_ok)
        if(_cjk_ok)
            _tenjin_rename_family("${_cjk_out}" "TenjinSansCJK")
            list(APPEND _generated "${_cjk_out}")
        endif()
    endforeach()

    set(${OUT_LIST} "${_generated}" PARENT_SCOPE)
endfunction()

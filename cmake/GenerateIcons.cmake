# Generate the Windows .ico from the single canonical icon source
# (App/ios/Assets.xcassets/AppIcon.appiconset/icon-1024.png) at configure time,
# so no binary .ico is committed and every platform derives from one master
# (§4: generate over commit; single source of truth).
#
# Uses Pillow (pure-Python, cross-platform, no ImageMagick/system deps). The
# .ico embeds the standard Windows sizes (16/24/32/48/64/128/256). If Pillow or
# Python is unavailable the build warns and skips the exe icon rather than
# failing (matches the existing missing-icon behaviour in App/CMakeLists.txt).

include_guard(GLOBAL)

# tenjin_generate_win_ico(<source_png> <output_ico> <out_var_success>)
function(tenjin_generate_win_ico SRC OUT SUCCESS_VAR)
    set(${SUCCESS_VAR} FALSE PARENT_SCOPE)

    if(NOT EXISTS "${SRC}")
        message(WARNING "Icon source not found: ${SRC} — Windows exe icon skipped.")
        return()
    endif()

    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(NOT Python3_Interpreter_FOUND)
        message(WARNING "Python3 not found — Windows exe icon skipped.")
        return()
    endif()

    # Only regenerate when the source is newer than the output.
    if(EXISTS "${OUT}" AND NOT "${SRC}" IS_NEWER_THAN "${OUT}")
        set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
        return()
    endif()

    get_filename_component(_out_dir "${OUT}" DIRECTORY)
    file(MAKE_DIRECTORY "${_out_dir}")

    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -c
"import sys\ntry:\n from PIL import Image\nexcept ImportError:\n sys.exit(42)\nimg = Image.open(sys.argv[1]).convert('RGBA')\nsizes = [(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]\nimg.save(sys.argv[2], format='ICO', sizes=sizes)\n"
            "${SRC}" "${OUT}"
        RESULT_VARIABLE _rc
        ERROR_VARIABLE  _err
    )

    if(_rc EQUAL 42)
        message(WARNING
            "Pillow (PIL) not installed — Windows exe icon skipped. "
            "Install with: pip install pillow")
        return()
    elseif(NOT _rc EQUAL 0)
        message(WARNING "Icon generation failed (${_rc}): ${_err}")
        return()
    endif()

    message(STATUS "Generated Windows icon: ${OUT}")
    set(${SUCCESS_VAR} TRUE PARENT_SCOPE)
endfunction()

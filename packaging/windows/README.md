# Windows packaging assets

The Windows installer is driven entirely by `cmake/Packaging.cmake` via CPack's
NSIS generator. There are no template files here today.

If we ever need a custom NSIS script (for example to embed a license page or
custom shortcuts beyond `CPACK_NSIS_CREATE_ICONS_EXTRA`), drop the template
here and reference it from `Packaging.cmake` with `CPACK_NSIS_TEMPLATE`.

Icons: when we have a real `tenjin.ico`, set `CPACK_NSIS_MUI_ICON` and
`CPACK_NSIS_MUI_UNIICON` in `Packaging.cmake`.

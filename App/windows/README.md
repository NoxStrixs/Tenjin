# Windows executable icon (vendored binary)

Commit `tenjin.ico` in this directory. It is compiled into the executable via
`tenjin.rc` so the binary shows the app logo in Explorer, the taskbar, and the
title bar. If the file is missing the build emits a WARNING and produces an
icon-less executable (it does not fail — the icon is cosmetic, unlike the
hard-required font assets).

Generating from the existing artwork (ImageMagick):

    magick packaging/linux/tenjin.jpg -define icon:auto-resize=256,128,64,48,32,16 App/windows/tenjin.ico

Multi-size is required: Explorer picks 16/32 px, the taskbar 48+, high-DPI 256.

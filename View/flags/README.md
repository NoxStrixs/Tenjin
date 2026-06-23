# Language Flags

SVG flags for the interface-language picker, from **lipis/flag-icons** (MIT).

Fetched automatically at configure time by `cmake/Assets.cmake` (4x3 ratio).
Git-ignored; CI caches them. For offline builds, place the mapped `<iso2>.svg`
files here manually (see `_TENJIN_FLAG_CODES` in `cmake/Assets.cmake`) or
configure with `-DTENJIN_NO_ASSET_DOWNLOAD=ON`.

The language→flag map lives in `tools/scripts/gen_lang_flags.py` (single source
of truth) and is emitted to `View/LanguageFlags.qml`. Keep the flag codes there
in sync with `_TENJIN_FLAG_CODES`.

Bundled via the `TenjinView` QML module → `qrc:/qt/qml/TenjinView/flags/<iso2>.svg`.

License: MIT (lipis/flag-icons).

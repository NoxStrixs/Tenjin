# Language Flags (vendored)

SVG flags for the interface-language picker, from **lipis/flag-icons** (MIT).
**Committed assets** — not downloaded — for reproducible, offline builds.

## Required files (4x3 ratio)

`gb us jp es mx fr de it pt br ru kr cn tw sa` → `View/flags/<code>.svg`

Download from
[lipis/flag-icons `flags/4x3/`](https://github.com/lipis/flag-icons/tree/main/flags/4x3).
`cmake/Assets.cmake` **fails configuration** if any mapped flag is missing.

The set is the single source of truth in three places that must stay in sync:
`TENJIN_FLAG_CODES` (cmake/Assets.cmake), the `TABLE` in
`tools/scripts/gen_lang_flags.py`, and the generated `View/LanguageFlags.qml`.

## Bundling & runtime

Embedded through the `TenjinView` QML module → `qrc:/qt/qml/TenjinView/flags/<code>.svg`,
rendered by `Qt6::Svg` in `View/components/LanguageFlagRow.qml`.

## Updating the language→flag map

Edit the `TABLE` in `tools/scripts/gen_lang_flags.py`, add the new flag SVG(s)
here, add the code(s) to `TENJIN_FLAG_CODES`, re-run the script, and commit.

License: MIT (lipis/flag-icons).

# Fonts (vendored)

These fonts are **committed assets** — not downloaded at build time — for
reproducible, offline, store-pipeline-safe builds across all targets.

## Required files

| File | Source | License |
|------|--------|---------|
| `MaterialSymbolsOutlined.ttf` | [google/material-design-icons `variablefont/`](https://github.com/google/material-design-icons/tree/master/variablefont) | OFL-1.1 |
| `MaterialSymbolsOutlined.codepoints` | same folder (glyph-name → codepoint) | OFL-1.1 |
| `JetBrainsMono-Regular.ttf` | [JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono) `fonts/ttf/` | OFL-1.1 |
| `JetBrainsMono-Bold.ttf` | same | OFL-1.1 |
| `OFL.txt` | the SIL Open Font License text | — |

Rename the Material Symbols variable font from
`MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf` to
`MaterialSymbolsOutlined.ttf` (and the same for `.codepoints`).

The build (`cmake/IconFont.cmake`, `cmake/Assets.cmake`) **fails configuration**
if any of these is missing or looks truncated (< 1 MB) — by design.

## Bundling & runtime

All four are embedded through the `TenjinView` QML module (`RESOURCES` in
`View/CMakeLists.txt`):

```
qrc:/qt/qml/TenjinView/fonts/MaterialSymbolsOutlined.ttf   (icons)
qrc:/qt/qml/TenjinView/fonts/JetBrainsMono-Regular.ttf     (Platform.fontMono)
qrc:/qt/qml/TenjinView/fonts/JetBrainsMono-Bold.ttf
```

The mono fonts are registered in `App/src/main.cpp` via
`QFontDatabase::addApplicationFont` (`:` resource path).

## Updating the icon font (deliberate)

Material Symbols reassigns codepoints over time, so updating requires realigning
the glyph table:

1. Replace `MaterialSymbolsOutlined.ttf` **and** `.codepoints` together.
2. `tools/tool verify-icons --fix`  (rewrites `View/TenjinIcons.qml`)
3. Commit all three.

CI (`verify-icons`) fails the build if `TenjinIcons.qml` and the committed
`.codepoints` disagree, so glyphs can never silently drift.

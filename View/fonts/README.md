# Icon Font

Place `MaterialSymbolsOutlined.ttf` here before building.

Download from the official release:
  https://github.com/google/material-symbols/raw/main/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf

Rename the file to: MaterialSymbolsOutlined.ttf

License: SIL Open Font License 1.1 (OFL-1.1)
The font file must NOT be committed to a public repository if it exceeds
GitHub's 100 MB LFS threshold. Current size is ~3.5 MB — safe to commit directly.

The font is referenced in View/TenjinIcons.qml as a singleton and loaded
once at startup via FontLoader. All icon glyphs are in the Unicode Private
Use Area (U+E000–U+F8FF) so they render identically on every platform.

---

## Monospace UI font (JetBrains Mono)

`JetBrainsMono-Regular.ttf` and `JetBrainsMono-Bold.ttf` are fetched here at
configure time by `cmake/Assets.cmake` (OFL-1.1) and bundled through the
`TenjinView` QML module. Loaded in `App/src/main.cpp` via
`QFontDatabase::addApplicationFont`, exposed to QML as `Platform.fontMono`.
Git-ignored; CI caches them. Offline: place manually or set
`-DTENJIN_NO_ASSET_DOWNLOAD=ON`.

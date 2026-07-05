import QtQuick
import TenjinView

// Baseline text element. Elides by default so any label overflow (mobile, long
// locales) is truncated with an ellipsis rather than spilling outside its
// bounds. Single line by default; set `maxLines > 1` for wrapped body text
// (wraps to N lines, then elides). Inherits the app UI font family. Use this
// instead of raw Text for all user-facing labels; use raw Text only for icon
// glyphs (which set font.family: TenjinIcons.family and must not elide).
Text {
    // >1 enables multi-line wrapping capped at this many lines.
    property int maxLines: 1

    color: Platform.textPrimary
    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
    font.pixelSize: Platform.fontBase

    elide: Text.ElideRight
    wrapMode: maxLines > 1 ? Text.Wrap : Text.NoWrap
    maximumLineCount: maxLines
}

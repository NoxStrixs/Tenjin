pragma Singleton
import QtQuick

// TenjinIcons — single source of truth for every icon glyph in the app.
//
// Font: Material Symbols Outlined (variable font, OFL-1.1)
// Place MaterialSymbolsOutlined.ttf in View/fonts/ before building.
// Download: https://github.com/google/material-symbols
//
// Usage in QML:
//   Text {
//       text:        TenjinIcons.search
//       font.family: TenjinIcons.family
//       color:       Platform.textMuted   // ← caller controls theme color
//   }
//
//   IconBtn { glyph: TenjinIcons.settings }  // IconBtn handles family + color
//
// All codepoints are in the Unicode Private Use Area (U+E000–U+F8FF).
// They render identically on every platform regardless of system fonts.
// Never set font.bold on a Text item that uses TenjinIcons.family — the
// variable font has no Bold axis, which causes DirectWrite to spam warnings.
// Use font.weight: Font.Normal (or omit weight entirely; the default is 400).
QtObject {
    id: root

    // Absolute qrc:/ path under the non-reserved /tenjin prefix.
    // The font is bundled THROUGH the QML module (RESOURCES in
    // View/CMakeLists.txt), so it lives under the module's resource prefix
    // qrc:/qt/qml/TenjinView/. Bundling via the module ties the resource
    // initializer to the module's own, so it survives static linking — unlike
    // a detached qt_add_resources(), whose initializer is stripped.
    readonly property FontLoader _loader: FontLoader {
        source: "qrc:/qt/qml/TenjinView/fonts/MaterialSymbolsOutlined.ttf"
        onStatusChanged: {
            if (status === FontLoader.Error)
                console.error(
                    "TenjinIcons: failed to load MaterialSymbolsOutlined.ttf\n" +
                    "  Place the font in View/fonts/ and rebuild.\n" +
                    "  Download: https://github.com/google/material-symbols")
        }
    }

    // Expose the loaded family name. Use this on every Text item that
    // renders an icon glyph.
    readonly property string family: _loader.font.family

    // ── Navigation ────────────────────────────────────────────────────────────
    readonly property string chevronLeft:  "\ue5cb"   // chevron_left
    readonly property string chevronRight: "\ue5cc"   // chevron_right
    readonly property string menu:         "\ue5d2"   // menu
    readonly property string close:        "\ue5cd"   // close
    readonly property string expandMore:   "\ue5cf"   // expand_more
    readonly property string expandLess:   "\ue5ce"   // expand_less
    readonly property string moreVert:     "\ue5d4"   // more_vert

    // ── App sections ──────────────────────────────────────────────────────────
    readonly property string words:    "\uf53e"        // book_2
    readonly property string decks:    "\uea19"        // menu_book
    readonly property string tags:     "\ue893"        // label
    readonly property string news:     "\ueb81"        // newspaper
    readonly property string stats:    "\uf092"        // insights
    readonly property string settings: "\ue8b8"        // settings
    readonly property string help:     "\ue8fd"        // help
    readonly property string info:     "\ue88e"        // info

    // ── Theme ─────────────────────────────────────────────────────────────────
    readonly property string lightMode: "\ue518"       // light_mode
    readonly property string darkMode:  "\ue51c"       // dark_mode

    // ── Actions ───────────────────────────────────────────────────────────────
    readonly property string add:      "\ue145"        // add
    readonly property string remove:   "\ue15b"        // remove
    readonly property string edit:     "\uf097"        // edit
    readonly property string del:      "\ue92e"        // delete
    readonly property string search:   "\uef7a"        // search
    readonly property string refresh:  "\ue5d5"        // refresh
    readonly property string copy:     "\ue14d"        // content_copy
    readonly property string keyboard: "\ue312"        // keyboard
    readonly property string check:    "\ue668"        // check
    readonly property string drag:     "\ue945"        // drag_indicator
    readonly property string pin:      "\uf045"        // pin
    readonly property string link:     "\ue250"        // link

    // ── Import / Export / Sync ────────────────────────────────────────────────
    readonly property string upload:   "\uf09b"        // upload
    readonly property string download: "\uf090"        // download
    readonly property string sync:     "\ue627"        // sync
    readonly property string mail:     "\ue159"        // mail

    // ── Media ─────────────────────────────────────────────────────────────────
    readonly property string play:       "\ue037"      // play_arrow
    readonly property string pause:      "\ue034"      // pause
    readonly property string volumeUp:   "\ue050"      // volume_up
    readonly property string volumeOff:  "\ue04f"      // volume_off
    readonly property string fullscreen: "\ue5d0"      // fullscreen
    readonly property string globe:      "\ue80b"      // public
    readonly property string audioFile:  "\ueb82"      // audio_file
    readonly property string videoFile:  "\ueb87"      // video_file
    readonly property string image:      "\ue3f4"      // image
    readonly property string attach:     "\ue226"      // attach_file
    readonly property string document:   "\ue873"      // description
    readonly property string folder:     "\ue2c7"      // folder

    // ── Text formatting ───────────────────────────────────────────────────────
    readonly property string bold:      "\ue238"       // format_bold
    readonly property string italic:    "\ue23f"       // format_italic
    readonly property string underline: "\ue249"       // format_underlined
    readonly property string strike:    "\ue257"       // strikethrough_s
    readonly property string bullet:    "\ue241"       // format_list_bulleted
    readonly property string formula:   "\ue661"       // functions

    // ── Status ────────────────────────────────────────────────────────────────
    readonly property string warning:     "\uf083"     // warning
    readonly property string bugReport:   "\ue868"     // bug_report
    readonly property string autoAwesome: "\ue65f"     // auto_awesome
    readonly property string tag:         "\ue9ef"     // tag
}

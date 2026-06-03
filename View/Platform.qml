pragma Singleton
import QtQuick

QtObject {
    id: platform
    readonly property bool isMobile: Qt.platform.os === "ios" || Qt.platform.os === "android"

    // 0 = light (default cream)
    // 1 = dark.
    // Persistence is handled by AppViewModel via QSettings
    property int theme: 0
    readonly property bool isDark: theme === 1
    function toggleTheme() { theme = isDark ? 0 : 1 }

    // ── Color tokens ──────────────────────────────────────────────────────────
    // Each token resolves to the light or dark value based on `theme`.
    readonly property color bg:          isDark ? "#1e1b16" : "#fefae0"
    readonly property color surface:     isDark ? "#2a251d" : "#faedcd"
    readonly property color surfaceAlt:  isDark ? "#332d23" : "#e9edc9"
    readonly property color border:      isDark ? "#4a4234" : "#ccd5ae"
    readonly property color accent:      isDark ? "#d4a373" : "#d4a373"
    readonly property color accentDark:  isDark ? "#e0b487" : "#b5835a"
    readonly property color textPrimary: isDark ? "#ede4d3" : "#3d2c1e"
    readonly property color textMuted:   isDark ? "#a89a85" : "#8a7560"
    readonly property color danger:      isDark ? "#e05a4c" : "#c0392b"
    readonly property color success:     isDark ? "#8fbf7a" : "#6a8f5a"

    // Additional Semantic Tokens for Review Modes & Chips
    readonly property color reviewBg:    isDark ? "#252017" : "#f4f1de"
    readonly property color textOnDark:  "#ffffff"
    // Translucent black for popup overlays. Same in both themes — the overlay
    // exists to dim whatever's behind it, not to communicate palette.
    readonly property color overlayDim:  "#80000000"

    // ── Sizing ────────────────────────────────────────────────────────────────
    readonly property int touchTarget:  isMobile ? 48 : 36
    readonly property int iconSize:     isMobile ? 24 : 16
    readonly property int headerHeight: isMobile ? 56 : 48
    readonly property int sidebarWidth: 220

    // Typography scale. Each step ≈ 2-3px, chosen so chip / pill text reads as
    // secondary at fontSmall and metadata at fontTiny without being illegible
    // on mobile. fontBase is what general body text uses.
    readonly property int fontTiny:   isMobile ? 12 : 10
    readonly property int fontSmall:  isMobile ? 14 : 11
    readonly property int fontBase:   isMobile ? 16 : 13
    readonly property int fontLarge:  isMobile ? 20 : 15
    readonly property int fontTitle:  isMobile ? 26 : 20

    // Spacing scale. Use these for margins, paddings, and gaps between
    // sibling components. pagePadding remains the outermost gutter for
    // pages and panels (kept separate so it can be retuned independently).
    readonly property int spacingXs:   isMobile ?  3 :  2
    readonly property int spacingSm:   isMobile ?  6 :  4
    readonly property int spacingMd:   isMobile ? 10 :  8
    readonly property int spacingLg:   isMobile ? 16 : 12
    readonly property int spacingXl:   isMobile ? 24 : 18
    readonly property int pagePadding: isMobile ? 16 : 24

    // Corner radii. radius is the default for buttons/inputs; radiusLarge is
    // for cards and dialogs; pill chips use chipRadius which is height-based.
    readonly property int radius:       6
    readonly property int radiusLarge:  10

    // Chip / pill primitives. Used by TagChip.qml, the tag-filter popup,
    // the deck-detail chip row, and any future pill-shaped control. Two
    // sizes — default (chipHeight) and compact (chipHeightSm) — both
    // height-derived radius so the pill shape is automatic.
    readonly property int chipHeight:    isMobile ? 32 : 26
    readonly property int chipHeightSm:  isMobile ? 26 : 22
    readonly property int chipPaddingH:  isMobile ? 12 : 10
    readonly property int chipRadius:    chipHeight / 2

    // Borders.
    readonly property int borderWidth:      1
    readonly property int borderWidthThick: 2

    // Popups. popupWidthSm fits a search field + ~6 visible list rows;
    // popupWidthMd is the default for the tag-filter popup and similar.
    // On mobile we clamp to viewport-derived sizes in the popup itself.
    readonly property int popupWidthSm: 240
    readonly property int popupWidthMd: 320
    readonly property int popupMaxRows: 10

    // Animation durations (ms). Keep these terse — UI should feel snappy.
    readonly property int durationFast: 120
    readonly property int durationMed:  200

    // ── Window ────────────────────────────────────────────────────────────────
    // Minimum desktop window size so layouts never collapse below usability.
    readonly property int minWindowWidth:  720
    readonly property int minWindowHeight: 480
}

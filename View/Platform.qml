pragma Singleton
import QtQuick

QtObject {
    id: platform
    readonly property bool isMobile: Qt.platform.os === "ios" || Qt.platform.os === "android"

    // ── Theme ─────────────────────────────────────────────────
    // 0 = light (default cream), 1 = dark. Persistence is handled by
    // AppViewModel via QSettings (see Main.qml), so no extra QML module is
    // required — this stays a plain property the rest of the UI binds to.
    property int theme: 0
    readonly property bool isDark: theme === 1
    function toggleTheme() { theme = isDark ? 0 : 1 }

    // ── Palette ───────────────────────────────────────────────
    // Each token resolves to the light or dark value based on `theme`.
    // Light is the original cream scheme; dark is a warm, low-glare palette
    // that keeps the same accent so the brand identity stays consistent.
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

    // ── Sizing ────────────────────────────────────────────────
    readonly property int touchTarget:  isMobile ? 48 : 36
    readonly property int iconSize:     isMobile ? 24 : 16
    readonly property int fontBase:     isMobile ? 16 : 13
    readonly property int fontLarge:    isMobile ? 20 : 15
    readonly property int fontTitle:    isMobile ? 26 : 20
    readonly property int headerHeight: isMobile ? 56 : 48
    readonly property int sidebarWidth: 220
    readonly property int pagePadding:  isMobile ? 16 : 24
    readonly property int radius:       6
    readonly property int radiusLarge:  10

    // Minimum desktop window size so layouts never collapse below usability.
    readonly property int minWindowWidth:  720
    readonly property int minWindowHeight: 480
}

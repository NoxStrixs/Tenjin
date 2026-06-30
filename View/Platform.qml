pragma Singleton
import QtQuick

QtObject {
    id: platform

    readonly property bool isMobile: Qt.platform.os === "ios" || Qt.platform.os === "android"

    // Width-aware layout switch. The OS check (isMobile) decides input model
    // (touch vs pointer), but layout should also adapt to available width so
    // an iPad in full screen or wide split-view gets the two-pane experience
    // while the same iPad in narrow split-view falls back to single-column.
    // `currentWidth` is updated by Main.qml from the window width.
    property int currentWidth: 0
    readonly property int wideLayoutThreshold: 760
    readonly property bool useWideLayout: currentWidth >= wideLayoutThreshold

    property int theme: 0
    readonly property bool isDark: theme === 1
    function toggleTheme() { theme = isDark ? 0 : 1 }

    // ── Color tokens ──────────────────────────────────────────────────────────
    readonly property color bg:          isDark ? "#1e1b16" : "#fefae0"
    readonly property color surface:     isDark ? "#2a251d" : "#faedcd"
    readonly property color surfaceAlt:  isDark ? "#332d23" : "#e9edc9"
    readonly property color border:      isDark ? "#4a4234" : "#ccd5ae"
    readonly property color accent:      "#d4a373"
    readonly property color accentDark:  isDark ? "#e0b487" : "#b5835a"
    readonly property color textPrimary: isDark ? "#ede4d3" : "#3d2c1e"
    readonly property color textMuted:   isDark ? "#a89a85" : "#8a7560"
    readonly property color danger:      isDark ? "#e05a4c" : "#c0392b"
    readonly property color success:     isDark ? "#8fbf7a" : "#6a8f5a"
    readonly property color reviewBg:    isDark ? "#252017" : "#f4f1de"
    readonly property color textOnDark:  "#ffffff"
    readonly property color overlayDim:  "#80000000"

    // ── Sizing ────────────────────────────────────────────────────────────────
    readonly property int touchTarget:  isMobile ? 48 : 36
    readonly property int iconSize:     isMobile ? 24 : 16
    readonly property int iconSizeLg:    isMobile ? 32 : 24
    readonly property int iconSizeXl:    isMobile ? 44 : 36
    readonly property int iconSizeHero:  isMobile ? 64 : 56
    readonly property int headerHeight: isMobile ? 56 : 48
    readonly property int sidebarWidth: 220

    // Bundled monospace family (JetBrainsMono, loaded in main.cpp via
    // QFontDatabase). Used for timestamps, code, and formula source.
    readonly property string fontMono: "JetBrains Mono"

    readonly property int fontTiny:   isMobile ? 12 : 10
    readonly property int fontSmall:  isMobile ? 14 : 11
    readonly property int fontBase:   isMobile ? 16 : 13
    readonly property int fontLarge:  isMobile ? 20 : 15
    readonly property int fontTitle:  isMobile ? 26 : 20

    readonly property int spacingXs:   isMobile ?  3 :  2
    readonly property int spacingSm:   isMobile ?  6 :  4
    readonly property int spacingMd:   isMobile ? 10 :  8
    readonly property int spacingLg:   isMobile ? 16 : 12
    readonly property int spacingXl:   isMobile ? 24 : 18
    readonly property int pagePadding: isMobile ? 16 : 24

    readonly property int radius:      6
    readonly property int radiusLarge: 10

    readonly property int chipHeight:   isMobile ? 32 : 26
    readonly property int chipHeightSm: isMobile ? 26 : 22
    readonly property int chipPaddingH: isMobile ? 12 : 10
    readonly property int chipRadius:   chipHeight / 2

    readonly property int borderWidth:      1
    readonly property int borderWidthThick: 2

    readonly property int popupWidthSm: 240
    readonly property int popupWidthMd: 320
    readonly property int popupMaxRows: 10

    readonly property int durationFast: 120
    readonly property int durationMed:  200

    // ── Motion / accessibility ─────────────────────────────────────────────
    // When true, UI animations collapse to near-instant. Bound to an in-app
    // Settings toggle (persisted) and, where available, an OS "reduce motion"
    // probe (see MotionService). UI binds to the effective* helpers below so a
    // single switch disables every transition without per-call conditionals.
    property bool reducedMotionUser:   false   // in-app toggle
    property bool reducedMotionSystem: false   // OS accessibility probe
    readonly property bool reducedMotion: reducedMotionUser || reducedMotionSystem

    // Effective durations: 0 when reduced motion is on, otherwise the base.
    readonly property int effDurationFast: reducedMotion ? 0 : durationFast
    readonly property int effDurationMed:  reducedMotion ? 0 : durationMed
    // Page-transition slide distance (px); collapses to 0 under reduced motion.
    readonly property int pageSlideDistance: reducedMotion ? 0 : 24

    readonly property int minWindowWidth:  720
    readonly property int minWindowHeight: 480

    // ── Display info ──────────────────────────────────────────────────────────
    readonly property real devicePixelRatio:
        Qt.application.screens.length > 0 ? Qt.application.screens[0].devicePixelRatio : 1.0
    readonly property int screenWidth:
        Qt.application.screens.length > 0 ? Qt.application.screens[0].desktopAvailableWidth  : 1280
    readonly property int screenHeight:
        Qt.application.screens.length > 0 ? Qt.application.screens[0].desktopAvailableHeight : 1920

    // ── Safe area ─────────────────────────────────────────────────────────────
    // Written once by Main.qml's Component.onCompleted from the window's
    // SafeArea.margins attached property (Qt 6.6+). Falls back to 0 on
    // platforms or builds where safe-area info is unavailable.
    property int safeAreaTop:    0
    property int safeAreaBottom: 0
    property int safeAreaLeft:   0
    property int safeAreaRight:  0
}

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

    // Screen physical density (device-independent pixels). Populated from
    // Main.qml (Screen.pixelDensity, dots/mm). Falls back to ~96dpi.
    property real screenPixelDensity: 3.78

    // Responsive UI scale — Material-3-style window size classes computed from
    // density-independent width. widthDp = px / (pixelDensity / 3.78), where
    // 3.78 dots/mm ≈ 96dpi (1dp = 1px baseline). Tiers (discrete, so this is a
    // stepped value, not a continuous reactive loop): Compact < 600dp phones,
    // Medium 600–840 small tablets, Expanded ≥ 840 large tablets/desktop.
    readonly property real _widthDp:
        currentWidth / Math.max(0.1, screenPixelDensity / 3.78)
    readonly property int sizeClassCompact:  0
    readonly property int sizeClassMedium:   1
    readonly property int sizeClassExpanded: 2
    readonly property int sizeClass:
        _widthDp < 600 ? sizeClassCompact
                       : (_widthDp < 840 ? sizeClassMedium : sizeClassExpanded)
    // Per-tier UI multiplier applied to size tokens below. Compact (phones) is
    // the 1.0 baseline; larger classes scale up modestly for readability at
    // greater viewing distance.
    readonly property real uiScale:
        sizeClass === sizeClassCompact ? 1.0
                                       : (sizeClass === sizeClassMedium ? 1.08 : 1.15)
    readonly property int wideLayoutThreshold: 760
    readonly property bool useWideLayout: currentWidth >= wideLayoutThreshold

    // Theme: 0 = light, 1 = dark, 2 = custom.
    property int theme: 0
    readonly property bool isDark: theme === 1 || (theme === 2 && customIsDark)
    readonly property bool isCustom: theme === 2
    function toggleTheme() { theme = isDark ? 0 : 1 }

    // ── Custom-theme overrides ────────────────────────────────────────────────
    // Four user-chosen anchor colors; the rest derive from them so the picker
    // stays simple. customIsDark tells derived tints which way to go. Written by
    // AppViewModel from persisted settings; ignored unless theme === 2.
    property color customAccent:  "#d4a373"
    property color customBg:      "#fefae0"
    property color customSurface: "#faedcd"
    property color customText:    "#3d2c1e"
    property color customDanger:  "#c0392b"
    property color customSuccess: "#6a8f5a"
    property color customBorder:  "#e0d4b8"
    property bool  customIsDark:  false

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    // ── Color tokens ──────────────────────────────────────────────────────────
    readonly property color bg:          isCustom ? customBg
                                                  : (isDark ? "#1e1b16" : "#fefae0")
    readonly property color surface:     isCustom ? customSurface
                                                  : (isDark ? "#2a251d" : "#faedcd")
    readonly property color surfaceAlt:  isCustom ? _mix(customSurface, customText, 0.08)
                                                  : (isDark ? "#332d23" : "#e9edc9")
    readonly property color border:      isCustom ? customBorder
                                                  : (isDark ? "#4a4234" : "#ccd5ae")
    readonly property color accent:      isCustom ? customAccent : "#d4a373"
    readonly property color accentDark:  isCustom ? _mix(customAccent, customText, 0.25)
                                                  : (isDark ? "#e0b487" : "#b5835a")
    readonly property color textPrimary: isCustom ? customText
                                                  : (isDark ? "#ede4d3" : "#3d2c1e")
    readonly property color textMuted:   isCustom ? _mix(customText, customBg, 0.4)
                                                  : (isDark ? "#a89a85" : "#8a7560")
    readonly property color danger:      isCustom ? customDanger : (isDark ? "#e05a4c" : "#c0392b")
    readonly property color success:     isCustom ? customSuccess : (isDark ? "#8fbf7a" : "#6a8f5a")
    readonly property color reviewBg:    isCustom ? _mix(customBg, customSurface, 0.5)
                                                  : (isDark ? "#252017" : "#f4f1de")
    readonly property color textOnDark:  "#ffffff"
    readonly property color overlayDim:  "#80000000"

    // ── Review grade scale ────────────────────────────────────────────────────
    // The four answer grades (Forgot/Hard/Good/Easy) need to stay visually
    // distinct — users learn them as a scale — so they get their own tokens
    // rather than being folded into danger/success. Dark variants are lightened
    // so they stay legible on the dark review background.
    readonly property color gradeForgot: isDark ? "#e05a4c" : "#e74c3c"
    readonly property color gradeHard:   isDark ? "#e8944a" : "#e67e22"
    readonly property color gradeGood:   isDark ? "#8fbf7a" : "#2ecc71"
    readonly property color gradeEasy:   isDark ? "#5aa9e0" : "#3498db"

    // ── Sizing ────────────────────────────────────────────────────────────────
    readonly property int touchTarget:  Math.round((isMobile ? 44 : 36) * uiScale)
    readonly property int iconSize:     Math.round((isMobile ? 18 : 16) * uiScale)
    readonly property int iconSizeLg:    isMobile ? 26 : 24
    readonly property int iconSizeXl:    isMobile ? 44 : 36
    readonly property int iconSizeHero:  isMobile ? 64 : 56
    readonly property int headerHeight: isMobile ? 48 : 48
    readonly property int sidebarWidth: 220

    // Bundled monospace family (JetBrainsMono, loaded in main.cpp via
    // QFontDatabase). Used for timestamps, code, and formula source.
    readonly property string fontMono: _monoName !== "" ? _monoName : "monospace"

    readonly property int fontTiny:   Math.round((isMobile ? 11 : 10) * uiScale)
    readonly property int fontSmall:  Math.round((isMobile ? 12 : 11) * uiScale)
    readonly property int fontBase:   Math.round((isMobile ? 14 : 13) * uiScale)

    // ── Font families ─────────────────────────────────────────────────────────
    // Subsetted Noto Sans (Latin/Cyrillic/Greek/Arabic/…) with a CJK fallback,
    // both generated from committed masters and bundled by the QML module.
    // FontLoaders are non-visual, so they live in this singleton. `fontFamily`
    // is the cascade string applied at the root ApplicationWindow.font so every
    // Text inherits it — one binding, consistent glyphs on all platforms. Until
    // the loaders are Ready the family falls back to the system font (avoids a
    // first-paint race). Mono (JetBrainsMono) is used for code/formula contexts.
    readonly property FontLoader _uiRegular: FontLoader {
        source: "qrc:/qt/qml/TenjinView/fonts/NotoSansTenjin-Regular.ttf"
    }
    readonly property FontLoader _uiCjk: FontLoader {
        source: "qrc:/qt/qml/TenjinView/fonts/NotoSansTenjinCJK-Regular.otf"
    }
    readonly property FontLoader _monoRegular: FontLoader {
        source: "qrc:/qt/qml/TenjinView/fonts/JetBrainsMono-Regular.ttf"
    }

    readonly property string _uiName:   _uiRegular.status === FontLoader.Ready ? _uiRegular.font.family : ""
    readonly property string _cjkName:  _uiCjk.status === FontLoader.Ready ? _uiCjk.font.family : ""
    readonly property string _monoName: _monoRegular.status === FontLoader.Ready ? _monoRegular.font.family : ""

    // Cascade: primary UI family, then CJK for han/kana/hangul glyph matching.
    readonly property string fontFamily:
        _uiName === "" ? ""
        : (_cjkName === "" ? _uiName : _uiName + ", " + _cjkName)
    readonly property int fontLarge:  Math.round((isMobile ? 15 : 15) * uiScale)
    readonly property int fontTitle:  Math.round((isMobile ? 19 : 20) * uiScale)

    // ── Spacing ───────────────────────────────────────────────────────────────
    // Mobile spacing is only marginally larger than desktop. Phones have far
    // less vertical room, so generous padding costs visible rows — the density
    // Anki gets comes from tight spacing, NOT from small tap targets. Touch
    // targets stay at the 44px HIG minimum (see touchTarget above); it's the
    // gaps between things that shrink.
    readonly property int spacingXs:   isMobile ?  2 :  2
    readonly property int spacingSm:   isMobile ?  4 :  4
    readonly property int spacingMd:   isMobile ?  7 :  8
    readonly property int spacingLg:   isMobile ? 12 : 12
    readonly property int spacingXl:   isMobile ? 18 : 18
    readonly property int pagePadding: isMobile ? 12 : 24

    // Softer, rounder shape language: larger radii + a slightly heavier
    // border read as "bubbly" rather than flat/stiff.
    readonly property int radius:      10
    readonly property int radiusLarge: 16

    readonly property int chipHeight:   isMobile ? 32 : 26
    readonly property int chipHeightSm: isMobile ? 26 : 22
    readonly property int chipPaddingH: isMobile ? 12 : 10
    readonly property int chipRadius:   chipHeight / 2

    readonly property int borderWidth:      2
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

import QtQuick.Window
import TenjinView
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true

    // Right-to-left support (Arabic, Hebrew, …). Mirroring at the root, with
    // `inherit`, flips anchors and RowLayout/GridLayout ordering for the whole
    // tree automatically — the standard Qt Quick approach. Items positioned by
    // explicit `x:` (rather than anchors/layouts) are NOT mirrored by Qt and
    // must be handled individually if any are found in RTL testing.
    LayoutMirroring.enabled: appVM.uiLayoutRightToLeft
    LayoutMirroring.childrenInherit: true
    // Mobile: oversized constants — with the Info_plist.in UILaunchScreen
    // fix in place iOS now reports the real native resolution to QQuickView
    // and clamps these down. Combined with visibility:FullScreen below.
    // Desktop sizes the window explicitly; on mobile the FullScreen window
    // takes the screen's logical size (setting width/height in logical
    // points here would magnify the whole UI -- Qt bug-trap).
    width:  Platform.isMobile ? Screen.width  : 1280
    height: Platform.isMobile ? Screen.height : 820
    minimumWidth:  Platform.isMobile ? 0 : Platform.minWindowWidth
    minimumHeight: Platform.isMobile ? 0 : Platform.minWindowHeight
    title: qsTr("Tenjin")

    // Root font: every Text and Control inherits this family (one binding →
    // consistent glyphs across all platforms). Empty until the loaders are
    // Ready, so first paint uses the system font rather than racing.
    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
    color: Platform.bg
    visibility: Platform.isMobile ? Window.FullScreen : Window.AutomaticVisibility

    // Keep the width-aware layout switch current (drives iPad split-view).
    onWidthChanged: Platform.currentWidth = width

    // Feed the platform-wide safe-area tokens from this window's SafeArea
    // attached property (Qt 6.9). Platform is a context-free singleton, so the
    // attached property must be read here, where an ApplicationWindow exists.
    // Existing consumers (header height, page margins) already read these
    // tokens; this supplies their live source. Insets update reactively on
    // rotation / notch / keyboard changes.
    // LIMITATION: SafeArea under QtQuick.Controls.Basic on the iOS 26.5 SDK is
    // unverified in-session; validate on a device build. If it fails to
    // resolve, replace these four bindings with a C++ QGuiApplication
    // safe-area helper exposed to QML (token consumers stay unchanged).
    Binding { target: Platform; property: "safeAreaTop";    value: root.SafeArea.margins.top }
    Binding { target: Platform; property: "safeAreaBottom"; value: root.SafeArea.margins.bottom }
    Binding { target: Platform; property: "safeAreaLeft";   value: root.SafeArea.margins.left }
    Binding { target: Platform; property: "safeAreaRight";  value: root.SafeArea.margins.right }

    // Page indices — must match AppViewModel::Page_t.
    readonly property int _pageWords:    0
    readonly property int _pageDecks:    1
    readonly property int _pageTags:     2
    readonly property int _pageHelp:     3
    readonly property int _pageNews:     4
    readonly property int _pageSettings: 5
    readonly property int _pageStats:    6

    // ── Keyboard shortcuts (desktop, iPad, Android tablets w/ keyboard) ──────
    // StandardKey maps to the platform-native chord automatically
    // (Cmd on macOS/iOS, Ctrl elsewhere).
    Shortcut {
        sequences: [StandardKey.Find]
        enabled: !Platform.isMobile
        onActivated: desktopSearchBox.focusSearch()
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            if (appVM.currentPage === root._pageWords) addEntryDialog.open()
            else if (appVM.currentPage === root._pageDecks) addDeckDialog.open()
            else if (appVM.currentPage === root._pageTags) addTagDialog.open()
        }
    }
    Shortcut { sequence: "Ctrl+1"; onActivated: appVM.currentPage = root._pageWords }
    Shortcut { sequence: "Ctrl+2"; onActivated: appVM.currentPage = root._pageDecks }
    Shortcut { sequence: "Ctrl+3"; onActivated: appVM.currentPage = root._pageTags }
    Shortcut { sequence: "Ctrl+,"; onActivated: appVM.currentPage = root._pageSettings }
    Shortcut { sequence: "Ctrl+4"; onActivated: appVM.currentPage = root._pageStats }
    Shortcut { sequence: "Ctrl+D"; onActivated: Platform.toggleTheme() }
    Shortcut {
        sequences: [StandardKey.HelpContents]
        onActivated: helpPopup.open()
    }
    Shortcut {
        sequence: StandardKey.Cancel  // Esc
        onActivated: if (appVM.currentPage > root._pageWords) appVM.currentPage = root._pageWords
    }

    // Callbacks exposed to pages (SettingsPage in particular) so they can
    // reach window-scoped helpers without ids.
    function openWelcomePopup() {
        welcomePopup.step = 0
        welcomePopup.open()
    }
    function openWhatsNew() { whatsNewSheet.open() }
    function openImportDialog() {
        if (Platform.isMobile) {
            // Native Files/iCloud picker where available (iOS); fall back to
            // the in-app Documents-folder picker.
            if (!appVM.openNativeImportPicker())
                importPickerDialog.open()
        }
        else if (desktopFileDialogsLoader.item) desktopFileDialogsLoader.item.openImport()
    }
    function openExportDialog() {
        if (Platform.isMobile) {
            exportFormatChooser.open()
        } else if (desktopFileDialogsLoader.item) {
            desktopFileDialogsLoader.item.openExport()
        }
    }

    // Surfaces the first news item flagged popup=true that the user hasn't
    // yet dismissed. Run after welcome flow (or at startup if welcome was
    // already acknowledged on a prior launch).
    function _showNextNewsPopup() {
        const items = appVM.newsItems
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (it.popup && !appVM.isNewsDismissed(it.id)) {
                newsLaunchPopup.currentItem = it
                newsLaunchPopup.open()
                return
            }
        }
    }

    Component.onCompleted: {
        Platform.currentWidth = width
        Platform.screenPixelDensity = Screen.pixelDensity
        // Keep the daily reminder text reflecting how many cards are due.
        // Guarded: a stats failure must never prevent the window from showing.
        try {
            if (appVM && appVM.deckVM) {
                const gs = appVM.deckVM.globalStats()
                if (gs && gs.dueToday > 0)
                    notifService.setReminderBody(
                        qsTr("You have %1 cards due for review.").arg(gs.dueToday))
            }
        } catch (e) {
            console.warn("globalStats at startup failed:", e)
        }
        Platform.theme = appVM.theme
        root._pushCustomTheme()
        Platform.reducedMotionUser = appVM.reducedMotion
        Platform.reducedMotionSystem = appVM.systemReducedMotion
        // Belt and suspenders for mobile fullscreen: after Qt's iOS bootstrap
        // has reported a real screen size, resize the QML window to match
        // it. The Info_plist.in fix should be sufficient on its own, but
        // this catches edge cases where ApplicationWindow's defaults stick.
        if (Platform.isMobile && Qt.application.screens.length > 0) {
            const s = Qt.application.screens[0]
            if (s.size && s.size.width > 0 && s.size.height > 0) {
                width  = s.size.width
                height = s.size.height
            }
        }
        // Children's-privacy age screen must come first and block everything
        // until answered. Only after an age band is set do we run the normal
        // onboarding (welcome carousel, what's-new, news popups).
        if (appVM.ageScreenRequired) {
            ageGate.thisYear = new Date().getFullYear()
            ageGate.birthYear = ageGate.thisYear - 20
            ageGate.open()
        } else if (!appVM.welcomeAcknowledged) {
            welcomePopup.open()
        } else if (appVM.consumeJustUpdated()) {
            whatsNewSheet.open()
        } else {
            _showNextNewsPopup()
        }
    }
    Connections {
        target: appVM
        function onThemeChanged() { Platform.theme = appVM.theme }
        function onReducedMotionChanged() { Platform.reducedMotionUser = appVM.reducedMotion }
        function onCustomThemeChanged() { root._pushCustomTheme() }
    }

    // Copy the persisted custom-theme anchors from AppViewModel into the
    // Platform singleton so the derived palette updates live. Called at startup
    // and whenever the user edits a custom color.
    function _pushCustomTheme() {
        Platform.customAccent  = appVM.customAccent
        Platform.customBg      = appVM.customBg
        Platform.customSurface = appVM.customSurface
        Platform.customText    = appVM.customText
        Platform.customDanger  = appVM.customDanger
        Platform.customSuccess = appVM.customSuccess
        Platform.customBorder  = appVM.customBorder
        Platform.customIsDark  = appVM.customIsDark
    }

    // ── Header ─────────────────────────────────────────────────────────────
    header: Rectangle {
        height: Platform.headerHeight + Platform.safeAreaTop
        color: Platform.surface
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Platform.border
        }

        // Desktop header
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: Platform.safeAreaTop }
            spacing: 12
            visible: Platform.useWideLayout

            // Sidebar toggle
            Rectangle {
                Layout.preferredWidth: Math.round(Platform.touchTarget * 0.8)
                Layout.preferredHeight: Math.round(Platform.touchTarget * 0.8)
                radius: Platform.radius
                color: sidebarToggleArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Text {
                    anchors.centerIn: parent
                    text: appVM.sidebarVM.collapsed ? TenjinIcons.chevronForward : TenjinIcons.chevronBack
                    font.family: TenjinIcons.family
                    font.pixelSize: Platform.fontLarge
                    color: Platform.textMuted
                }
                MouseArea {
                    id: sidebarToggleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.sidebarVM.collapsed = !appVM.sidebarVM.collapsed
                }
            }

            // App icon badge — clickable, returns to Words page.
            Rectangle {
                id: appBadge
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Platform.radius
                color: Platform.accent
                Text {
                    anchors.centerIn: parent
                    text: "\u5929"
                    color: Platform.bg
                    font.pixelSize: 19
                    font.bold: true
                }
                HoverHandler { id: badgeHover }
                ToolTip.visible: badgeHover.hovered
                ToolTip.text: qsTr("Tenjin")
                ToolTip.delay: 500
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.currentPage = root._pageWords
                }
            }

            Item { Layout.fillWidth: true }

            // Universal search — searches words, tags, and decks. Always
            // visible (not gated on page), since results from each kind
            // route to the matching destination.
            SearchBox { parentWidth: root.width }

            // About — hover popup with version info.
            IconBtn {
                id: aboutBtn
                glyph: TenjinIcons.info
                accessibleName: qsTr("Help")
                onActivated: aboutPopup.opened ? aboutPopup.close() : aboutPopup.open()
            }
            // Tags page is reached via the Sidebar's "Manage tags" footer
            // (the canonical entry-point). The previous header "#" IconBtn
            // duplicated that affordance and cluttered the top bar.
            IconBtn {
                id: helpBtn
                glyph: "?"
                accessibleName: qsTr("Help")
                active: helpPopup.opened
                onActivated: helpPopup.open()
            }
            IconBtn {
                id: newsBtn
                glyph: TenjinIcons.news
                accessibleName: qsTr("News")
                active: newsPopup.opened
                onActivated: newsPopup.open()
            }
            IconBtn {
                id: settingsBtn
                glyph: TenjinIcons.settings
                accessibleName: qsTr("Settings")
                active: appVM.currentPage === root._pageSettings
                onActivated: appVM.currentPage = root._pageSettings
            }
            IconBtn {
                glyph: TenjinIcons.autoAwesome
                accessibleName: qsTr("Statistics")
                active: appVM.currentPage === root._pageStats
                onActivated: appVM.currentPage = root._pageStats
            }
            IconBtn {
                id: langBtn
                glyph: TenjinIcons.globe
                accessibleName: qsTr("Interface language")
                onActivated: languageMenu.open()
            }
            IconBtn {
                id: themeBtn
                glyph: Platform.isDark ? TenjinIcons.lightMode : TenjinIcons.darkMode
                accessibleName: Platform.isDark ? qsTr("Switch to light mode") : qsTr("Switch to dark mode")
                onActivated: appVM.setTheme(Platform.isDark ? 0 : 1)
            }
            IconBtn {
                id: debugBtn
                visible: !Platform.isMobile
                glyph: TenjinIcons.keyboard
                accessibleName: qsTr("Keyboard shortcuts")
                active: debugDrawer.visible
                onActivated: debugDrawer.visible = !debugDrawer.visible
            }
        }

        // Mobile header — drawer toggle, search box (now universal), and
        // the contextual + Add button (only on content pages).
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: Platform.safeAreaTop }
            spacing: 10
            visible: !Platform.useWideLayout

            Rectangle {
                Layout.preferredWidth: Platform.touchTarget
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: hamburgerArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Text {
                    anchors.centerIn: parent
                    text: TenjinIcons.menu
                    font.family: TenjinIcons.family
                    font.pixelSize: Platform.fontTitle
                    color: Platform.textPrimary
                }
                MouseArea {
                    id: hamburgerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebarDrawer.open()
                }
            }

            // Universal search — always visible. Replaces the previous
            // "page title" slot on non-Words pages since the drawer already
            // indicates which page is active.
            SearchBox {
                id: desktopSearchBox
                parentWidth: root.width
                dropdownEnabled: true
                Layout.fillWidth: true
            }

            // Add button — only relevant on the content pages.
            Rectangle {
                visible: appVM.currentPage <= root._pageTags
                Layout.preferredWidth: mAddLabel.implicitWidth + 24
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: mAddArea.containsMouse ? Platform.accentDark : Platform.accent
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                scale: mAddArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                Text {
                    id: mAddLabel
                    anchors.centerIn: parent
                    text: appVM.currentPage === root._pageWords ? qsTr("+ Word")
                        : appVM.currentPage === root._pageDecks ? qsTr("+ Deck")
                                                                 : qsTr("+ Tag")
                    color: Platform.bg
                    font.pixelSize: Platform.fontBase
                    font.bold: true
                }
                MouseArea {
                    id: mAddArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (appVM.currentPage === root._pageWords) addEntryDialog.open()
                        else if (appVM.currentPage === root._pageDecks) addDeckDialog.open()
                        else addTagDialog.open()
                    }
                }
            }
        }
    }

    // ── About popup ─────────────────────────────────────────────────────────
    Popup {
        id: aboutPopup
        parent: aboutBtn
        // Anchor just below/left of the button; not modal and not hover-driven
        // so it cannot flicker (hover-open fought the modal overlay stealing the
        // hover). Opened by click; closes on outside-press or Escape.
        x: aboutBtn.width - width
        y: aboutBtn.height + Platform.spacingXs
        width: Platform.popupWidthSm
        height: aboutCol.implicitHeight + Platform.spacingLg * 2
        padding: Platform.spacingLg
        modal: false
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            implicitWidth: Platform.popupWidthSm
            implicitHeight: aboutCol.implicitHeight + Platform.spacingLg * 2
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }
        contentItem: ColumnLayout {
            id: aboutCol
            spacing: Platform.spacingSm
            Text { text: qsTr("Tenjin"); color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }
            Text { text: qsTr("Vocabulary & spaced-repetition study"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; height: Platform.borderWidth; color: Platform.border; opacity: 0.5 }
            Text { text: qsTr("Version 1.0"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
            Text { text: qsTr("Qt 6.8"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
            Text { text: Qt.platform.os; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Platform.effDurationFast }
                NumberAnimation { property: "scale";   from: 0.96; to: 1; duration: Platform.effDurationFast; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Platform.effDurationFast }
        }
    }

    // ── News & Help pop-outs (formerly full pages) ──────────────────────────
    SheetPopup {
        id: newsPopup
        title: qsTr("News")
        NewsPage {
            anchors.fill: parent
            onBackRequested: newsPopup.close()
        }
    }
    SheetPopup {
        id: helpPopup
        title: qsTr("Help")
        HelpPage {
            anchors.fill: parent
            onBackRequested: helpPopup.close()
        }
    }

    // Export format chooser (mobile). JSON is the full round-trip backup; CSV
    // is a flat spreadsheet projection (lossy — no relations/decks/structure).
    SheetPopup {
        id: exportFormatChooser
        title: qsTr("Export as")

        function _finish(path) {
            exportFormatChooser.close()
            if (path.length > 0) {
                if (!appVM.shareFile(path))
                    notifService.toast(qsTr("Exported to: ") + path)
            } else {
                notifService.toast(qsTr("Export failed — see logs."))
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { label: qsTr("JSON (full backup)"), fmt: "json" },
                    { label: qsTr("CSV (spreadsheet)"),   fmt: "csv" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Platform.touchTarget + 8
                    radius: Platform.radius
                    color: fmtArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    AppText {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.label
                        font.pixelSize: Platform.fontBase
                    }
                    MouseArea {
                        id: fmtArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: exportFormatChooser._finish(
                            parent.modelData.fmt === "csv"
                                ? appVM.exportToDocumentsCsv()
                                : appVM.exportToDocuments())
                    }
                }
            }
        }
    }

    // ── Language FILTER menu (sidebar globe button) ─────────────────────────
    // Distinct from the interface-language menu: this narrows the visible
    // words/decks to a single language via EntryViewModel.currentLanguageFilter.
    // An empty string means "all languages".
    Popup {
        id: languageFilterMenu
        parent: Overlay.overlay
        modal: true
        dim: true
        Overlay.modal: Rectangle { color: "#66000000" }
        width: Platform.isMobile ? Math.min(root.width - 32, 360) : 360
        height: Math.min(root.height - Platform.safeAreaTop - Platform.safeAreaBottom - 80, 520)
        anchors.centerIn: Overlay.overlay
        background: Rectangle {
            implicitWidth: languageFilterMenu.width
            implicitHeight: languageFilterMenu.height
            color: Platform.surface; radius: Platform.radiusLarge
            border.color: Platform.border; border.width: Platform.borderWidth
        }

        padding: Platform.spacingLg
        contentItem: ColumnLayout {
            spacing: Platform.spacingMd

            Text {
                text: qsTr("Filter by language")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontLarge
                font.bold: true
            }

            ListView {
                id: filterList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // "All languages" sentinel (empty code) followed by the codes
                // actually present in the collection.
                model: [""].concat(appVM.availableLanguages)

                delegate: Rectangle {
                    required property var modelData
                    width: filterList.width
                    height: Platform.touchTarget
                    radius: Platform.radius
                    readonly property bool isAll: modelData === ""
                    readonly property bool isCurrent: appVM.entryVM.currentLanguageFilter === modelData
                    color: filterArea.containsMouse || isCurrent ? Platform.surfaceAlt : "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: Platform.spacingMd; rightMargin: Platform.spacingMd }
                        spacing: Platform.spacingMd

                        LanguageFlagRow {
                            visible: !parent.parent.isAll
                            codes: parent.parent.isAll ? [] : LanguageFlags.flags(modelData)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.parent.isAll ? qsTr("All languages")
                                                      : appVM.languageDisplayName(modelData)
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.bold: parent.parent.isCurrent
                        }
                        Text {
                            visible: parent.parent.isCurrent
                            text: TenjinIcons.check
                            font.family: TenjinIcons.family
                            color: Platform.accent
                            font.pixelSize: Platform.fontLarge
                        }
                    }
                    MouseArea {
                        id: filterArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appVM.entryVM.currentLanguageFilter = modelData
                            languageFilterMenu.close()
                        }
                    }
                }
            }
        }
    }

    // ── Quick language menu (header globe button) ───────────────────────────
    Popup {
        id: languageMenu
        parent: Overlay.overlay
        modal: true
        dim: true
        Overlay.modal: Rectangle { color: "#66000000" }
        padding: 0
        width: Platform.isMobile ? Math.min(root.width - 32, 360) : 360
        height: Math.min(root.height - Platform.safeAreaTop - Platform.safeAreaBottom - 80, 520)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? Math.max(Platform.safeAreaTop + 8, (parent.height - height) / 2) : 0
        background: Rectangle { color: Platform.surface; radius: Platform.radiusLarge; border.color: Platform.border; border.width: 1 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Platform.spacingLg
            spacing: Platform.spacingMd

            Text {
                text: qsTr("Interface language")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontLarge
                font.bold: true
            }

            ListView {
                id: langList
                readonly property Popup menuRef: languageMenu
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: appVM.supportedUiLanguages
                spacing: 2
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    width: langList.width
                    height: Platform.touchTarget
                    radius: Platform.radius
                    readonly property bool isCurrent: appVM.uiLanguage === modelData
                    color: langDelegateArea.containsMouse ? Platform.surfaceAlt
                           : (isCurrent ? Platform.surfaceAlt : "transparent")

                    RowLayout {
                        anchors { fill: parent; leftMargin: Platform.spacingMd; rightMargin: Platform.spacingMd }
                        spacing: Platform.spacingMd

                        LanguageFlagRow {
                            codes: LanguageFlags.flags(modelData)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: LanguageFlags.name(modelData) || modelData
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.bold: parent.parent.isCurrent
                        }
                        Text {
                            visible: parent.parent.isCurrent
                            text: TenjinIcons.check
                            font.family: TenjinIcons.family
                            color: Platform.accent
                            font.pixelSize: Platform.fontLarge
                        }
                    }
                    MouseArea {
                        id: langDelegateArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appVM.setUiLanguage(modelData)
                            langList.menuRef.close()
                        }
                    }
                }
            }
        }
    }

    // ── Children's-privacy age gate (shown first on first launch) ────────────
    AgeGateDialog {
        id: ageGate
        onAnswered: function(band) {
            // After the age band is recorded, continue the normal onboarding.
            // An under-13 answer (band === 1) routes into the parental-consent
            // flow; until consent is granted, off-device features stay disabled.
            if (band === 1) {
                parentalConsentNotice.open()
            } else if (!appVM.welcomeAcknowledged) {
                welcomePopup.open()
            } else {
                root._showNextNewsPopup()
            }
        }
    }

    // Parental-consent notice for under-13 users. This is the in-app entry point
    // to the (verifiable) parental-consent flow. The actual verification (the
    // COPPA VPC step) is performed by the backend / a consent vendor; this notice
    // explains the situation and lets a parent begin. Until consent is granted,
    // the app runs fully local (no off-device data collection).
    Popup {
        id: parentalConsentNotice
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width - 16, 480) : 480
        height: pcCol.implicitHeight + Platform.spacingXl * 2
        x: parent ? Math.max(8, (parent.width - width) / 2) : 8
        y: parent ? Math.max(Platform.safeAreaTop + 8, (parent.height - height) / 2) : 8
        background: Rectangle { color: Platform.surface; radius: Platform.radiusLarge; border.color: Platform.border; border.width: 1 }

        ColumnLayout {
            id: pcCol
            width: parent.width
            anchors.centerIn: parent
            spacing: Platform.spacingLg

            Text {
                Layout.fillWidth: true
                Layout.margins: Platform.spacingXl
                Layout.bottomMargin: 0
                text: qsTr("A parent's help is needed")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingXl
                Layout.rightMargin: Platform.spacingXl
                text: qsTr("Because this account is for someone under 13, a parent or guardian needs to give permission before any data can sync or leave the device. Until then, Tenjin works fully on this device — all your words, decks, and reviews are saved here.")
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Button {
                id: pcContinue
                Layout.fillWidth: true
                Layout.margins: Platform.spacingXl
                Layout.topMargin: 0
                implicitHeight: Platform.touchTarget + 8
                text: qsTr("Continue on this device")
                onClicked: {
                    parentalConsentNotice.close()
                    if (!appVM.welcomeAcknowledged)
                        welcomePopup.open()
                    else
                        root._showNextNewsPopup()
                }
                background: Rectangle { radius: Platform.radius; color: Platform.accent }
                contentItem: Text { text: pcContinue.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // ── Welcome carousel ───────────────────────────────────────────────────
    Popup {
        id: welcomePopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 16, 560) : 560
        height: Platform.isMobile ? Math.min(root.height - Platform.safeAreaTop - Platform.safeAreaBottom - 60, 680) : 640
        x: parent ? Math.max(8, (parent.width  - width)  / 2) : 8
        y: parent ? Math.max(Platform.safeAreaTop + 8, (parent.height - height) / 2) : 8

        property int step: 0
        readonly property int stepCount: 4
        readonly property var titles: [
            qsTr("Welcome to Tenjin"),
            qsTr("Words, decks, tags"),
            qsTr("Spaced-repetition reviews"),
            qsTr("You're ready")
        ]
        readonly property var bodies: [
            qsTr("Your personal study companion for vocabulary, phrases, and anything else worth remembering. Let's take a quick look around."),
            qsTr("Add words with rich content — text, formulas, images, audio, video. Group related words into decks, and tag them however you like for fast filtering."),
            qsTr("Decks schedule cards using a proven spaced-repetition algorithm. Review what's due each day and Tenjin tracks what you know."),
            qsTr("Toggle light and dark from the header at any time. Open Help anytime to revisit the basics, or News to see what's new.")
        ]

        function finish() {
            close()
            appVM.setWelcomeAcknowledged(true)
            root._showNextNewsPopup()
        }

        background: Rectangle {
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }

        contentItem: ColumnLayout {
            spacing: Platform.spacingMd
            Item { Layout.preferredHeight: Platform.spacingMd; Layout.fillWidth: true }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 76
                implicitHeight: 76
                radius: Platform.radiusLarge
                color: Platform.accent
                Text {
                    anchors.centerIn: parent
                    text: "\u5929"
                    color: Platform.bg
                    font.pixelSize: 46
                    font.bold: true
                }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Platform.spacingLg
                Layout.rightMargin: Platform.spacingLg
                clip: true
                ColumnLayout {
                    width: welcomePopup.width - 2 * Platform.spacingLg
                    spacing: Platform.spacingMd
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Platform.spacingSm
                        horizontalAlignment: Text.AlignHCenter
                        text: welcomePopup.titles[welcomePopup.step]
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: welcomePopup.bodies[welcomePopup.step]
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                    Item { Layout.preferredHeight: Platform.spacingMd }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: welcomePopup.stepCount
                    delegate: Rectangle {
                        required property int index
                        width: index === welcomePopup.step ? 20 : 8
                        height: 8
                        radius: 4
                        color: index === welcomePopup.step ? Platform.accent : Platform.border
                        Behavior on width { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: Platform.effDurationFast } }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingLg
                Layout.rightMargin: Platform.spacingLg
                Layout.bottomMargin: Platform.spacingLg
                spacing: Platform.spacingMd
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: skipLabel.implicitWidth + 24
                    radius: Platform.radius
                    color: skipArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    visible: welcomePopup.step < welcomePopup.stepCount - 1
                    Text { id: skipLabel; anchors.centerIn: parent; text: qsTr("Skip"); color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                    MouseArea { id: skipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: welcomePopup.finish() }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: backLabel.implicitWidth + 28
                    radius: Platform.radius
                    color: backArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border; border.width: Platform.borderWidth
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    visible: welcomePopup.step > 0
                    Text { id: backLabel; anchors.centerIn: parent; text: qsTr("Back"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (welcomePopup.step > 0) welcomePopup.step-- }
                }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: nextLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: nextArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    scale: nextArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                    Text { id: nextLabel; anchors.centerIn: parent; text: welcomePopup.step < welcomePopup.stepCount - 1 ? "Next" : "Got it"; color: Platform.bg; font.pixelSize: Platform.fontBase; font.bold: true }
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (welcomePopup.step < welcomePopup.stepCount - 1)
                                welcomePopup.step++
                            else
                                welcomePopup.finish()
                        }
                    }
                }
            }
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0;    to: 1; duration: Platform.effDurationMed }
                NumberAnimation { property: "scale";   from: 0.94; to: 1; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0;    duration: Platform.effDurationFast }
                NumberAnimation { property: "scale";   from: 1; to: 0.96; duration: Platform.effDurationFast }
            }
        }
    }

    // ── News launch popup ──────────────────────────────────────────────────
    Popup {
        id: newsLaunchPopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 16, 540) : 540
        height: Platform.isMobile ? Math.min(root.height - Platform.safeAreaTop - Platform.safeAreaBottom - 60, 520) : 480
        x: parent ? Math.max(8, (parent.width  - width)  / 2) : 8
        y: parent ? Math.max(Platform.safeAreaTop + 8, (parent.height - height) / 2) : 8

        property var currentItem: null
        function finish() { if (currentItem) appVM.dismissNews(currentItem.id); close() }
        background: Rectangle {
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }
        contentItem: ColumnLayout {
            spacing: 0
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.headerHeight + 8
                color: "transparent"
                ColumnLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: 1
                    Item { Layout.fillHeight: true }
                    Text { text: qsTr("What's new"); color: Platform.textPrimary; font.pixelSize: Platform.fontTitle; font.bold: true }
                    Text { text: newsLaunchPopup.currentItem ? newsLaunchPopup.currentItem.date : ""; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    Item { Layout.fillHeight: true }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Platform.spacingLg
                Layout.rightMargin: Platform.spacingLg
                Layout.topMargin: Platform.spacingLg
                clip: true
                ColumnLayout {
                    width: newsLaunchPopup.width - 2 * Platform.spacingLg
                    spacing: Platform.spacingMd
                    Text {
                        Layout.fillWidth: true
                        text: newsLaunchPopup.currentItem ? newsLaunchPopup.currentItem.title : ""
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: newsLaunchPopup.currentItem ? newsLaunchPopup.currentItem.body : ""
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                    Item { Layout.preferredHeight: Platform.spacingMd }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingLg
                Layout.rightMargin: Platform.spacingLg
                Layout.bottomMargin: Platform.spacingLg
                Layout.topMargin: Platform.spacingMd
                spacing: Platform.spacingMd
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: seeAllLabel.implicitWidth + 24
                    radius: Platform.radius
                    color: seeAllArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text { id: seeAllLabel; anchors.centerIn: parent; text: qsTr("See all news"); color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                    MouseArea {
                        id: seeAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { newsLaunchPopup.close(); newsPopup.open() }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: gotItLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: gotItArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    scale: gotItArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                    Text { id: gotItLabel; anchors.centerIn: parent; text: qsTr("Got it"); color: Platform.bg; font.pixelSize: Platform.fontBase; font.bold: true }
                    MouseArea {
                        id: gotItArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: newsLaunchPopup.finish()
                    }
                }
            }
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0;    to: 1; duration: Platform.effDurationMed }
                NumberAnimation { property: "scale";   from: 0.94; to: 1; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0;    duration: Platform.effDurationFast }
                NumberAnimation { property: "scale";   from: 1; to: 0.96; duration: Platform.effDurationFast }
            }
        }
    }

    // ── Body ───────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            // Persist across all pages: previously hidden once you navigated
            // past Tags (Help/News/Settings/Stats), which meant the word list
            // vanished. Now it stays available on every page; only the collapse
            // toggle hides it.
            visible: Platform.useWideLayout && !appVM.sidebarVM.collapsed
            Layout.preferredWidth: Platform.sidebarWidth
            Layout.fillHeight: true
            onAddEntryRequested: addEntryDialog.open()
            onAddDeckRequested: addDeckDialog.open()
            onAddTagRequested: addTagDialog.open()
            onLanguageRequested: languageFilterMenu.open()
            onSyncRequested: cloudService.syncDecks("")
            onImportRequested: root.openImportDialog()
            onExportRequested: root.openExportDialog()
        }
        Rectangle {
            visible: Platform.useWideLayout && !appVM.sidebarVM.collapsed
            Layout.preferredWidth: 1; Layout.fillHeight: true
            color: Platform.border
        }

        // Page area with a directional slide + fade on page change. The whole
        // StackLayout is offset/faded so individual pages need no changes. The
        // animation fires only on currentPage change (no idle cost) and is
        // disabled under Platform.reducedMotion (offset/duration collapse to 0).
        Item {
            id: pageArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property int _prevPage: appVM.currentPage

            Connections {
                target: appVM
                function onCurrentPageChanged() {
                    var dir = appVM.currentPage >= pageArea._prevPage ? 1 : -1
                    pageArea._prevPage = appVM.currentPage
                    if (Platform.reducedMotion) {
                        pageStack.x = 0; pageStack.opacity = 1
                        return
                    }
                    pageStack.opacity = 0
                    pageStack.x = dir * Platform.pageSlideDistance
                    pageSlide.restart()
                    pageFade.restart()
                }
            }

            NumberAnimation {
                id: pageSlide; target: pageStack; property: "x"; to: 0
                duration: Platform.effDurationMed; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: pageFade; target: pageStack; property: "opacity"; to: 1
                duration: Platform.effDurationMed; easing.type: Easing.OutCubic
            }

            StackLayout {
                id: pageStack
                anchors.fill: parent
                currentIndex: appVM.currentPage
                EntryPage    {}
                DeckListPage {}
                TagsPage     {
                    onAddTagRequested: addTagDialog.open()
                    onBackRequested:   appVM.currentPage = root._pageWords
                }
                // Help and News are now pop-outs (see helpPopup / newsPopup
                // below), but their StackLayout slots are kept as empty items so
                // the positional page indices (Settings=5, Stats=6, …) stay
                // stable. Navigating to these indices is no longer wired.
                Item {}
                Item {}
                SettingsPage {
                    applicationRoot: root
                    onBackRequested: appVM.currentPage = root._pageWords
                }
                StatsPage    { onBackRequested: appVM.currentPage = root._pageWords }
            }
        }
    }

    // Mobile navigation drawer
    Drawer {
        id: sidebarDrawer
        width: Math.min(Platform.sidebarWidth, root.width * 0.82)
        height: parent.height
        edge: Qt.LeftEdge
        background: Rectangle { color: Platform.surface }

        MobileDrawer {
            anchors.fill: parent
            onNavigate: (page) => {
                sidebarDrawer.close()
                // Help and News are pop-outs, not StackLayout pages (their slots
                // are empty placeholders). Route their nav to the popups.
                if (page === root._pageHelp) { helpPopup.open(); return }
                if (page === root._pageNews) { newsPopup.open(); return }
                if (page === root._pageWords) appVM.entryVM.clearSelection()
                appVM.currentPage = page
            }
            onImportRequested: { sidebarDrawer.close(); root.openImportDialog() }
            onExportRequested: { sidebarDrawer.close(); root.openExportDialog() }
            onSyncRequested: { sidebarDrawer.close(); cloudService.syncDecks("") }
            onLanguageFilterRequested: { sidebarDrawer.close(); languageFilterMenu.open() }
            onUiLanguageRequested: { sidebarDrawer.close(); languageMenu.open() }
        }
    }

    // File pickers
    // FileDialogs live in a desktop-only component so Main.qml never imports
    // QtQuick.Dialogs (absent on iOS, where importing it fails the whole file).
    // On mobile, import/export uses the custom picker and exportToDocuments().
    Loader {
        id: desktopFileDialogsLoader
        active: !Platform.isMobile
        source: "components/DesktopFileDialogs.qml"
        onLoaded: {
            item.importAccepted.connect(function(f) {
                const s = f.toString().toLowerCase()
                if (s.endsWith(".apkg")) appVM.importAnki(f)
                else appVM.importData(f)
            })
            item.exportAccepted.connect(function(f) {
                if (f.toString().toLowerCase().endsWith(".csv"))
                    appVM.exportDataCsv(f)
                else
                    appVM.exportData(f)
            })
            item.syncFolderAccepted.connect(function(f) {
                // Desktop has no C++ folder picker (no QtWidgets), so QML hands
                // the chosen folder to the backend, which validates+persists it.
                cloudSync.setFolder(f.toString())
            })
        }
    }

    // Opens the desktop folder picker for the cloud-sync target. Mobile uses the
    // platform's own mechanism (iCloud is implicit; Android opens the SAF tree
    // picker), so this is desktop-only.
    function chooseSyncFolder() {
        if (!Platform.isMobile && desktopFileDialogsLoader.item)
            desktopFileDialogsLoader.item.openSyncFolder()
        else
            cloudSync.chooseLocation()
    }

    // Import picker for mobile (FileDialog unavailable on iOS)
    ImportPickerDialog { id: importPickerDialog }

    // Add dialogs
    WhatsNewSheet  { id: whatsNewSheet }
    AddEntryDialog { id: addEntryDialog }
    AddDeckDialog  { id: addDeckDialog }
    AddTagDialog   { id: addTagDialog }

    // Error toast
    Connections { target: appVM.entryVM; function onErrorOccurred(msg) { toast.show(msg) } }
    Connections { target: appVM.deckVM;  function onErrorOccurred(msg) { toast.show(msg) } }
    Connections { target: appVM.reviewVM; function onErrorOccurred(msg) { toast.show(msg) } }
    // Cloud sync feedback — surfaces the result/message (including the consent
    // block and the current "coming soon" stub) so the Sync button gives the
    // user a response rather than failing silently.
    Connections {
        target: cloudService
        function onSyncResult(status, message) { if (message && message.length > 0) toast.show(message) }
        function onNetworkError(message) { if (message && message.length > 0) toast.show(message) }
    }
    Connections {
        target: notifService
        function onToastRequested(message, level) { toast.show(message) }
        function onAlertRequested(title, body) {
            // No dedicated alert dialog yet; surface as a toast so the message
            // is never lost. (A richer alert UI can replace this later.)
            toast.show(title + (body.length > 0 ? (": " + body) : ""))
        }
    }

    Rectangle {
        id: toast
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 32 + Platform.safeAreaBottom }
        width: toastText.implicitWidth + 32; height: 36
        radius: Platform.radius; color: Platform.danger
        visible: false; opacity: 0; z: 100
        property string message: ""
        function show(msg) { message = msg; visible = true; toastAnim.restart() }
        Text {
            id: toastText
            anchors.centerIn: parent
            text: toast.message
            color: "white"
            font.pixelSize: Platform.fontBase
        }
        SequentialAnimation {
            id: toastAnim
            ParallelAnimation {
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: Platform.effDurationFast; easing.type: Easing.OutCubic }
                NumberAnimation { target: toast; property: "anchors.bottomMargin"; to: 32 + Platform.safeAreaBottom; duration: Platform.effDurationMed; easing.type: Easing.OutBack }
            }
            PauseAnimation  { duration: 2500 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Platform.effDurationMed }
            ScriptAction    { script: toast.visible = false }
        }
    }

    // Debug drawer
    Rectangle {
        id: debugDrawer
        visible: false
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: Math.min(parent.width * 0.4, 460)
        color: Platform.surface
        z: 200
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Platform.border
        }

        property int tab: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Debug console"); color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: ["Log", "Eval"]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        implicitWidth: dbgTabText.implicitWidth + 18
                        implicitHeight: 26
                        radius: Platform.radius
                        color: debugDrawer.tab === index ? Platform.accent : Platform.bg
                        border.color: Platform.border; border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        Text { id: dbgTabText; anchors.centerIn: parent; text: modelData; color: debugDrawer.tab === index ? Platform.bg : Platform.textPrimary; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: debugDrawer.tab = index }
                    }
                }
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26; radius: Platform.radius
                    color: dbgCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text { anchors.centerIn: parent; text: TenjinIcons.close; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                    MouseArea { id: dbgCloseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: debugDrawer.visible = false }
                }
            }

            ColumnLayout {
                visible: debugDrawer.tab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                ListView {
                    id: logView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: logModel
                    onCountChanged: positionViewAtEnd()
                    delegate: Rectangle {
                        required property string level
                        required property string message
                        required property string time
                        width: ListView.view.width
                        implicitHeight: logLine.implicitHeight + 6
                        color: "transparent"
                        Row {
                            id: logLine
                            width: parent.width - 8
                            x: 4
                            spacing: 6
                            Text { text: time; color: Platform.textMuted; font.pixelSize: Platform.fontSmall; font.family: Platform.fontMono }
                            Text {
                                width: parent.width - 70
                                text: message
                                wrapMode: Text.Wrap
                                font.pixelSize: Platform.fontSmall
                                font.family: Platform.fontMono
                                color: level === "critical" ? Platform.danger
                                     : level === "warning"  ? Platform.accentDark
                                                              : Platform.textPrimary
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar {}
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: logModel.count + " entries"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    Rectangle {
                        implicitWidth: clearText.implicitWidth + 16; implicitHeight: 24; radius: Platform.radius
                        color: clearArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                        border.color: Platform.border; border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        Text { id: clearText; anchors.centerIn: parent; text: qsTr("Clear"); color: Platform.textPrimary; font.pixelSize: Platform.fontSmall }
                        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: logModel.clear() }
                    }
                }
            }

            ColumnLayout {
                visible: debugDrawer.tab === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Evaluate a JS expression in the window scope. Result and errors print to the Log tab.")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontSmall
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Platform.radius
                    color: Platform.bg
                    border.color: Platform.border; border.width: 1
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6
                        TextArea {
                            id: evalInput
                            placeholderText: qsTr("e.g. appVM.theme  /  Platform.toggleTheme()")
                            color: Platform.textPrimary
                            font.pixelSize: 12
                            font.family: Platform.fontMono
                            wrapMode: TextArea.Wrap
                            background: null
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Platform.radius
                    color: runArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text { anchors.centerIn: parent; text: qsTr("Run"); color: Platform.bg; font.pixelSize: 12; font.bold: true }
                    MouseArea {
                        id: runArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: debugDrawer.runEval()
                    }
                }
            }
        }

        function runEval() {
            const src = evalInput.text.trim()
            if (src.length === 0) return
            try {
                const obj = Qt.createQmlObject(
                    'import QtQuick; QtObject { function run() { return (' + src + ') } }',
                    debugDrawer, "eval")
                const r = obj.run()
                console.log("eval> " + src + "  =>  " + r)
                obj.destroy()
            } catch (e) {
                try {
                    const obj2 = Qt.createQmlObject(
                        'import QtQuick; QtObject { function run() { ' + src + ' } }',
                        debugDrawer, "evalStmt")
                    obj2.run()
                    console.log("eval> " + src + "  (ok)")
                    obj2.destroy()
                } catch (e2) {
                    console.warn("eval error: " + e2)
                }
            }
        }
    }
}



import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    visible: true
    // Mobile: oversized constants — with the Info_plist.in UILaunchScreen
    // fix in place iOS now reports the real native resolution to QQuickView
    // and clamps these down. Combined with visibility:FullScreen below.
    width:  Platform.isMobile ? 1080 : 1280
    height: Platform.isMobile ? 1920 : 820
    minimumWidth:  Platform.isMobile ? 0 : Platform.minWindowWidth
    minimumHeight: Platform.isMobile ? 0 : Platform.minWindowHeight
    title: "Tenjin"
    color: Platform.bg
    // 1 = AutomaticVisibility, 5 = FullScreen (Window visibility enum ints).
    visibility: Platform.isMobile ? 5 : 1

    // Page indices — must match AppViewModel::Page_t.
    readonly property int _pageWords:    0
    readonly property int _pageDecks:    1
    readonly property int _pageTags:     2
    readonly property int _pageHelp:     3
    readonly property int _pageNews:     4
    readonly property int _pageSettings: 5

    // Callbacks exposed to pages (SettingsPage in particular) so they can
    // reach window-scoped helpers without ids.
    function openWelcomePopup() {
        welcomePopup.step = 0
        welcomePopup.open()
    }
    function openImportDialog() { importDialog.open() }
    function openExportDialog() { exportDialog.open() }

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
        Platform.theme = appVM.theme
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
        if (!appVM.welcomeAcknowledged)
            welcomePopup.open()
        else
            _showNextNewsPopup()
    }
    Connections {
        target: appVM
        function onThemeChanged() { Platform.theme = appVM.theme }
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
            visible: !Platform.isMobile

            // Sidebar toggle
            Rectangle {
                Layout.preferredWidth: Math.round(Platform.touchTarget * 0.8)
                Layout.preferredHeight: Math.round(Platform.touchTarget * 0.8)
                radius: Platform.radius
                color: sidebarToggleArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                Text {
                    anchors.centerIn: parent
                    text: appVM.sidebarVM.collapsed ? "\u203A" : "\u2039"
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
                ToolTip.text: "Tenjin"
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
                glyph: "\u24D8"
                onActivated: aboutPopup.open()
                onHoveredChanged: hovered ? aboutPopup.open() : aboutPopup.close()
            }
            // Tags page is reached via the Sidebar's "Manage tags" footer
            // (the canonical entry-point). The previous header "#" IconBtn
            // duplicated that affordance and cluttered the top bar.
            IconBtn {
                id: helpBtn
                glyph: "?"
                active: appVM.currentPage === root._pageHelp
                onActivated: appVM.currentPage = root._pageHelp
            }
            IconBtn {
                id: newsBtn
                glyph: "\u2709"
                active: appVM.currentPage === root._pageNews
                onActivated: appVM.currentPage = root._pageNews
            }
            IconBtn {
                id: settingsBtn
                glyph: "\u2699"
                active: appVM.currentPage === root._pageSettings
                onActivated: appVM.currentPage = root._pageSettings
            }
            IconBtn {
                id: themeBtn
                glyph: Platform.isDark ? "\u2600" : "\u263E"
                onActivated: appVM.setTheme(Platform.isDark ? 0 : 1)
            }
            IconBtn {
                id: debugBtn
                glyph: "\u2328"
                active: debugDrawer.visible
                onActivated: debugDrawer.visible = !debugDrawer.visible
            }
        }

        // Mobile header — drawer toggle, search box (now universal), and
        // the contextual + Add button (only on content pages).
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: Platform.safeAreaTop }
            spacing: 10
            visible: Platform.isMobile

            Rectangle {
                Layout.preferredWidth: Platform.touchTarget
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: hamburgerArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                Text {
                    anchors.centerIn: parent
                    text: "\u2630"
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
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                scale: mAddArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                Text {
                    id: mAddLabel
                    anchors.centerIn: parent
                    text: appVM.currentPage === root._pageWords ? "+ Word"
                        : appVM.currentPage === root._pageDecks ? "+ Deck"
                                                                 : "+ Tag"
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

    // ── About popup (hover) ────────────────────────────────────────────────
    Popup {
        id: aboutPopup
        parent: aboutBtn
        x: aboutBtn.width - width
        y: aboutBtn.height + Platform.spacingXs
        width: Platform.popupWidthSm
        padding: Platform.spacingLg
        closePolicy: Popup.NoAutoClose
        background: Rectangle {
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }
        contentItem: ColumnLayout {
            spacing: Platform.spacingSm
            Text { text: "Tenjin"; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }
            Text { text: "Vocabulary & spaced-repetition study"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; height: Platform.borderWidth; color: Platform.border; opacity: 0.5 }
            Text { text: "Version 1.0"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
            Text { text: "Qt 6.8"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
            Text { text: Qt.platform.os; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Platform.durationFast }
                NumberAnimation { property: "scale";   from: 0.96; to: 1; duration: Platform.durationFast; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Platform.durationFast }
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
            "Welcome to Tenjin",
            "Words, decks, tags",
            "Spaced-repetition reviews",
            "You're ready"
        ]
        readonly property var bodies: [
            "Your personal study companion for vocabulary, phrases, and anything else worth remembering. Let's take a quick look around.",
            "Add words with rich content — text, formulas, images, audio, video. Group related words into decks, and tag them however you like for fast filtering.",
            "Decks schedule cards using a proven spaced-repetition algorithm. Review what's due each day and Tenjin tracks what you know.",
            "Toggle light and dark from the header at any time. Open Help anytime to revisit the basics, or News to see what's new."
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
                        Behavior on width { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: Platform.durationFast } }
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
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    visible: welcomePopup.step < welcomePopup.stepCount - 1
                    Text { id: skipLabel; anchors.centerIn: parent; text: "Skip"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                    MouseArea { id: skipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: welcomePopup.finish() }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: backLabel.implicitWidth + 28
                    radius: Platform.radius
                    color: backArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border; border.width: Platform.borderWidth
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    visible: welcomePopup.step > 0
                    Text { id: backLabel; anchors.centerIn: parent; text: "Back"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (welcomePopup.step > 0) welcomePopup.step-- }
                }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: nextLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: nextArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    scale: nextArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
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
                NumberAnimation { property: "opacity"; from: 0;    to: 1; duration: Platform.durationMed }
                NumberAnimation { property: "scale";   from: 0.94; to: 1; duration: Platform.durationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0;    duration: Platform.durationFast }
                NumberAnimation { property: "scale";   from: 1; to: 0.96; duration: Platform.durationFast }
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
                    Text { text: "What's new"; color: Platform.textPrimary; font.pixelSize: Platform.fontTitle; font.bold: true }
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
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text { id: seeAllLabel; anchors.centerIn: parent; text: "See all news"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                    MouseArea {
                        id: seeAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { newsLaunchPopup.close(); appVM.currentPage = root._pageNews }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: gotItLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: gotItArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    scale: gotItArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                    Text { id: gotItLabel; anchors.centerIn: parent; text: "Got it"; color: Platform.bg; font.pixelSize: Platform.fontBase; font.bold: true }
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
                NumberAnimation { property: "opacity"; from: 0;    to: 1; duration: Platform.durationMed }
                NumberAnimation { property: "scale";   from: 0.94; to: 1; duration: Platform.durationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0;    duration: Platform.durationFast }
                NumberAnimation { property: "scale";   from: 1; to: 0.96; duration: Platform.durationFast }
            }
        }
    }

    // ── Body ───────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            visible: !Platform.isMobile && !appVM.sidebarVM.collapsed && appVM.currentPage <= root._pageTags
            Layout.preferredWidth: Platform.sidebarWidth
            Layout.fillHeight: true
            onAddEntryRequested: addEntryDialog.open()
            onAddDeckRequested: addDeckDialog.open()
            onAddTagRequested: addTagDialog.open()
        }
        Rectangle {
            visible: !Platform.isMobile && !appVM.sidebarVM.collapsed && appVM.currentPage <= root._pageTags
            Layout.preferredWidth: 1; Layout.fillHeight: true
            color: Platform.border
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: appVM.currentPage
            EntryPage    {}
            DeckListPage {}
            TagsPage     {
                onAddTagRequested: addTagDialog.open()
                onBackRequested:   appVM.currentPage = root._pageWords
            }
            HelpPage     { onBackRequested: appVM.currentPage = root._pageWords }
            NewsPage     { onBackRequested: appVM.currentPage = root._pageWords }
            SettingsPage {
                applicationRoot: root
                onBackRequested: appVM.currentPage = root._pageWords
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
                if (page === root._pageWords) appVM.entryVM.clearSelection()
                appVM.currentPage = page
                sidebarDrawer.close()
            }
            onImportRequested: { sidebarDrawer.close(); importDialog.open() }
            onExportRequested: { sidebarDrawer.close(); exportDialog.open() }
        }
    }

    // File pickers
    FileDialog {
        id: importDialog
        title: "Import collection"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Tenjin export (*.json)", "All files (*)"]
        onAccepted: appVM.importData(selectedFile)
    }
    FileDialog {
        id: exportDialog
        title: "Export collection"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Tenjin export (*.json)"]
        defaultSuffix: "json"
        onAccepted: appVM.exportData(selectedFile)
    }

    // Add dialogs
    AddEntryDialog { id: addEntryDialog }
    AddDeckDialog  { id: addDeckDialog }
    AddTagDialog   { id: addTagDialog }

    // Error toast
    Connections { target: appVM.entryVM; function onErrorOccurred(msg) { toast.show(msg) } }
    Connections { target: appVM.deckVM;  function onErrorOccurred(msg) { toast.show(msg) } }

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
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: toast; property: "anchors.bottomMargin"; to: 32 + Platform.safeAreaBottom; duration: 220; easing.type: Easing.OutBack }
            }
            PauseAnimation  { duration: 2500 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
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
                Text { text: "Debug console"; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }
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
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { id: dbgTabText; anchors.centerIn: parent; text: modelData; color: debugDrawer.tab === index ? Platform.bg : Platform.textPrimary; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: debugDrawer.tab = index }
                    }
                }
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26; radius: Platform.radius
                    color: dbgCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text { anchors.centerIn: parent; text: "\u2715"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
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
                            Text { text: time; color: Platform.textMuted; font.pixelSize: 11; font.family: "monospace" }
                            Text {
                                width: parent.width - 70
                                text: message
                                wrapMode: Text.Wrap
                                font.pixelSize: 11
                                font.family: "monospace"
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
                    Text { Layout.fillWidth: true; text: logModel.count + " entries"; color: Platform.textMuted; font.pixelSize: 11 }
                    Rectangle {
                        implicitWidth: clearText.implicitWidth + 16; implicitHeight: 24; radius: Platform.radius
                        color: clearArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                        border.color: Platform.border; border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { id: clearText; anchors.centerIn: parent; text: "Clear"; color: Platform.textPrimary; font.pixelSize: 11 }
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
                    text: "Evaluate a JS expression in the window scope. Result and errors print to the Log tab."
                    color: Platform.textMuted
                    font.pixelSize: 11
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
                            placeholderText: "e.g. appVM.theme  /  Platform.toggleTheme()"
                            color: Platform.textPrimary
                            font.pixelSize: 12
                            font.family: "monospace"
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
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text { anchors.centerIn: parent; text: "Run"; color: Platform.bg; font.pixelSize: 12; font.bold: true }
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


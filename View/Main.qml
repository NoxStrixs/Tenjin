import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    visible: true
    // Platform.screenWidth/Height resolve via Qt.application.screens — no
    // QtQuick.Window dependency, so the iOS static build doesn't have to
    // link a plugin that wasn't reliably loading.
    width:  Platform.isMobile ? Platform.screenWidth  : 1280
    height: Platform.isMobile ? Platform.screenHeight : 820
    minimumWidth:  Platform.isMobile ? 0 : Platform.minWindowWidth
    minimumHeight: Platform.isMobile ? 0 : Platform.minWindowHeight
    title: "Tenjin"
    color: Platform.bg

    // Bundled news items. Each: id (unique), date (YYYY-MM-DD), title, body,
    // popup (whether to surface as a launch popup). Later this list will be
    // replaced/augmented by a fetched JSON feed; the schema stays the same.
    property var newsItems: [
        { id: "v1.0-launch",
          date: "2026-06-04",
          title: "Welcome to Tenjin 1.0",
          body:  "Tenjin's first public release. Words, decks, spaced-repetition reviews, tags, and rich content blocks — all stored locally on your device.",
          popup: false },
        { id: "multi-platform",
          date: "2026-06-04",
          title: "Coming soon: more platforms & polish",
          body:  "We're working on broader platform coverage (Android, polished macOS builds), multilingual UI, in-app reminders, and a redesigned analytics page. Stay tuned.",
          popup: false }
    ]

    // Apply the persisted theme on startup, and keep Platform in sync if the
    // stored preference changes
    Component.onCompleted: {
        Platform.theme = appVM.theme
        if (!appVM.welcomeAcknowledged)
            welcomePopup.open()
    }
    Connections {
        target: appVM
        function onThemeChanged() { Platform.theme = appVM.theme }
    }

    // Header
    header: Rectangle {
        height: Platform.headerHeight
        color: Platform.surface
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Platform.border
        }

        // Desktop header
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
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

            // App icon badge — placeholder. Replaces the previous "Tenjin"
            // text logo. Swap for an Image { source: "qrc:/..." } once a
            // real icon asset is wired through the QML module.
            Rectangle {
                id: appBadge
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Platform.radius
                color: Platform.accent
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                Text {
                    anchors.centerIn: parent
                    text: "\u5929" // 天
                    color: Platform.bg
                    font.pixelSize: 19
                    font.bold: true
                }
                HoverHandler { id: badgeHover }
                ToolTip.visible: badgeHover.hovered
                ToolTip.text: "Tenjin"
                ToolTip.delay: 500
            }

            Item { Layout.fillWidth: true }

            SearchBox {
                visible: appVM.currentPage === 0
                parentWidth: root.width
            }

            IconBtn {
                id: aboutBtn
                glyph: "\u24D8"
                onActivated: aboutPopup.open()
                onHoveredChanged: hovered ? aboutPopup.open() : aboutPopup.close()
            }
            IconBtn {
                id: helpBtn
                glyph: "?"
                onActivated: helpPopup.open()
            }
            IconBtn {
                id: newsBtn
                glyph: "\u2709" // ✉
                onActivated: newsPopup.open()
            }
            IconBtn {
                id: settingsBtn
                glyph: "\u2699" // ⚙
                onActivated: settingsPopup.open()
            }
            IconBtn {
                id: themeBtn
                glyph: Platform.isDark ? "\u2600" : "\u263E"
                onActivated: appVM.setTheme(Platform.isDark ? 0 : 1)
            }
            IconBtn {
                id: debugBtn
                glyph: "\u2328" // ⌨ keyboard — debug/eval console
                active: debugDrawer.visible
                onActivated: debugDrawer.visible = !debugDrawer.visible
            }
        }

        // Mobile header
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
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

            Text {
                visible: appVM.currentPage !== 0
                text: appVM.currentPage === 1 ? "Decks" : "Tags"
                color: Platform.textPrimary
                font.pixelSize: Platform.fontLarge
                font.bold: true
            }

            SearchBox {
                visible: appVM.currentPage === 0
                parentWidth: root.width
                dropdownEnabled: false
                Layout.fillWidth: true
            }

            Item { Layout.fillWidth: true; visible: appVM.currentPage !== 0 }

            Rectangle {
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
                    text: appVM.currentPage === 0 ? "+ Word"
                        : appVM.currentPage === 1 ? "+ Deck"
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
                        if (appVM.currentPage === 0) addEntryDialog.open()
                        else if (appVM.currentPage === 1) addDeckDialog.open()
                        else addTagDialog.open()
                    }
                }
            }
        }
    }

    // About popup (header-anchored, hover-driven)
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

    // ── Welcome carousel ────────────────────────────────────────────────────
    Popup {
        id: welcomePopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 24, 480) : 480
        height: Platform.isMobile ? Math.min(root.height - 64, 560) : 540
        x: parent ? Math.max(12, (parent.width  - width)  / 2) : 12
        y: parent ? Math.max(12, (parent.height - height) / 2) : 12

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
        }

        background: Rectangle {
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }

        contentItem: ColumnLayout {
            spacing: Platform.spacingLg

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

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingXl
                Layout.rightMargin: Platform.spacingXl
                horizontalAlignment: Text.AlignHCenter
                text: welcomePopup.titles[welcomePopup.step]
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingXl
                Layout.rightMargin: Platform.spacingXl
                horizontalAlignment: Text.AlignHCenter
                text: welcomePopup.bodies[welcomePopup.step]
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                wrapMode: Text.WordWrap
                lineHeight: 1.35
            }

            Item { Layout.fillHeight: true }

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
                    Text {
                        id: skipLabel
                        anchors.centerIn: parent
                        text: "Skip"
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                    }
                    MouseArea {
                        id: skipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: welcomePopup.finish()
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: backLabel.implicitWidth + 28
                    radius: Platform.radius
                    color: backArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border
                    border.width: Platform.borderWidth
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    visible: welcomePopup.step > 0
                    Text {
                        id: backLabel
                        anchors.centerIn: parent
                        text: "Back"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                    }
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (welcomePopup.step > 0) welcomePopup.step--
                    }
                }

                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: nextLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: nextArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    scale: nextArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                    Text {
                        id: nextLabel
                        anchors.centerIn: parent
                        text: welcomePopup.step < welcomePopup.stepCount - 1 ? "Next" : "Got it"
                        color: Platform.bg
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
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

    // ── Help popup ──────────────────────────────────────────────────────────
    Popup {
        id: helpPopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 24, 560) : 560
        height: Platform.isMobile ? Math.min(root.height - 64, 640) : Math.min(root.height - 80, 640)
        x: parent ? Math.max(12, (parent.width  - width)  / 2) : 12
        y: parent ? Math.max(12, (parent.height - height) / 2) : 12

        readonly property var sections: [
            { h: "Getting started",
              b: "Tenjin organizes the things you want to remember into Words, gathered into Decks, and labelled with Tags. Everything lives locally on this device unless you export it." },
            { h: "Adding a word",
              b: "From the Words page, tap + Word. Give it a headword, then add content blocks below — plain text, formulas (LaTeX), images, audio, video, or links. Drag handles let you arrange the layout." },
            { h: "Decks & reviews",
              b: "On the Decks page, create a deck and add words to it. Open a deck and start a Review session — Tenjin uses spaced repetition to schedule what you see next based on how well you knew it." },
            { h: "Tags & filtering",
              b: "Tag words on the word's detail page or from the Tags page. The Tags filter in the sidebar / mobile filter bar lets you narrow the Words list to any combination, in Any or All mode." },
            { h: "Import & export",
              b: "Your entire collection exports to a single JSON file (sidebar footer on desktop, drawer on mobile). Import the same JSON on another device to move everything across." },
            { h: "Re-run this walkthrough",
              b: "Settings (gear icon) → Show welcome again. The carousel will re-open immediately and play through all four steps." }
        ]

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
                Layout.preferredHeight: Platform.headerHeight
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingMd }
                    Text {
                        Layout.fillWidth: true
                        text: "Help"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        radius: Platform.radius
                        color: helpCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { anchors.centerIn: parent; text: "\u2715"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                        MouseArea { id: helpCloseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: helpPopup.close() }
                    }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ColumnLayout {
                    width: helpPopup.width
                    spacing: Platform.spacingMd

                    Repeater {
                        model: helpPopup.sections
                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.leftMargin: Platform.spacingLg
                            Layout.rightMargin: Platform.spacingLg
                            Layout.topMargin: index === 0 ? Platform.spacingLg : 0
                            spacing: Platform.spacingSm
                            Text {
                                Layout.fillWidth: true
                                text: modelData.h
                                color: Platform.textPrimary
                                font.pixelSize: Platform.fontLarge
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.b
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase
                                wrapMode: Text.WordWrap
                                lineHeight: 1.35
                            }
                            Rectangle { Layout.fillWidth: true; Layout.topMargin: Platform.spacingSm; Layout.preferredHeight: Platform.borderWidth; color: Platform.border; opacity: 0.5 }
                        }
                    }

                    Item { Layout.preferredHeight: Platform.spacingLg }
                }
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Platform.durationMed }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Platform.durationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Platform.durationFast }
        }
    }

    // ── News popup ──────────────────────────────────────────────────────────
    Popup {
        id: newsPopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 24, 560) : 560
        height: Platform.isMobile ? Math.min(root.height - 64, 640) : Math.min(root.height - 80, 640)
        x: parent ? Math.max(12, (parent.width  - width)  / 2) : 12
        y: parent ? Math.max(12, (parent.height - height) / 2) : 12

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
                Layout.preferredHeight: Platform.headerHeight
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingMd }
                    Text {
                        Layout.fillWidth: true
                        text: "News"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        radius: Platform.radius
                        color: newsCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { anchors.centerIn: parent; text: "\u2715"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                        MouseArea { id: newsCloseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: newsPopup.close() }
                    }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.newsItems
                spacing: Platform.spacingMd
                topMargin: Platform.spacingLg
                bottomMargin: Platform.spacingLg
                leftMargin: Platform.spacingLg
                rightMargin: Platform.spacingLg

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width - 2 * Platform.spacingLg
                    implicitHeight: newsCol.implicitHeight + 2 * Platform.spacingMd
                    radius: Platform.radius
                    color: Platform.bg
                    border.color: Platform.border
                    border.width: Platform.borderWidth
                    ColumnLayout {
                        id: newsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Platform.spacingMd }
                        spacing: Platform.spacingXs
                        Text {
                            text: modelData.date
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontTiny
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontLarge
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.body
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontBase
                            wrapMode: Text.WordWrap
                            lineHeight: 1.35
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "No news yet."
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                }

                ScrollBar.vertical: ScrollBar {}
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Platform.durationMed }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Platform.durationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Platform.durationFast }
        }
    }

    // ── Settings popup ──────────────────────────────────────────────────────
    Popup {
        id: settingsPopup
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        width:  Platform.isMobile ? Math.min(root.width  - 24, 480) : 480
        height: Platform.isMobile ? Math.min(root.height - 64, 560) : Math.min(root.height - 80, 560)
        x: parent ? Math.max(12, (parent.width  - width)  / 2) : 12
        y: parent ? Math.max(12, (parent.height - height) / 2) : 12

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
                Layout.preferredHeight: Platform.headerHeight
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingMd }
                    Text {
                        Layout.fillWidth: true
                        text: "Settings"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        radius: Platform.radius
                        color: setCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { anchors.centerIn: parent; text: "\u2715"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                        MouseArea { id: setCloseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsPopup.close() }
                    }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: settingsPopup.width
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Platform.spacingLg
                        Layout.topMargin: Platform.spacingLg
                        Layout.bottomMargin: Platform.spacingSm
                        text: "Appearance"
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget + 16
                        color: themeRowArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                            spacing: Platform.spacingMd
                            Text {
                                text: Platform.isDark ? "\u2600" : "\u263E"
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontLarge
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: "Theme"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                                Text { text: Platform.isDark ? "Dark" : "Light"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                            }
                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 28
                                radius: 14
                                color: Platform.isDark ? Platform.accent : Platform.border
                                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    y: 3
                                    x: Platform.isDark ? parent.width - width - 3 : 3
                                    color: Platform.bg
                                    Behavior on x { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                        MouseArea {
                            id: themeRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appVM.setTheme(Platform.isDark ? 0 : 1)
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Platform.spacingLg
                        Layout.topMargin: Platform.spacingLg
                        Layout.bottomMargin: Platform.spacingSm
                        text: "Language"
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget + 16
                        color: "transparent"
                        opacity: 0.55
                        RowLayout {
                            anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                            spacing: Platform.spacingMd
                            Text { text: "\uD83C\uDF10"; font.pixelSize: Platform.fontLarge }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: "Interface language"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                                Text { text: "English (more languages coming soon)"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Platform.spacingLg
                        Layout.topMargin: Platform.spacingLg
                        Layout.bottomMargin: Platform.spacingSm
                        text: "Onboarding"
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget + 16
                        color: welcomeAgainArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                            spacing: Platform.spacingMd
                            Text { text: "\u21BB"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: "Show welcome again"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                                Text { text: "Re-open the first-launch carousel now"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                            }
                            Text { text: "\u203A"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                        }
                        MouseArea {
                            id: welcomeAgainArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appVM.setWelcomeAcknowledged(false)
                                welcomePopup.step = 0
                                settingsPopup.close()
                                welcomePopup.open()
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Platform.spacingLg }
                }
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Platform.durationMed }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Platform.durationMed; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Platform.durationFast }
        }
    }

    // Body
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            visible: !Platform.isMobile && !appVM.sidebarVM.collapsed
            Layout.preferredWidth: Platform.sidebarWidth
            Layout.fillHeight: true
            onAddEntryRequested: addEntryDialog.open()
            onAddDeckRequested: addDeckDialog.open()
            onAddTagRequested: addTagDialog.open()
        }
        Rectangle {
            visible: !Platform.isMobile && !appVM.sidebarVM.collapsed
            Layout.preferredWidth: 1; Layout.fillHeight: true
            color: Platform.border
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: appVM.currentPage
            EntryPage     {}
            DeckListPage {}
            TagsPage     {}
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
                if (page === 0) appVM.entryVM.clearSelection()
                appVM.currentPage = page
                sidebarDrawer.close()
            }
            onImportRequested:   { sidebarDrawer.close(); importDialog.open() }
            onExportRequested:   { sidebarDrawer.close(); exportDialog.open() }
            onHelpRequested:     { sidebarDrawer.close(); helpPopup.open() }
            onNewsRequested:     { sidebarDrawer.close(); newsPopup.open() }
            onSettingsRequested: { sidebarDrawer.close(); settingsPopup.open() }
        }
    }

    // Import / export file pickers
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

    // Dialogs
    AddEntryDialog { id: addEntryDialog }
    AddDeckDialog  { id: addDeckDialog }
    AddTagDialog   { id: addTagDialog }

    // Error toast
    Connections { target: appVM.entryVM; function onErrorOccurred(msg) { toast.show(msg) } }
    Connections { target: appVM.deckVM;  function onErrorOccurred(msg) { toast.show(msg) } }

    Rectangle {
        id: toast
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 32 }
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
                NumberAnimation { target: toast; property: "anchors.bottomMargin"; to: 32; duration: 220; easing.type: Easing.OutBack }
            }
            PauseAnimation  { duration: 2500 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
            ScriptAction    { script: toast.visible = false }
        }
    }

    // Debug console
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

        property int tab: 0

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


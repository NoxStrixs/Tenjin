import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    visible: true
    width:  Platform.isMobile ? Screen.width  : 1280
    height: Platform.isMobile ? Screen.height : 820
    minimumWidth:  Platform.isMobile ? 0 : Platform.minWindowWidth
    minimumHeight: Platform.isMobile ? 0 : Platform.minWindowHeight
    title: "Tenjin"
    color: Platform.bg

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
                // Show the full name on hover as a tooltip so the brand
                // isn't lost when we drop the text label.
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
                id: themeBtn
                glyph: Platform.isDark ? "\u2600" : "\u263E"
                onActivated: appVM.setTheme(Platform.isDark ? 0 : 1)
            }
            IconBtn {
                id: debugBtn
                glyph: "\u2699"
                active: debugDrawer.visible
                onActivated: debugDrawer.visible = !debugDrawer.visible
            }
        }

        // Mobile header
        // Hamburger (opens nav drawer) and contextual controls
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
                    text: "\u2630"   // hamburger
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

    // About popup
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

    // Welcome carousel — first-launch onboarding. Multi-step, persistently
    // dismissible via Skip or the Got it button on the final step. Acknowledged
    // state lives in QSettings (onboarding/welcomeAcknowledged) so this only
    // ever appears once unless the user explicitly re-enables it from Settings.
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
            "Toggle light and dark from the header at any time. More features — news, settings, language, reminders — are on the way."
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

            // Inner padding wrapper so background hugs full popup size.
            Item { Layout.preferredHeight: Platform.spacingMd; Layout.fillWidth: true }

            // 天 badge
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 76
                implicitHeight: 76
                radius: Platform.radiusLarge
                color: Platform.accent
                Text {
                    anchors.centerIn: parent
                    text: "\u5929" // 天
                    color: Platform.bg
                    font.pixelSize: 46
                    font.bold: true
                }
            }

            // Title
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

            // Body
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

            // Step dots
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

            // Footer buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.spacingLg
                Layout.rightMargin: Platform.spacingLg
                Layout.bottomMargin: Platform.spacingLg
                spacing: Platform.spacingMd

                // Skip — only while there are still steps left.
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

                // Back — only after the first step.
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

                // Next / Got it
                Rectangle {
                    Layout.preferredHeight: Platform.touchTarget
                    Layout.preferredWidth: nextLabel.implicitWidth + 32
                    radius: Platform.radius
                    color: nextArea.containsMouse ? Platform.accentDark : Platform.accent
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
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
                // Land on the Words list (not a stale detail) when picking Words.
                if (page === 0) appVM.entryVM.clearSelection()
                appVM.currentPage = page
                sidebarDrawer.close()
            }
            onImportRequested: { sidebarDrawer.close(); importDialog.open() }
            onExportRequested: { sidebarDrawer.close(); exportDialog.open() }
        }
    }

    // Import / export file pickers (driven by the mobile drawer; desktop keeps
    // its own controls in the sidebar footer).
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
    AddDeckDialog { id: addDeckDialog }
    AddTagDialog { id: addTagDialog }

    // Error toast
    Connections { target: appVM.entryVM; function onErrorOccurred(msg) { toast.show(msg) } }
    Connections { target: appVM.deckVM; function onErrorOccurred(msg) { toast.show(msg) } }

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

            // Header and tab switch.
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

            // Log viewer
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

            // Evaluator
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
                // Retry as statements (no return value) if expression form failed.
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


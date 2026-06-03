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

    // Apply the persisted theme on startup, and keep Platform in sync if the
    // stored preference changes
    Component.onCompleted: Platform.theme = appVM.theme
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

            Text {
                text: "Tenjin"
                font.pixelSize: 16
                font.bold: true
                color: Platform.textPrimary
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
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 150 }
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
                        Text { id: dbgTabText; anchors.centerIn: parent; text: modelData; color: debugDrawer.tab === index ? Platform.bg : Platform.textPrimary; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: debugDrawer.tab = index }
                    }
                }
                Rectangle {
                    implicitWidth: 26; implicitHeight: 26; radius: Platform.radius
                    color: dbgCloseArea.containsMouse ? Platform.surfaceAlt : "transparent"
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





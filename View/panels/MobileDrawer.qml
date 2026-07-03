pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

Rectangle {
    id: drawerRoot
    color: Platform.surface

    signal navigate(int page)
    signal importRequested()
    signal exportRequested()
    signal syncRequested()
    signal languageFilterRequested()
    signal uiLanguageRequested()

    property bool aboutExpanded: false

    // Page indices must match AppViewModel::Page_t in C++.
    readonly property int _pageWords:    0
    readonly property int _pageDecks:    1
    readonly property int _pageTags:     2
    readonly property int _pageHelp:     3
    readonly property int _pageNews:     4
    readonly property int _pageSettings: 5

    Flickable {
        anchors.fill: parent
        contentHeight: drawerCol.implicitHeight
        contentWidth:  width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: drawerCol
            width: drawerRoot.width
            spacing: 0

            // App badge + name
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.headerHeight + 12 + Platform.safeAreaTop
                color: Platform.surface
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: Platform.safeAreaTop }
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Platform.radius
                        color: Platform.accent
                        Text {
                            anchors.centerIn: parent
                            text: "\u5929" // 天
                            color: Platform.bg
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Tenjin")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
            }

            // Content nav — Words / Decks / Tags
            Repeater {
                model: [
                    { label: qsTr("Words"), page: 0, glyph: TenjinIcons.words },
                    { label: qsTr("Decks"), page: 1, glyph: TenjinIcons.decks },
                    { label: qsTr("Tags"),  page: 2, glyph: TenjinIcons.tags }
                ]
                delegate: Rectangle {
                    id: navItem
                    required property var modelData
                    readonly property bool current: appVM.currentPage === modelData.page
                    Layout.fillWidth: true
                    Layout.preferredHeight: Platform.touchTarget + 10
                    color: navArea.containsMouse || current ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: navItem.current ? Platform.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 14
                        Text {
                            text: navItem.modelData.glyph
                            font.family: TenjinIcons.family
                            font.pixelSize: Platform.fontLarge
                            color: navItem.current ? Platform.accent : Platform.textMuted
                        }
                        Text {
                            Layout.fillWidth: true
                            text: navItem.modelData.label
                            color: navItem.current ? Platform.accent : Platform.textPrimary
                            font.pixelSize: Platform.fontLarge
                            font.bold: navItem.current
                        }
                    }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawerRoot.navigate(navItem.modelData.page)
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; Layout.topMargin: 8 }

            // Utility nav — Help / News / Settings. Same navigate() signal as
            // the content rows; routing in Main.qml just sets appVM.currentPage.
            Repeater {
                model: [
                    { label: qsTr("Statistics"), glyph: TenjinIcons.autoAwesome, page: 6 },
                    { label: qsTr("Help"),       glyph: TenjinIcons.help,        page: 3 },
                    { label: qsTr("News"),       glyph: TenjinIcons.news,        page: 4 },
                    { label: qsTr("Settings"),   glyph: TenjinIcons.settings,    page: 5 }
                ]
                delegate: Rectangle {
                    id: utilItem
                    required property var modelData
                    readonly property bool current: appVM.currentPage === modelData.page
                    Layout.fillWidth: true
                    Layout.preferredHeight: Platform.touchTarget + 10
                    color: utilArea.containsMouse || current ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: utilItem.current ? Platform.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 14
                        Text {
                            text: utilItem.modelData.glyph
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontLarge
                            font.weight: utilItem.modelData.glyph === "?" ? Font.Bold : Font.Normal
                        }
                        Text {
                            Layout.fillWidth: true
                            text: utilItem.modelData.label
                            color: utilItem.current ? Platform.accent : Platform.textPrimary
                            font.pixelSize: Platform.fontLarge
                            font.bold: utilItem.current
                        }
                    }
                    MouseArea {
                        id: utilArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawerRoot.navigate(utilItem.modelData.page)
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; Layout.topMargin: 8 }

            // Theme toggle — convenience: still in the drawer beyond Settings.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 10
                color: themeArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                    spacing: 14
                    Text { text: Platform.isDark ? TenjinIcons.lightMode : TenjinIcons.darkMode; font.family: TenjinIcons.family; font.pixelSize: Platform.fontLarge; color: Platform.textMuted }
                    Text {
                        Layout.fillWidth: true
                        text: Platform.isDark ? qsTr("Light theme") : qsTr("Dark theme")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                    }
                }
                MouseArea {
                    id: themeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.setTheme(Platform.isDark ? 0 : 1)
                }
            }

            // Import / Export (also reachable from Settings page Data section).
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 8
                Repeater {
                    model: [
                        { label: qsTr("Import"), glyph: TenjinIcons.upload,   act: 0 },
                        { label: qsTr("Export"), glyph: TenjinIcons.download, act: 1 }
                    ]
                    delegate: Rectangle {
                        id: ieItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget
                        radius: Platform.radius
                        color: ieArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                        border.color: Platform.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        scale: ieArea.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: ieItem.modelData.glyph; font.family: TenjinIcons.family; color: Platform.accentDark; font.pixelSize: Platform.fontBase }
                            Text { text: ieItem.modelData.label; color: Platform.accentDark; font.pixelSize: Platform.fontBase; font.bold: true }
                        }
                        MouseArea {
                            id: ieArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ieItem.modelData.act === 0 ? drawerRoot.importRequested()
                                                                  : drawerRoot.exportRequested()
                        }
                    }
                }
            }

            // Language filter + interface language + sync — parity with the
            // desktop sidebar (globe filter, top-bar globe) and sidebar sync.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                spacing: 8
                Repeater {
                    model: [
                        { label: qsTr("Language filter"),    glyph: TenjinIcons.globe, act: 0 },
                        { label: qsTr("Interface language"), glyph: TenjinIcons.globe, act: 1 },
                        { label: qsTr("Sync now"),           glyph: TenjinIcons.sync,  act: 2 }
                    ]
                    delegate: Rectangle {
                        id: extraItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget
                        radius: Platform.radius
                        color: extraArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                        border.color: Platform.border
                        border.width: 1
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 8
                            Text { text: extraItem.modelData.glyph; font.family: TenjinIcons.family; color: Platform.accentDark; font.pixelSize: Platform.fontBase }
                            Text { Layout.fillWidth: true; text: extraItem.modelData.label; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                            Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                        }
                        MouseArea {
                            id: extraArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (extraItem.modelData.act === 0) drawerRoot.languageFilterRequested()
                                else if (extraItem.modelData.act === 1) drawerRoot.uiLanguageRequested()
                                else drawerRoot.syncRequested()
                            }
                        }
                    }
                }
            }

            // About expansion stays at the bottom.
            Rectangle {
                Layout.fillWidth: true
                visible: drawerRoot.aboutExpanded
                Layout.preferredHeight: aboutCol.implicitHeight + 24
                color: Platform.bg
                ColumnLayout {
                    id: aboutCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 3
                    Text { text: qsTr("Tenjin"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                    Text { text: qsTr("Vocabulary & spaced-repetition study"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Text { text: qsTr("Version 1.0"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 6 + Platform.safeAreaBottom
                color: aboutArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Platform.border }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16; bottomMargin: Platform.safeAreaBottom }
                    Text { text: TenjinIcons.info + "  " + qsTr("About"); font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontBase; Layout.fillWidth: true }
                    Text { text: drawerRoot.aboutExpanded ? TenjinIcons.expandLess : TenjinIcons.expandMore; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
                }
                MouseArea {
                    id: aboutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: drawerRoot.aboutExpanded = !drawerRoot.aboutExpanded
                }
            }
        }
    }
}



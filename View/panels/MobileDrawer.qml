pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Rectangle {
    id: drawerRoot
    color: Platform.surface

    signal navigate(int page)
    signal importRequested()
    signal exportRequested()
    signal helpRequested()
    signal newsRequested()
    signal settingsRequested()

    property bool aboutExpanded: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // App badge + name
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.headerHeight + 12
            color: Platform.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
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
                    text: "Tenjin"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
        }

        // Page navigation
        Repeater {
            model: [
                { label: "Words", page: 0, glyph: "\uD83D\uDCD6" },
                { label: "Decks", page: 1, glyph: "\uD83D\uDCDA" },
                { label: "Tags",  page: 2, glyph: "\uD83C\uDFF7\uFE0F" }
            ]
            delegate: Rectangle {
                id: navItem
                required property var modelData
                readonly property bool current: appVM.currentPage === modelData.page
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 10
                color: navArea.containsMouse || current ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    color: navItem.current ? Platform.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                    spacing: 14
                    Text { text: navItem.modelData.glyph; font.pixelSize: Platform.fontLarge }
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

        // Secondary menu — Help / News / Settings
        Repeater {
            model: [
                { label: "Help",     glyph: "?",      sig: "help" },
                { label: "News",     glyph: "\u2709", sig: "news" },
                { label: "Settings", glyph: "\u2699", sig: "settings" }
            ]
            delegate: Rectangle {
                id: secItem
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 10
                color: secArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                    spacing: 14
                    Text {
                        text: secItem.modelData.glyph
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontLarge
                        font.bold: secItem.modelData.glyph === "?"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: secItem.modelData.label
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                    }
                }
                MouseArea {
                    id: secArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if      (secItem.modelData.sig === "help")     drawerRoot.helpRequested()
                        else if (secItem.modelData.sig === "news")     drawerRoot.newsRequested()
                        else if (secItem.modelData.sig === "settings") drawerRoot.settingsRequested()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; Layout.topMargin: 8 }

        // Theme toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + 10
            color: themeArea.containsMouse ? Platform.surfaceAlt : "transparent"
            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                spacing: 14
                Text { text: Platform.isDark ? "\u2600" : "\u263E"; font.pixelSize: Platform.fontLarge; color: Platform.textMuted }
                Text {
                    Layout.fillWidth: true
                    text: Platform.isDark ? "Light theme" : "Dark theme"
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

        // Import / Export
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            Repeater {
                model: [{ label: "Import", act: 0 }, { label: "Export", act: 1 }]
                delegate: Rectangle {
                    id: ieItem
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: ieArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    scale: ieArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                    Text { anchors.centerIn: parent; text: ieItem.modelData.label; color: Platform.accentDark; font.pixelSize: Platform.fontBase; font.bold: true }
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

        Item { Layout.fillHeight: true }

        // About
        Rectangle {
            Layout.fillWidth: true
            visible: drawerRoot.aboutExpanded
            Layout.preferredHeight: aboutCol.implicitHeight + 24
            color: Platform.bg
            ColumnLayout {
                id: aboutCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 3
                Text { text: "Tenjin"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                Text { text: "Vocabulary & spaced-repetition study"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Text { text: "Version 1.0"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2 }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + 6
            color: aboutArea.containsMouse ? Platform.surfaceAlt : "transparent"
            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Platform.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                Text { text: "\u24D8  About"; color: Platform.textMuted; font.pixelSize: Platform.fontBase; Layout.fillWidth: true }
                Text { text: drawerRoot.aboutExpanded ? "\u25B4" : "\u25BE"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
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


pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Mobile navigation drawer. Pure navigation + app-level actions; the lists live
// on their respective pages. Hosted by a Drawer in Main.qml.
Rectangle {
    id: drawerRoot
    color: Platform.surface

    // page: 0 = Words, 1 = Decks, 2 = Tags
    signal navigate(int page)
    signal importRequested()
    signal exportRequested()

    property bool aboutExpanded: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── App name ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.headerHeight + 12
            color: Platform.surface
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "Tenjin"
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }
        }

        // ── Page navigation ──────────────────────────────────────────
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

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    color: navItem.current ? Platform.accent : "transparent"
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

        // ── Theme toggle ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + 10
            color: themeArea.containsMouse ? Platform.surfaceAlt : "transparent"
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

        // ── Import / Export ──────────────────────────────────────────
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

        // ── About (inline expand) ────────────────────────────────────
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


import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Symbol picker for the formula editor. Opens from the "more symbols" button and
// offers two ways to find a symbol: a live search box (type "sum", "greek",
// "vector"…) and category tabs. Selecting a symbol calls onPick(snippet); the
// editor inserts it at the caret and the popup stays open so several symbols can
// be inserted in a row (closed with Esc or the close button).
Popup {
    id: root

    // Emitted with the chosen LaTeX snippet; the host (FormulaBlock) inserts it.
    // A signal (not an "onPick" property — names starting with "on" collide with
    // QML's signal-handler syntax and make the whole type fail to compile).
    signal picked(string snippet)

    modal: false
    focus: true
    padding: 0
    // Sized to sit under the trigger button; the host positions it.
    implicitWidth: Math.min(420, (parent ? parent.width : 420))
    implicitHeight: 320

    // Reset to the first category and clear the search each time it opens, so it
    // never reopens mid-search from a previous session.
    onOpened: {
        searchField.text = ""
        tabs.currentIndex = 0
        searchField.forceActiveFocus()
    }

    background: Rectangle {
        color: Platform.surface
        radius: Platform.radius
        border.color: Platform.border
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: Platform.spacingSm

        // ── Search box ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Platform.spacingSm
            spacing: Platform.spacingSm

            Text {
                text: TenjinIcons.search
                font.family: TenjinIcons.family
                font.pixelSize: Platform.iconSize
                color: Platform.textMuted
            }
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search symbols\u2026  (e.g. \u201Csum\u201D, \u201Cvector\u201D)")
                placeholderTextColor: Platform.textMuted
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
                selectByMouse: true
                background: Rectangle {
                    color: Platform.surfaceAlt
                    radius: 4
                    border.color: searchField.activeFocus ? Platform.accent : Platform.border
                }
                Keys.onEscapePressed: {
                    if (text.length > 0) text = ""
                    else root.close()
                }
            }
            IconBtn {
                glyph: TenjinIcons.close
                onActivated: root.close()
            }
        }

        // ── Category tabs (hidden while searching) ────────────────────────
        TabBar {
            id: tabs
            Layout.fillWidth: true
            visible: searchField.text.length === 0
            background: Rectangle { color: "transparent" }

            Repeater {
                model: MathSymbols.categories
                delegate: TabButton {
                    id: tabBtn
                    required property var modelData
                    required property int index
                    text: modelData.name
                    width: Math.max(implicitWidth, 72)
                    contentItem: Text {
                        text: tabBtn.text
                        color: tabs.currentIndex === tabBtn.index
                               ? Platform.accent : Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: tabs.currentIndex === tabBtn.index
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: "transparent"
                        // Accent underline for the active tab.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: Platform.accent
                            visible: tabs.currentIndex === tabBtn.index
                        }
                    }
                }
            }
        }

        // ── Symbol grid ───────────────────────────────────────────────────
        // Shows either the search results or the active category's items.
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Platform.spacingSm
            clip: true
            cellWidth: 52
            cellHeight: 44

            model: {
                if (searchField.text.length > 0)
                    return MathSymbols.search(searchField.text)
                const cat = MathSymbols.categories[tabs.currentIndex]
                return cat ? cat.items : []
            }

            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: parent.height - 6
                    radius: Platform.radius - 2
                    color: cellArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: cellArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Keep the editor's caret/selection when clicking.
                        onPressed: (m) => m.accepted = true
                        onClicked: root.picked(modelData.snippet)
                        ToolTip.visible: containsMouse
                        ToolTip.text: modelData.snippet.replace("$1", "\u25AF")
                    }
                }
            }

            // Empty-search hint.
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: searchField.text.length > 0
                      ? qsTr("No symbols match \u201C%1\u201D").arg(searchField.text)
                      : ""
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
            }
        }
    }
}

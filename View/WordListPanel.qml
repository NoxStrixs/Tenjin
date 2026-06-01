pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// The scrollable list of all words for mobile. The header search field (Main.qml)
// drives appVM.wordVM.searchQuery, so the list filters inline; this panel re-reads
// getAllWords() whenever the list, query, or tag filters change. A horizontal row
// of tag chips below the header provides tag filtering.
Rectangle {
    id: listRoot
    color: Platform.bg

    signal wordActivated(int wordId)

    // getAllWords() already honours the active search query and tag filters.
    property var words: appVM.wordVM.getAllWords()
    property var allTags: appVM.wordVM.getAllTags()

    function refreshWords() { words = appVM.wordVM.getAllWords() }
    function refreshTags()  { allTags = appVM.wordVM.getAllTags() }

    Connections {
        target: appVM.wordVM
        function onWordListChanged()   { listRoot.refreshWords(); listRoot.refreshTags() }
        function onSearchQueryChanged() { listRoot.refreshWords() }
        function onTagFiltersChanged()  { listRoot.refreshWords() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Tag filter row ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: listRoot.allTags.length > 0
            implicitHeight: visible ? Platform.touchTarget + 8 : 0
            color: Platform.surface

            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border }

            Flickable {
                anchors.fill: parent
                anchors.leftMargin: Platform.pagePadding
                anchors.rightMargin: Platform.pagePadding
                contentWidth: chipRow.implicitWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        visible: appVM.wordVM.tagFilters.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearText.implicitWidth + 22
                        height: 30
                        radius: height / 2
                        color: clearArea.containsMouse ? Platform.danger : Platform.bg
                        border.color: Platform.danger
                        border.width: 1
                        Text { id: clearText; anchors.centerIn: parent; text: "Clear"; color: clearArea.containsMouse ? Platform.textOnDark : Platform.danger; font.pixelSize: Platform.fontBase - 2; font.bold: true }
                        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appVM.wordVM.clearTagFilters() }
                    }

                    Repeater {
                        model: listRoot.allTags
                        delegate: Rectangle {
                            id: filterChip
                            required property var modelData
                            // Touch tagFilters so this re-evaluates when filters change.
                            readonly property bool active: (appVM.wordVM.tagFilters, appVM.wordVM.isTagFiltered(modelData.id))
                            anchors.verticalCenter: parent.verticalCenter
                            width: chipLabel.implicitWidth + 22
                            height: 30
                            radius: height / 2
                            color: active ? Platform.accent : Platform.bg
                            border.color: active ? Platform.accent : Platform.border
                            border.width: 1
                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: filterChip.modelData.name
                                color: filterChip.active ? Platform.bg : Platform.accentDark
                                font.pixelSize: Platform.fontBase - 2
                                font.bold: filterChip.active
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (filterChip.active) appVM.wordVM.removeTagFilter(filterChip.modelData.id)
                                    else appVM.wordVM.addTagFilter(filterChip.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Word list ────────────────────────────────────────────────
        ListView {
            id: wordList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: listRoot.words

            delegate: ItemDelegate {
                id: row
                required property var modelData
                width: ListView.view.width
                implicitHeight: Platform.touchTarget + 8

                background: Rectangle {
                    color: row.hovered ? Platform.surfaceAlt : "transparent"
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border; opacity: 0.4 }
                }
                contentItem: Text {
                    text: row.modelData.word
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontLarge
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Platform.pagePadding
                    elide: Text.ElideRight
                }
                onClicked: listRoot.wordActivated(row.modelData.wordId)
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 48
                visible: wordList.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: appVM.wordVM.searchQuery.length > 0 || appVM.wordVM.tagFilters.length > 0
                      ? "No words match the current filter."
                      : "No words yet.\nTap + Word to add one."
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
            }
        }
    }
}

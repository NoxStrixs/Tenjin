pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// The scrollable list of all words for mobile. The header search field
// drives appVM.entryVM.searchQuery, so the list filters inline; this panel re-reads
// getAllEntries() whenever the list, query, or tag filters change. A horizontal row
// of tag chips below the header provides tag filtering.
Rectangle {
    id: listRoot
    color: Platform.bg

    signal wordActivated(int wordId)

    // getAllEntries() already honours the active search query and tag filters.
    property var words: appVM.entryVM.getAllEntries()
    property var allTags: appVM.entryVM.getAllTags()

    function refreshWords() { words = appVM.entryVM.getAllEntries() }
    function refreshTags()  { allTags = appVM.entryVM.getAllTags() }

    Connections {
        target: appVM.entryVM
        function onEntryListChanged()   { listRoot.refreshWords(); listRoot.refreshTags() }
        function onSearchQueryChanged() { listRoot.refreshWords() }
        function onTagFiltersChanged()  { listRoot.refreshWords() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tag filter — single trigger button that opens the shared
        // TagFilterPopup. Same component as the desktop sidebar; positions
        // here in the EntryListPanel header so mobile users get the same UX.
        Rectangle {
            Layout.fillWidth: true
            visible: listRoot.allTags.length > 0
            implicitHeight: visible ? Platform.touchTarget + Platform.spacingMd : 0
            color: Platform.surface

            // Bottom separator — mirrors the previous chip row's underline.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Platform.borderWidth
                color: Platform.border
            }

            TagFilterPopup {
                id: tagFilter
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Platform.pagePadding
                }
            }
        }

        // Word list
        ListView {
            id: entryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: listRoot.words
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: ItemDelegate {
                id: row
                required property var modelData
                width: ListView.view.width
                implicitHeight: Platform.touchTarget + 8

                background: Rectangle {
                    color: row.hovered ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border; opacity: 0.4 }
                }
                scale: row.pressed ? 0.99 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
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

            EmptyState {
                anchors.centerIn: parent
                width: parent.width
                visible: entryList.count === 0
                readonly property bool _filtered: appVM.entryVM.searchQuery.length > 0
                                                  || appVM.entryVM.tagFilters.length > 0
                icon: TenjinIcons.words
                title: _filtered ? qsTr("No matches") : qsTr("No words yet")
                subtitle: _filtered
                          ? qsTr("No words match the current filter. Try clearing it.")
                          : qsTr("Add your first word to start building your collection.")
                ctaText: _filtered ? "" : qsTr("+ Word")
                onCtaClicked: addEntryDialog.open()
            }
        }
    }
}




pragma ComponentBehavior: Bound

import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Router for the Words page.
//   Desktop — the word list lives in the always-visible Sidebar, so this page
//             shows either the selected word's detail or an empty-state hint.
//   Mobile  — a self-contained StackView: a searchable/tag-filterable list that
//             pushes to the full-screen detail editor on tap. Transitions are
//             driven reactively off selectedEntryId so the stack stays correct no
//             matter how selection changes (back, delete, or drawer nav).
Item {
    id: wordPageRoot

    // Desktop
    Loader {
        anchors.fill: parent
        active: !Platform.isMobile
        sourceComponent: appVM.entryVM.selectedEntryId >= 0 ? desktopDetail : emptyState
    }

    // Mobile
    Loader {
        anchors.fill: parent
        active: Platform.isMobile
        sourceComponent: mobileWords
    }

    Component {
        id: emptyState
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 12
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: TenjinIcons.words; font.family: TenjinIcons.family; font.pixelSize: Platform.iconSizeHero
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Select a word from the sidebar")
                    color: Platform.textMuted; font.pixelSize: Platform.fontLarge
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("or click + Word to add a new one")
                    color: Platform.textMuted; font.pixelSize: Platform.fontBase
                }
            }
        }
    }

    Component {
        id: desktopDetail
        EntryDetailView { showBack: false }
    }

    Component {
        id: mobileWords
        StackView {
            id: wordsNav
            initialItem: listComp

            // Selecting a word shows the detail, clearing returns to the list.
            property var detailItem: null

            Connections {
                target: appVM.entryVM
                function onSelectedEntryChanged() {
                    if (appVM.entryVM.selectedEntryId >= 0) {
                        if (wordsNav.currentItem !== wordsNav.detailItem)
                            wordsNav.push(detailComp)
                    } else {
                        if (wordsNav.depth > 1) wordsNav.pop(null)
                    }
                }
            }

            Component {
                id: listComp
                EntryListPanel {
                    onWordActivated: (wordId) => appVM.entryVM.selectEntry(wordId)
                }
            }

            Component {
                id: detailComp
                EntryDetailView {
                    showBack: true
                    Component.onCompleted: wordsNav.detailItem = this
                    onBackRequested: appVM.entryVM.clearSelection()
                }
            }
        }
    }
}




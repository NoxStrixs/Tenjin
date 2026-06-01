import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Item {
    StackLayout {
        anchors.fill: parent
        currentIndex: Platform.isMobile ? mobileStack.currentIndex : 0

        // Desktop: the Sidebar's Decks tab already lists and selects decks,
        // so the detail panel fills the whole page (no redundant DeckListPanel).
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: appVM.deckVM.selectedDeckId >= 0 ? deckDetailComp : noDeckComp
        }
    }

    QtObject {
        id: mobileStack
        property int currentIndex: 0
    }

    Loader {
        anchors.fill: parent
        active: Platform.isMobile
        sourceComponent: ColumnLayout {
            spacing: 0

            StackView {
                id: mobileNav
                Layout.fillWidth: true; Layout.fillHeight: true
                initialItem: mobileDeckList
            }

            Component {
                id: mobileDeckList
                Rectangle {
                    color: Platform.bg
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        DeckListPanel {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onDeckSelected: (id) => {
                                appVM.deckVM.selectDeck(id)
                                mobileNav.push(mobileDeckDetail)
                            }
                        }
                    }
                }
            }

            Component {
                id: mobileDeckDetail
                Rectangle {
                    color: Platform.bg
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Button {
                            Layout.fillWidth: true
                            implicitHeight: Platform.touchTarget
                            text: "‹ Decks"
                            font.pixelSize: Platform.fontBase
                            onClicked: mobileNav.pop()
                            background: Rectangle { color: Platform.surface }
                            contentItem: Text { text: parent.text; color: Platform.accentDark; font.pixelSize: parent.font.pixelSize; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }

                        Loader {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            sourceComponent: appVM.deckVM.selectedDeckId >= 0 ? deckDetailComp : noDeckComp
                        }
                    }
                }
            }
        }
    }

    Component {
        id: noDeckComp
        Item {
            Text { anchors.centerIn: parent; text: "Select or create a deck."; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
        }
    }

    Component {
        id: deckDetailComp
        DeckDetailPanel { anchors.fill: parent; reviewLoaderRef: reviewLoader }
    }

    Loader {
        id: reviewLoader
        active: false
        anchors.fill: parent; z: 10
        sourceComponent: ReviewPage { onSessionEnded: reviewLoader.active = false }
    }
}

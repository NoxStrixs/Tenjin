import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Rectangle {
    color: Platform.surface
    signal deckSelected(int deckId)

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        Text { text: "Decks"; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            model: appVM.deckVM.deckModel
            clip: true; spacing: 4

            delegate: ItemDelegate {
                width: ListView.view.width
                implicitHeight: Platform.touchTarget

                background: Rectangle {
                    color: appVM.deckVM.selectedDeckId === model.deckId ? Platform.surfaceAlt : "transparent"
                    radius: Platform.radius
                    border.color: appVM.deckVM.selectedDeckId === model.deckId ? Platform.border : "transparent"
                    border.width: 1
                }

                contentItem: RowLayout {
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: model.deckName; color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase; elide: Text.ElideRight
                    }
                    Text {
                        text: "✦"; color: Platform.accent
                        font.pixelSize: Platform.fontBase; visible: model.isSmart
                    }
                }

                onClicked: deckSelected(model.deckId)
            }
        }
    }
}

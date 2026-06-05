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
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: ItemDelegate {
                id: deckDel
                width: ListView.view.width
                implicitHeight: Platform.touchTarget

                readonly property bool _selected: appVM.deckVM.selectedDeckId === model.deckId

                background: Rectangle {
                    color: deckDel._selected ? Platform.surfaceAlt
                         : deckDel.hovered  ? Qt.rgba(Platform.surfaceAlt.r, Platform.surfaceAlt.g, Platform.surfaceAlt.b, 0.5)
                                             : "transparent"
                    radius: Platform.radius
                    border.color: deckDel._selected ? Platform.border : "transparent"
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: Platform.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                }

                scale: deckDel.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }

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


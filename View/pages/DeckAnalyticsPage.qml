import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import TenjinView

// Full-page deck analytics. Previously the AnalyticsPanel was toggled inline
// inside DeckDetailPanel, which squeezed charts into whatever width was left
// beside the deck list. As a page it gets the whole viewport, so the heatmap and
// charts are actually readable.
Item {
    id: analyticsRoot

    signal backRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header with back navigation + the deck this is reporting on.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + Platform.spacingLg
            color: Platform.surface

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Platform.spacingLg
                    rightMargin: Platform.spacingLg
                }
                spacing: Platform.spacingMd

                ActionButton {
                    text: TenjinIcons.chevronBack
                    font.family: TenjinIcons.family
                    variant: "neutral"
                    onClicked: analyticsRoot.backRequested()
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Back to decks")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: qsTr("Analytics")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: appVM.deckVM.selectedDeckName
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text.length > 0
                    }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Platform.border
            }
        }

        // The panel itself, now full width.
        AnalyticsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            deckId: appVM.deckVM.selectedDeckId
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: appVM.deckVM.selectedDeckId < 0
        icon: TenjinIcons.stats
        title: qsTr("No deck selected")
        subtitle: qsTr("Pick a deck to see its analytics.")
    }
}

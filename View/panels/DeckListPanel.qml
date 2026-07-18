import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

Rectangle {
    color: Platform.surface
    signal deckSelected(int deckId)

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: Platform.spacingMd

        Text { text: qsTr("Decks"); color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; font.bold: true }

        // Filter the deck list by the deck's language. Decks without a language
        // are hidden while a filter is active.
        StyledComboBox {
            Layout.fillWidth: true
            visible: appVM.availableLanguages.length > 0
            model: [qsTr("All languages")].concat(appVM.availableLanguages)
            onActivated: (idx) => {
                appVM.deckVM.deckLanguageFilter =
                    idx === 0 ? "" : appVM.availableLanguages[idx - 1]
            }
        }

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            model: appVM.deckVM.deckModel
            clip: true; spacing: Platform.spacingSm
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
                    Behavior on color        { ColorAnimation { duration: Platform.effDurationFast } }
                    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                }

                scale: deckDel.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }

                contentItem: RowLayout {
                    spacing: Platform.spacingMd
                    // Language flag badge — shown when the deck has a language.
                    LanguageFlagRow {
                        codes: LanguageFlags.flags(model.deckLanguage || "")
                        visible: (model.deckLanguage || "").length > 0
                    }
                    Text {
                        Layout.fillWidth: true
                        text: model.deckName; color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase; elide: Text.ElideRight
                    }
                    // Number of cards due for review now. Computed once per
                    // delegate load and refreshed when the deck list changes.
                    Rectangle {
                        id: dueBadge
                        property int dueCount: 0
                        visible: dueCount > 0
                        implicitWidth: Math.max(20, dueLabel.implicitWidth + 10)
                        implicitHeight: 20
                        radius: 10
                        color: Platform.accent
                        Text {
                            id: dueLabel
                            anchors.centerIn: parent
                            text: dueBadge.dueCount > 99 ? "99+" : dueBadge.dueCount
                            color: Platform.textOnDark
                            font.pixelSize: Platform.fontSmall
                            font.bold: true
                        }
                        function refresh() {
                            var st = appVM.deckVM.deckStats(model.deckId)
                            dueBadge.dueCount = (st && st.due !== undefined) ? st.due : 0
                        }
                        Component.onCompleted: refresh()
                        Connections {
                            target: appVM.deckVM.deckModel
                            function onModelReset() { dueBadge.refresh() }
                        }
                    }
                    Text {
                        text: TenjinIcons.autoAwesome
                        font.family: TenjinIcons.family
                        color: Platform.accent
                        font.pixelSize: Platform.fontBase; visible: model.isSmart
                    }
                }

                onClicked: deckSelected(model.deckId)
            }
        }
    }
}



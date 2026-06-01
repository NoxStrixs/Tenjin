import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Dialog {
    id: root
    title: "Create Deck"
    modal: true
    anchors.centerIn: parent
    width: Platform.isMobile ? Math.min(parent.width - 32, 340) : 320
    padding: 20
    standardButtons: Dialog.Ok | Dialog.Cancel

    background: Rectangle {
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
    }

    onAboutToShow: {
        deckNameInput.text = ""
        smartToggle.checked = false
        orToggle.checked = false
        root.allTags = appVM.wordVM.getAllTags()
        root.selectedTagIds = []
    }
    onAccepted: {
        const name = deckNameInput.text.trim()
        if (name.length === 0) return
        if (smartToggle.checked)
            appVM.deckVM.createSmartDeck(name, orToggle.checked ? 1 : 0, root.selectedTagIds)
        else
            appVM.deckVM.createDeck(name, false, orToggle.checked ? 1 : 0)
    }

    property var allTags: []
    property var selectedTagIds: []

    ColumnLayout {
        spacing: 12
        width: parent.width

        Text { text: "Name:"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }

        Rectangle {
            Layout.fillWidth: true
            height: Platform.touchTarget
            radius: Platform.radius
            color: Platform.surface
            border.color: deckNameInput.activeFocus ? Platform.accent : Platform.border
            border.width: deckNameInput.activeFocus ? 2 : 1

            TextField {
                id: deckNameInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                placeholderText: "e.g. JLPT N3"
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Smart deck (tag-based):"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
            Switch {
                id: smartToggle
                indicator: Rectangle {
                    implicitWidth: 40; implicitHeight: 22
                    x: smartToggle.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: height / 2
                    color: smartToggle.checked ? Platform.accent : Platform.surfaceAlt
                    border.color: smartToggle.checked ? Platform.accent : Platform.border
                    border.width: 1
                    Rectangle {
                        x: smartToggle.checked ? parent.width - width - 2 : 2
                        y: 2; width: 18; height: 18; radius: 9
                        color: Platform.bg
                        border.color: Platform.border
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: smartToggle.checked
            Text { Layout.fillWidth: true; text: "Match ANY tag (default: ALL):"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
            Switch {
                id: orToggle
                indicator: Rectangle {
                    implicitWidth: 40; implicitHeight: 22
                    x: orToggle.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: height / 2
                    color: orToggle.checked ? Platform.accent : Platform.surfaceAlt
                    border.color: orToggle.checked ? Platform.accent : Platform.border
                    border.width: 1
                    Rectangle {
                        x: orToggle.checked ? parent.width - width - 2 : 2
                        y: 2; width: 18; height: 18; radius: 9
                        color: Platform.bg
                        border.color: Platform.border
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }

        // Tag picker for smart decks — choose the tags to filter by at creation.
        Text {
            visible: smartToggle.checked
            text: "Filter by tags:"
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            font.bold: true
        }
        Rectangle {
            visible: smartToggle.checked
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(tagFlow.implicitHeight + 16, 160)
            radius: Platform.radius
            color: Platform.surface
            border.color: Platform.border
            border.width: 1

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: tagFlow.implicitHeight
                clip: true

                Flow {
                    id: tagFlow
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.allTags
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool picked: root.selectedTagIds.indexOf(modelData.id) !== -1
                            implicitWidth: tagChipText.implicitWidth + 20
                            implicitHeight: 26
                            radius: height / 2
                            color: picked ? Platform.accent : Platform.bg
                            border.color: picked ? Platform.accent : Platform.border
                            border.width: 1

                            Text {
                                id: tagChipText
                                anchors.centerIn: parent
                                text: modelData.name
                                color: parent.picked ? Platform.bg : Platform.accentDark
                                font.pixelSize: Platform.fontBase - 1
                                font.bold: parent.picked
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const ids = root.selectedTagIds.slice()
                                    const i = ids.indexOf(modelData.id)
                                    if (i === -1) ids.push(modelData.id)
                                    else ids.splice(i, 1)
                                    root.selectedTagIds = ids
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            visible: smartToggle.checked && root.allTags.length === 0
            text: "No tags yet — create some first."
            color: Platform.textMuted
            font.pixelSize: Platform.fontBase - 1
            font.italic: true
        }
    }
}

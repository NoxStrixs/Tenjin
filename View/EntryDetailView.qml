pragma ComponentBehavior: Bound

import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtQml.Models

// The full editor for a single word: title, action buttons, tags, the row/column
// content grid, and the add-content buttons. Extracted from EntryPage so both the
// desktop detail pane and the mobile list→detail stack render one definition.
//
//   showBack — when true (mobile), shows a "‹" button that emits backRequested()
//              so the host StackView can pop.
Item {
    id: detailRoot

    property bool showBack: false
    signal backRequested()

    clip: true

    ColumnLayout {
        anchors { fill: parent; margins: Platform.pagePadding }
        spacing: 16

        // ── Header: title + actions ──────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ActionButton {
                    visible: detailRoot.showBack
                    text: "\u2039"
                    variant: "neutral"
                    onClicked: detailRoot.backRequested()
                }

                Text {
                    text: appVM.entryVM.selectedWord
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                ActionButton {
                    visible: !appVM.entryVM.editMode
                    text: "Edit"
                    variant: "neutral"
                    onClicked: appVM.entryVM.beginEdit()
                }

                // Desktop: Save/Cancel/Delete inline with the title.
                Row {
                    visible: appVM.entryVM.editMode && !Platform.isMobile
                    spacing: 8
                    ActionButton { text: "Save";        variant: "success"; onClicked: appVM.entryVM.saveEdit() }
                    ActionButton { text: "Cancel";      variant: "neutral"; onClicked: appVM.entryVM.cancelEdit() }
                    ActionButton { text: "Delete Word"; variant: "danger";  onClicked: deleteEntryConfirm.open() }
                }
            }

            // Mobile edit actions — full-width second row.
            RowLayout {
                visible: appVM.entryVM.editMode && Platform.isMobile
                Layout.fillWidth: true
                spacing: 8
                ActionButton { Layout.fillWidth: true; text: "Save";   variant: "success"; onClicked: appVM.entryVM.saveEdit() }
                ActionButton { Layout.fillWidth: true; text: "Cancel"; variant: "neutral"; onClicked: appVM.entryVM.cancelEdit() }
                ActionButton { Layout.fillWidth: true; text: "Delete"; variant: "danger";  onClicked: deleteEntryConfirm.open() }
            }
        }

        // ── Tags ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: "Tags:"; color: Platform.textMuted; font.pixelSize: Platform.fontBase }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: appVM.entryVM.wordTags
                    delegate: TagChip {
                        required property var modelData
                        tagName: modelData.name
                        tagId: modelData.id
                        editable: appVM.entryVM.editMode
                        onRemoveClicked: (tid) => appVM.entryVM.detachTag(appVM.entryVM.selectedEntryId, tid)
                    }
                }

                // "+ tag" → popup to create-or-attach.
                Rectangle {
                    id: addTagButton
                    visible: appVM.entryVM.editMode
                    width: addTagText.implicitWidth + 24
                    height: Platform.isMobile ? 36 : 24
                    radius: height / 2
                    color: addTagArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        id: addTagText
                        anchors.centerIn: parent
                        text: "+ tag"
                        font.pixelSize: Platform.fontBase - 2
                        color: Platform.textMuted
                    }
                    MouseArea {
                        id: addTagArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tagPopup.allTags = appVM.entryVM.getAllTags()
                            newTagField.text = ""
                            tagPopup.open()
                            newTagField.forceActiveFocus()
                        }
                    }

                    Popup {
                        id: tagPopup
                        y: addTagButton.height + 4
                        width: 240
                        padding: 8
                        property var allTags: []

                        background: Rectangle {
                            color: Platform.surface
                            radius: Platform.radius
                            border.color: Platform.border
                            border.width: 1
                        }

                        contentItem: ColumnLayout {
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Platform.touchTarget
                                color: Platform.bg
                                radius: Platform.radius - 2
                                border.color: newTagField.activeFocus ? Platform.accent : Platform.border
                                border.width: newTagField.activeFocus ? 2 : 1

                                TextField {
                                    id: newTagField
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    placeholderText: "New tag name\u2026 (Enter)"
                                    placeholderTextColor: Platform.textMuted
                                    color: Platform.textPrimary
                                    font.pixelSize: Platform.fontBase
                                    background: null
                                    onAccepted: {
                                        if (text.trim().length > 0
                                            && appVM.entryVM.createAndAttachTag(text)) {
                                            text = ""
                                            tagPopup.close()
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }

                            Text {
                                visible: tagPopup.allTags.length > 0
                                text: "Existing tags"
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase - 3
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight, 200)
                                clip: true
                                model: tagPopup.allTags

                                delegate: ItemDelegate {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: Platform.touchTarget * 0.85
                                    background: Rectangle {
                                        color: hovered ? Platform.surfaceAlt : "transparent"
                                        radius: Platform.radius - 2
                                    }
                                    contentItem: Text {
                                        text: modelData.name ?? ""
                                        color: Platform.textPrimary
                                        font.pixelSize: Platform.fontBase
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 6
                                    }
                                    onClicked: {
                                        appVM.entryVM.attachTag(appVM.entryVM.selectedEntryId, modelData.id)
                                        tagPopup.close()
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: "No tags yet \u2014 type above to create one"
                                    color: Platform.textMuted
                                    font.pixelSize: Platform.fontBase - 2
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border }

        // ── Content blocks (row/column grid) ─────────────────────────
        GridContentView {
            id: blockGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            editMode: appVM.entryVM.editMode
        }

        // ── Add content buttons (wrap on narrow screens) ─────────────
        // Formula (type 4) is offered alongside the rest; it shows a text
        // fallback when offline rendering isn't compiled in.
        Flow {
            Layout.fillWidth: true
            visible: appVM.entryVM.editMode
            spacing: 8

            Repeater {
                model: [
                    { type: 0, label: "Definition" },
                    { type: 1, label: "Media Path" },
                    { type: 2, label: "Note" },
                    { type: 4, label: "Formula" },
                    { type: 3, label: "Divider" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    implicitHeight: Platform.touchTarget
                    implicitWidth: addLabel.implicitWidth + 24
                    radius: Platform.radius
                    color: addArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        id: addLabel
                        anchors.centerIn: parent
                        text: "+ " + parent.modelData.label
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                        color: addArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appVM.entryVM.addContentBlock(parent.modelData.type)
                    }
                }
            }
        }
    }

    ConfirmDialog {
        id: deleteEntryConfirm
        message: "Delete \"" + appVM.entryVM.selectedWord + "\"? This cannot be undone."
        onConfirmed: {
            appVM.entryVM.deleteEntry(appVM.entryVM.selectedEntryId)
            if (detailRoot.showBack) detailRoot.backRequested()
        }
    }
}



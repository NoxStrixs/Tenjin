pragma ComponentBehavior: Bound

import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtQml.Models

// The full editor for a single word: title, action buttons, tags, the row/column
// content grid, and the add-content buttons. Extracted from EntryPage so both the
// desktop detail pane and the mobile list-detail stack render one definition.
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

        // Header: title and actions
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

            // Mobile edit actions: full-width second row.
            RowLayout {
                visible: appVM.entryVM.editMode && Platform.isMobile
                Layout.fillWidth: true
                spacing: 8
                ActionButton { Layout.fillWidth: true; text: "Save";   variant: "success"; onClicked: appVM.entryVM.saveEdit() }
                ActionButton { Layout.fillWidth: true; text: "Cancel"; variant: "neutral"; onClicked: appVM.entryVM.cancelEdit() }
                ActionButton { Layout.fillWidth: true; text: "Delete"; variant: "danger";  onClicked: deleteEntryConfirm.open() }
            }
        }

        // Tags
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

                // "+ tag": popup to create-or-attach.
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

        // Content blocks
        GridContentView {
            id: blockGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            editMode: appVM.entryVM.editMode
        }

        // Add content buttons (wrap on narrow screens)
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
                        onClicked: {
                            appVM.entryVM.addContentBlock(parent.modelData.type)
                            // Scroll the block grid to the bottom so the new
                            // block is in view. callLater defers the read of
                            // contentHeight until after the model has been
                            // refreshed and GridContentView has relaid out
                            // — item #10 in the improvement plan.
                            Qt.callLater(function() {
                                if (blockGrid.contentHeight > blockGrid.height)
                                    blockGrid.contentY = blockGrid.contentHeight - blockGrid.height
                                else
                                    blockGrid.contentY = 0
                            })
                        }
                    }
                }
            }
        }

        // Related words section. Groups by kind so the page surfaces
        // Synonyms / Antonyms / Translations etc. separately. Always
        // visible (even when empty) so users discover the affordance; the
        // + Add Relation button is gated to edit mode like the other
        // structural editors above.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Platform.border
            visible: appVM.entryVM.selectedEntryId > 0
        }

        ColumnLayout {
            id: relationsLayout
            Layout.fillWidth: true
            visible: appVM.entryVM.selectedEntryId > 0
            spacing: 10

            // _grouped is rebuilt whenever selectedEntryRelations changes,
            // yielding { synonym: [...], antonym: [...], ... }. The
            // canonical order matches AddRelationDialog._kinds so the
            // page is stable across sessions.
            readonly property var _relations: appVM.entryVM.selectedEntryRelations
            readonly property var _kindOrder: [
                { id: "synonym",     label: "Synonyms"     },
                { id: "antonym",     label: "Antonyms"     },
                { id: "related",     label: "Related"      },
                { id: "translation", label: "Translations" },
                { id: "inflection",  label: "Inflections"  }
            ]

            function _groupedRelations() {
                const groups = { synonym: [], antonym: [], related: [], translation: [], inflection: [] }
                for (let i = 0; i < _relations.length; i++) {
                    const r = _relations[i]
                    if (groups[r.kind] !== undefined) groups[r.kind].push(r)
                    else (groups.related = groups.related).push(r)  // unknown kind → "Related"
                }
                return groups
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Related words"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontLarge
                    font.bold: true
                }
                Rectangle {
                    visible: appVM.entryVM.editMode
                    implicitHeight: Platform.touchTarget * 0.85
                    implicitWidth: addRelLbl.implicitWidth + 22
                    radius: Platform.radius
                    color: addRelArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text {
                        id: addRelLbl
                        anchors.centerIn: parent
                        text: "+ Add relation"
                        color: addRelArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    }
                    MouseArea {
                        id: addRelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            addRelationDialog.sourceEntryId = appVM.entryVM.selectedEntryId
                            addRelationDialog.open()
                        }
                    }
                }
            }

            // Empty state.
            Text {
                visible: relationsLayout._relations.length === 0
                Layout.fillWidth: true
                text: appVM.entryVM.editMode
                      ? "No related words yet. Tap + Add relation to link a synonym, antonym, translation, or inflection."
                      : "No related words yet."
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                wrapMode: Text.WordWrap
            }

            // One ColumnLayout per kind group. Repeater materialises only
            // the groups that have entries — empty groups are hidden.
            Repeater {
                model: relationsLayout._kindOrder
                delegate: ColumnLayout {
                    id: kindGroupDelegate
                    required property var modelData
                    Layout.fillWidth: true

                    readonly property var _entries: {
                        const g = relationsLayout._groupedRelations()
                        return g[modelData.id] || []
                    }
                    visible: _entries.length > 0
                    spacing: 4

                    Text {
                        text: modelData.label + " · " + kindGroupDelegate._entries.length
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: kindGroupDelegate._entries
                            delegate: Rectangle {
                                required property var modelData
                                implicitHeight: Platform.chipHeight
                                implicitWidth: row.implicitWidth + 18
                                radius: Platform.chipRadius
                                color: chipHover.containsMouse ? Platform.surfaceAlt : Platform.surface
                                border.color: Platform.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                                Row {
                                    id: row
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.word.length > 0
                                              ? modelData.word
                                              : "(deleted)"
                                        color: modelData.word.length > 0
                                               ? Platform.textPrimary
                                               : Platform.textMuted
                                        font.pixelSize: Platform.fontSmall
                                        font.italic: modelData.word.length === 0
                                    }
                                    Text {
                                        visible: appVM.entryVM.editMode
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\u2715"
                                        color: removeArea.containsMouse ? Platform.danger : Platform.textMuted
                                        font.pixelSize: Platform.fontSmall
                                        font.bold: true
                                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                                        MouseArea {
                                            id: removeArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: appVM.entryVM.removeRelation(modelData.id)
                                        }
                                    }
                                }
                                MouseArea {
                                    id: chipHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: modelData.relatedId > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    // Tap the chip (not the ×) to open the related entry.
                                    onClicked: if (modelData.relatedId > 0)
                                                   appVM.entryVM.selectEntry(modelData.relatedId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // AddRelationDialog is hosted here so it can read selectedEntryId at
    // open time. Kept inside the EntryDetailView scope rather than at
    // Main.qml because nothing outside this view opens it.
    AddRelationDialog { id: addRelationDialog }

    ConfirmDialog {
        id: deleteEntryConfirm
        message: "Delete \"" + appVM.entryVM.selectedWord + "\"? This cannot be undone."
        onConfirmed: {
            appVM.entryVM.deleteEntry(appVM.entryVM.selectedEntryId)
            if (detailRoot.showBack) detailRoot.backRequested()
        }
    }
}

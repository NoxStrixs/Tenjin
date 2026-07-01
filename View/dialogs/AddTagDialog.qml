import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Create-or-find tag dialog.
//
// As the user types, matching existing tags are shown below the input so
// they don't accidentally create a duplicate. Tapping a match closes the
// dialog and emits `tagSelected(id)`; hitting Enter (or the Create button)
// on a non-matching name creates a new tag and emits `tagCreated(id)`.
// Callers can wire either signal or just rely on the existing
// `appVM.entryVM.createTag(name)` side effect.
//
// Explicitly centered so it doesn't land on top of where RenameTagDialog
// last positioned itself.
ThemedDialog {
    id: root
    title: qsTr("Add tag")
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 340, 380) : 360
    padding: 20

    // Force centering regardless of how a previous dialog left
    // Overlay.overlay positioned. parent is set to Overlay.overlay by
    // Dialog at open time on the desktop runtime; the binding stays valid
    // afterwards.
    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    signal tagCreated(int tagId)
    signal tagSelected(int tagId)

    property var _allTags: []
    property string _query: ""

    function _refresh() { _allTags = appVM.entryVM.getAllTags() }
    function _matches() {
        const q = _query.toLowerCase().trim()
        if (q.length === 0) return []
        const out = []
        for (let i = 0; i < _allTags.length; i++) {
            const n = _allTags[i].name
            if (n && n.toLowerCase().indexOf(q) !== -1) out.push(_allTags[i])
            if (out.length >= 8) break
        }
        return out
    }
    function _exactMatch() {
        const q = _query.toLowerCase().trim()
        if (q.length === 0) return null
        for (let i = 0; i < _allTags.length; i++) {
            if (_allTags[i].name && _allTags[i].name.toLowerCase() === q) return _allTags[i]
        }
        return null
    }

    onAboutToShow: {
        tagNameInput.text = ""
        _query = ""
        _refresh()
        tagNameInput.forceActiveFocus()
    }

    // Override accept so Enter behaves "select if exact match exists, else
    // create". The standard `onAccepted` runs after this, but emits no-op
    // create when text is empty.
    onAccepted: {
        const name = tagNameInput.text.trim()
        if (name.length === 0) return
        const m = root._exactMatch()
        if (m) {
            tagSelected(m.id)
        } else {
            const newId = appVM.entryVM.createTag(name)
            if (newId !== undefined && newId >= 0) tagCreated(newId)
        }
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Text {
            text: qsTr("Name")
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: Platform.touchTarget
            radius: Platform.radius
            color: Platform.surface
            border.color: tagNameInput.activeFocus ? Platform.accent : Platform.border
            border.width: tagNameInput.activeFocus ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
            Behavior on border.width { NumberAnimation { duration: Platform.effDurationFast } }

            TextField {
                id: tagNameInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                placeholderText: qsTr("e.g. verb, JLPT N3, chapter 1")
                placeholderTextColor: Platform.textMuted
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                onTextChanged: root._query = text
                Keys.onReturnPressed: root.accept()
            }
        }

        // Existing-match hint. Tells the user when the typed name already
        // exists so they don't create a duplicate. The visible match list
        // below is the actionable form — this row is just a status line.
        Text {
            Layout.fillWidth: true
            visible: root._query.length > 0
            text: root._exactMatch()
                  ? "\u2713 \"" + root._exactMatch().name + "\" already exists — tap below to use it"
                  : ("Press Enter to create \"" + tagNameInput.text.trim() + "\"")
            color: root._exactMatch() ? Platform.success : Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }

        // Matching existing tags. Shown only while the user is typing
        // something. Tapping a row picks that existing tag and closes the
        // dialog — saves the create-a-duplicate trip.
        Rectangle {
            Layout.fillWidth: true
            visible: root._query.length > 0 && matchList.count > 0
            Layout.preferredHeight: Math.min(matchList.contentHeight + 8, 220)
            radius: Platform.radius
            color: Platform.bg
            border.color: Platform.border
            border.width: 1

            ListView {
                id: matchList
                anchors { fill: parent; margins: 4 }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // _matches() recomputes whenever _query or _allTags change.
                property var _trigger: root._query
                property var _allTrigger: root._allTags
                model: root._matches()
                on_TriggerChanged: model = root._matches()
                on_AllTriggerChanged: model = root._matches()

                delegate: Rectangle {
                    required property var modelData
                    width: matchList.width
                    height: Platform.touchTarget * 0.85
                    radius: Platform.radius - 2
                    color: matchHover.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Text {
                            text: TenjinIcons.tags
                            font.family: TenjinIcons.family
                            font.pixelSize: Platform.fontBase
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.parent.modelData.name
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            elide: Text.ElideRight
                        }
                        Text {
                            text: qsTr("Use")
                            color: Platform.accentDark
                            font.pixelSize: Platform.fontSmall
                            font.bold: true
                            visible: matchHover.containsMouse
                        }
                    }
                    MouseArea {
                        id: matchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.tagSelected(parent.modelData.id)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}



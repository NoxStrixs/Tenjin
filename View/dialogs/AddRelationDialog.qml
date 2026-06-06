import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// "Add relation" dialog. Two-step picker: search for the related word,
// then pick the relation kind from the five canonical options
// (Synonym / Antonym / Related / Translation / Inflection).
//
// On accept, calls appVM.entryVM.addRelation(entryId, relatedId, kind).
// The dialog is one-shot per opening; reopen to add another relation.
ThemedDialog {
    id: root
    title: "Add related word"
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 420, 460) : 420
    padding: 20

    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    // The entry we're adding a relation FROM. Set by the caller before open().
    property int sourceEntryId: -1

    // Picked state.
    property int    pickedId:   -1
    property string pickedWord: ""
    property string pickedKind: "synonym"

    property var _allEntries: []
    property string _query: ""

    function _refresh() { _allEntries = appVM.entryVM.getAllEntries() }
    function _matches() {
        const q = _query.toLowerCase().trim()
        if (q.length === 0) return []
        const out = []
        for (let i = 0; i < _allEntries.length; i++) {
            const e = _allEntries[i]
            // Skip the source entry itself — a word can't relate to itself.
            if (e.wordId === sourceEntryId) continue
            if (e.word && e.word.toLowerCase().indexOf(q) !== -1) out.push(e)
            if (out.length >= 12) break
        }
        return out
    }

    onAboutToShow: {
        _refresh()
        wordSearch.text = ""
        _query = ""
        pickedId = -1
        pickedWord = ""
        pickedKind = "synonym"
        wordSearch.forceActiveFocus()
    }

    onAccepted: {
        if (sourceEntryId < 0 || pickedId < 0) return
        appVM.entryVM.addRelation(sourceEntryId, pickedId, pickedKind)
    }

    // Five canonical kinds. Keep names lowercase so the DB has a single
    // canonical form even if QML labels are capitalised.
    readonly property var _kinds: [
        { id: "synonym",     label: "Synonym",     hint: "Means roughly the same thing"   },
        { id: "antonym",     label: "Antonym",     hint: "Means the opposite"             },
        { id: "related",     label: "Related",     hint: "Topically connected"            },
        { id: "translation", label: "Translation", hint: "Same meaning, other language"   },
        { id: "inflection",  label: "Inflection",  hint: "Conjugation or form variant"    }
    ]

    ColumnLayout {
        spacing: 14
        width: parent.width

        // Step 1 — pick the related word.
        Text {
            text: root.pickedId >= 0
                  ? "Related word — \"" + root.pickedWord + "\""
                  : "Related word"
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget
            radius: Platform.radius
            color: Platform.bg
            border.color: wordSearch.activeFocus ? Platform.accent : Platform.border
            border.width: wordSearch.activeFocus ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
            Behavior on border.width { NumberAnimation { duration: Platform.durationFast } }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 6
                Text { text: "\u2315"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                TextField {
                    id: wordSearch
                    Layout.fillWidth: true
                    placeholderText: "Search words\u2026"
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    background: Rectangle { color: "transparent" }
                    onTextChanged: {
                        root._query = text
                        // Clear pick when query changes — user starts over.
                        root.pickedId = -1
                        root.pickedWord = ""
                    }
                }
            }
        }

        // Match list.
        Rectangle {
            Layout.fillWidth: true
            visible: root._query.length > 0 && root.pickedId < 0
            Layout.preferredHeight: Math.min(matchList.contentHeight + 8, 200)
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

                property var _trigger: root._query
                property var _entriesTrigger: root._allEntries
                model: root._matches()
                on_TriggerChanged: model = root._matches()
                on_EntriesTriggerChanged: model = root._matches()

                delegate: Rectangle {
                    required property var modelData
                    width: matchList.width
                    height: Platform.touchTarget * 0.85
                    radius: Platform.radius - 2
                    color: matchHover.containsMouse ? Platform.surfaceAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                    Text {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: Text.AlignVCenter
                        text: parent.modelData.word
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: matchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pickedId = parent.modelData.wordId
                            root.pickedWord = parent.modelData.word
                        }
                    }
                }
            }
        }

        // Step 2 — kind chips. Visible only once a word is picked.
        Text {
            visible: root.pickedId >= 0
            text: "Relation kind"
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            font.bold: true
        }

        Flow {
            Layout.fillWidth: true
            visible: root.pickedId >= 0
            spacing: 8

            Repeater {
                model: root._kinds
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool _active: root.pickedKind === modelData.id
                    implicitHeight: Platform.touchTarget * 0.85
                    implicitWidth: kindLbl.implicitWidth + 22
                    radius: Platform.radius
                    color: _active ? Platform.accent : kindArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: _active ? Platform.accent : Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                    Text {
                        id: kindLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent._active ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontSmall
                        font.bold: parent._active
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    }
                    MouseArea {
                        id: kindArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickedKind = parent.modelData.id
                    }
                }
            }
        }

        Text {
            visible: root.pickedId >= 0
            Layout.fillWidth: true
            text: {
                for (let i = 0; i < root._kinds.length; i++)
                    if (root._kinds[i].id === root.pickedKind) return root._kinds[i].hint
                return ""
            }
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
            font.italic: true
            wrapMode: Text.WordWrap
        }
    }

    // Override the default OK button label / behaviour so it's clearly
    // disabled until a pick is made. (ThemedDialog drives standard
    // buttons; we just hint state through whatever it exposes.)
    standardButtons: root.pickedId >= 0 ? (Dialog.Ok | Dialog.Cancel) : Dialog.Cancel
}


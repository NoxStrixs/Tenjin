pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Universal search field — searches words, tags AND decks. Tapping a result
// navigates to the appropriate page:
//
//   word  → Words page (currentPage = 0), entry selected
//   tag   → Tags page  (currentPage = 2), tag highlighted via appVM.highlightedTagId
//   deck  → Decks page (currentPage = 1), deck selected
//
// Words and tags come from appVM.entryVM.searchResults (which already
// covers both kinds with a `kind` discriminator). Decks aren't in that
// list, so we materialize the deck model into a JS array via a hidden
// Repeater and filter that array by the query string. The materialized
// list rebuilds whenever the deck model's row count changes.
Item {
    id: root

    // Public: focus the text field (called by Ctrl/Cmd+F shortcut).
    function focusSearch() { searchField.forceActiveFocus() }
    implicitHeight: Platform.touchTarget
    Layout.preferredWidth: Platform.isMobile ? -1 : Math.min(280, parentWidth * 0.32)
    Layout.fillWidth: Platform.isMobile
    Layout.minimumWidth: 120
    Layout.preferredHeight: Platform.touchTarget

    // Provided by parent so width can scale with the window.
    property real parentWidth: 800

    // When false, the live results popup is suppressed.
    property bool dropdownEnabled: true

    // Keep the field in sync with the VM query across page switches.
    property string queryText: appVM.entryVM.searchQuery

    // Materialized decks (rebuilt whenever the deck model count changes).
    property var _allDecks: []

    // Combined results: words + tags from entryVM + decks filtered locally.
    property var combinedResults: []

    function _rebuildDeckCache() {
        const arr = []
        for (let i = 0; i < deckMaterializer.count; i++) {
            const inst = deckMaterializer.itemAt(i)
            if (inst) arr.push({ id: inst.deckId, name: inst.deckName, isSmart: inst.isSmart })
        }
        _allDecks = arr
        _updateCombined()
    }

    function _deckMatches() {
        const q = searchField.text.toLowerCase().trim()
        if (q.length === 0) return []
        const out = []
        for (let i = 0; i < _allDecks.length; i++) {
            const d = _allDecks[i]
            if (d.name && d.name.toLowerCase().indexOf(q) !== -1) {
                out.push({
                    kind: "deck",
                    id: d.id,
                    label: d.name,
                    snippet: d.isSmart ? "Smart deck" : ""
                })
            }
        }
        return out
    }

    function _updateCombined() {
        const base = appVM.entryVM.searchResults || []
        const decks = _deckMatches()
        // Concatenate without mutating the source array.
        const merged = []
        for (let i = 0; i < base.length; i++) merged.push(base[i])
        for (let i = 0; i < decks.length; i++) merged.push(decks[i])
        combinedResults = merged
    }

    Connections {
        target: appVM.entryVM
        function onSearchResultsChanged() { root._updateCombined() }
    }
    Component.onCompleted: { _rebuildDeckCache(); _updateCombined() }

    // Hidden materializer — pulls role data out of deckModel into JS objects.
    // Repeater requires an Item-derived delegate (QtObject is rejected at
    // runtime with "Delegate must be of Item type"), so we use a sized-zero
    // Item that's never laid out and never painted. The Repeater itself
    // watches the model's row signals — when decks are added or removed
    // its count changes and _rebuildDeckCache picks up the new shape.
    Repeater {
        id: deckMaterializer
        model: appVM.deckVM.deckModel
        delegate: Item {
            required property int deckId
            required property string deckName
            required property bool isSmart
            visible: false
            width: 0
            height: 0
        }
        onCountChanged: root._rebuildDeckCache()
    }

    Rectangle {
        id: field
        anchors.fill: parent
        color: Platform.bg
        radius: Platform.radius
        border.color: searchField.activeFocus ? Platform.accent : Platform.border
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
            spacing: 6

            Text { text: TenjinIcons.search; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }

            TextField {
                id: searchField
                Layout.fillWidth: true
                text: root.queryText
                placeholderText: qsTr("Search words, tags, decks\u2026")
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                leftPadding: 0
                onTextChanged: {
                    appVM.entryVM.searchQuery = text
                    root._updateCombined()
                    // Only OUR text field gets to surface the dropdown.
                    // Without this, both desktop and mobile SearchBoxes (one
                    // hidden by RowLayout.visible) would open their popups
                    // simultaneously: when the focused field writes to
                    // appVM.entryVM.searchQuery, the queryText binding
                    // round-trips into the hidden field's TextField.text,
                    // re-fires onTextChanged there, and pops its dropdown.
                    if (searchField.activeFocus
                        && root.dropdownEnabled
                        && text.length > 0) dropdown.open()
                    else dropdown.close()
                }
                onActiveFocusChanged: if (!activeFocus) dropdown.close()
                Keys.onEscapePressed: { text = ""; dropdown.close() }
            }

            // Clear button
            Text {
                visible: searchField.text.length > 0
                text: TenjinIcons.close
                font.family: TenjinIcons.family
                color: clearArea.containsMouse ? Platform.textPrimary : Platform.textMuted
                font.pixelSize: Platform.fontBase
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchField.text = ""; dropdown.close() }
                }
            }

            // Content-search toggle (only meaningful for word matches).
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Platform.isMobile ? 34 : 26
                implicitHeight: Platform.isMobile ? 34 : 26
                radius: Platform.radius - 1
                color: appVM.entryVM.searchInContent ? Platform.accent : Platform.surfaceAlt
                border.color: appVM.entryVM.searchInContent ? Platform.accent : Platform.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Text {
                    anchors.centerIn: parent
                    text: TenjinIcons.menu
                font.family: TenjinIcons.family
                    font.pixelSize: Platform.fontBase
                    font.weight: Font.Normal
                    color: appVM.entryVM.searchInContent ? Platform.textOnDark : Platform.textMuted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.entryVM.searchInContent = !appVM.entryVM.searchInContent
                    ToolTip.visible: pressed
                    ToolTip.text: qsTr("Also search content blocks")
                }
            }
        }
    }

    Popup {
        id: dropdown
        y: field.height + 4
        width: field.width
        padding: 6
        closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

        background: Rectangle {
            color: Platform.surface
            radius: Platform.radius
            border.color: Platform.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 4

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 320)
                clip: true
                model: root.combinedResults
                interactive: true

                delegate: ItemDelegate {
                    id: resultRow
                    required property var modelData
                    width: ListView.view.width
                    height: (modelData.kind === "word" && (modelData.snippet ?? "").length > 0)
                            ? Platform.touchTarget * 1.5 : Platform.touchTarget

                    background: Rectangle {
                        color: resultRow.hovered ? Platform.surfaceAlt : "transparent"
                        radius: Platform.radius - 2
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        // Kind badge — three colors so word / tag / deck stay distinct.
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4
                            implicitWidth: kindText.implicitWidth + 12
                            implicitHeight: 18
                            radius: height / 2
                            color: resultRow.modelData.kind === "tag"  ? Platform.accentDark
                                 : resultRow.modelData.kind === "deck" ? Platform.accent
                                                                        : Platform.surfaceAlt
                            border.color: Platform.border
                            border.width: 1
                            Text {
                                id: kindText
                                anchors.centerIn: parent
                                text: resultRow.modelData.kind
                                color: resultRow.modelData.kind === "word" ? Platform.accentDark
                                                                            : Platform.textOnDark
                                font.pixelSize: Platform.fontBase - 4
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: resultRow.modelData.label
                                color: Platform.textPrimary
                                font.pixelSize: Platform.fontBase
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: (resultRow.modelData.snippet ?? "").length > 0
                                text: resultRow.modelData.snippet ?? ""
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase - 3
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                    onClicked: {
                        if (resultRow.modelData.kind === "tag") {
                            // Tag → Tags page; flag the id so TagsPage can
                            // briefly highlight / scroll to the matching chip.
                            appVM.setHighlightedTagId(resultRow.modelData.id)
                            appVM.currentPage = 2
                        } else if (resultRow.modelData.kind === "deck") {
                            // Deck → Decks page; select the matching deck.
                            // selectedDeckId is READ-only on DeckViewModel;
                            // selectDeck() is the canonical setter.
                            appVM.deckVM.selectDeck(resultRow.modelData.id)
                            appVM.currentPage = 1
                        } else {
                            // Word → Words page; select the matching entry.
                            appVM.entryVM.selectEntry(resultRow.modelData.id)
                            appVM.currentPage = 0
                        }
                        searchField.text = ""
                        dropdown.close()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: qsTr("No matches")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                }
            }
        }
    }
}



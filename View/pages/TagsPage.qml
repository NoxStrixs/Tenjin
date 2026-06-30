pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Canonical tag UI. Lists every tag with rename, delete, and word-count
// badge; tapping a tag jumps to Words filtered by that tag. Reached from
// the header / mobile drawer / universal search.
//
// Universal search uses appVM.highlightedTagId to ask this page to scroll
// to and briefly pulse the matching chip; the highlight clears after a
// short timer, and we write -1 back so a second navigation to the same
// tag pulses again.
Item {
    id: tagsPageRoot

    // Re-emitted by Main.qml's instantiation onto the addTagDialog.
    signal addTagRequested()

    // Asks Main.qml to navigate back to Words. Wired in Main.qml's
    // StackLayout host onto appVM.currentPage = _pageWords.
    signal backRequested()

    property var allTags: appVM.entryVM.getAllTags()
    function refresh() { allTags = appVM.entryVM.getAllTags() }

    // Filter text typed into the search input above the list.
    property string filterText: ""

    // ID currently being pulsed (-1 = none).
    property int _pulsingTagId: -1

    function _filteredTags() {
        const q = filterText.toLowerCase().trim()
        if (q.length === 0) return allTags
        const out = []
        for (let i = 0; i < allTags.length; i++) {
            if (allTags[i].name && allTags[i].name.toLowerCase().indexOf(q) !== -1)
                out.push(allTags[i])
        }
        return out
    }

    Connections {
        target: appVM.entryVM
        function onEntryListChanged() { tagsPageRoot.refresh() }
    }

    // Universal-search → "scroll to + pulse the matching chip" handshake.
    Connections {
        target: appVM
        function onHighlightedTagIdChanged() {
            const id = appVM.highlightedTagId
            if (id < 0) return
            // Clear the filter so the matched tag is reachable even if a
            // prior filter string was hiding it.
            tagsPageRoot.filterText = ""
            filterInput.text = ""
            const items = tagsPageRoot.allTags
            for (let i = 0; i < items.length; i++) {
                if (items[i].id === id) {
                    tagList.positionViewAtIndex(i, ListView.Center)
                    tagsPageRoot._pulsingTagId = id
                    pulseClearTimer.restart()
                    appVM.setHighlightedTagId(-1)
                    return
                }
            }
        }
    }
    Timer {
        id: pulseClearTimer
        interval: 2200
        onTriggered: tagsPageRoot._pulsingTagId = -1
    }
    // Catch the case where the search request arrived before the page was
    // composed — re-process whatever's currently in highlightedTagId.
    Component.onCompleted: {
        const id = appVM.highlightedTagId
        if (id >= 0) {
            for (let i = 0; i < allTags.length; i++) {
                if (allTags[i].id === id) {
                    tagList.positionViewAtIndex(i, ListView.Center)
                    _pulsingTagId = id
                    pulseClearTimer.restart()
                    appVM.setHighlightedTagId(-1)
                    return
                }
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Platform.pagePadding }
        spacing: 12

        // Title row: back button, page title, + Tag button.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Back to Words. The "<" character is more reliable in monospace
            // / desktop fonts than the "\u2039" glyph this app uses elsewhere,
            // but both render fine; pick the one that matches the rest of
            // the app's chevrons.
            Rectangle {
                Layout.preferredWidth: Platform.touchTarget
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: tagsBackArea.containsMouse ? Platform.surfaceAlt : "transparent"
                border.color: Platform.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Text {
                    anchors.centerIn: parent
                    text: TenjinIcons.chevronLeft
                    font.family: TenjinIcons.family
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.weight: Font.Normal
                }
                MouseArea {
                    id: tagsBackArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tagsPageRoot.backRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Tags")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }
            Rectangle {
                Layout.preferredHeight: Platform.touchTarget
                Layout.preferredWidth: addTagLabel.implicitWidth + 28
                radius: Platform.radius
                color: addTagArea.containsMouse ? Platform.accentDark : Platform.accent
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                scale: addTagArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                Text { id: addTagLabel; anchors.centerIn: parent; text: qsTr("+ Tag"); color: Platform.bg; font.pixelSize: Platform.fontBase; font.bold: true }
                MouseArea {
                    id: addTagArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tagsPageRoot.addTagRequested()
                }
            }
        }

        // Inline filter — replaces what the sidebar tag-mode used to offer.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget
            color: Platform.bg
            radius: Platform.radius
            border.color: filterInput.activeFocus ? Platform.accent : Platform.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                spacing: 6
                Text { text: TenjinIcons.search; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                TextField {
                    id: filterInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Filter tags\u2026")
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    background: Rectangle { color: "transparent" }
                    leftPadding: 0
                    onTextChanged: tagsPageRoot.filterText = text
                }
                Text {
                    visible: filterInput.text.length > 0
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
                        onClicked: filterInput.text = ""
                    }
                }
            }
        }

        // Tag list.
        ListView {
            id: tagList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: tagsPageRoot._filteredTags()
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            // _filteredTags is a JS-derived array; rebind on the inputs.
            property var _filterTrigger: tagsPageRoot.filterText
            property var _allTagsTrigger: tagsPageRoot.allTags
            on_FilterTriggerChanged: model = tagsPageRoot._filteredTags()
            on_AllTagsTriggerChanged: model = tagsPageRoot._filteredTags()

            delegate: Rectangle {
                id: tagRow
                required property var modelData
                width: ListView.view.width
                implicitHeight: Platform.touchTarget + 16
                radius: Platform.radiusLarge

                readonly property bool _pulsing: tagsPageRoot._pulsingTagId === modelData.id

                color: rowHover.hovered ? Platform.surfaceAlt : Platform.surface
                border.color: _pulsing ? Platform.accent
                            : rowHover.hovered ? Platform.accent
                                                 : Platform.border
                border.width: _pulsing ? 2 : 1

                Behavior on color        { ColorAnimation { duration: Platform.effDurationFast } }
                Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                Behavior on border.width { NumberAnimation { duration: Platform.effDurationFast } }

                // Subtle hover lift on desktop.
                transform: Translate {
                    y: rowHover.hovered ? -1 : 0
                    Behavior on y { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                }
                HoverHandler { id: rowHover }

                // Pulsing scale — kicks in for ~2 s after a search nav.
                SequentialAnimation on scale {
                    running: tagRow._pulsing
                    loops: 3
                    NumberAnimation { from: 1.0; to: 1.03; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { from: 1.03; to: 1.0; duration: 200; easing.type: Easing.InCubic }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                    spacing: 10

                    // Tag glyph
                    Text {
                        text: TenjinIcons.tags
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontLarge
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: tagRow.modelData.name
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontLarge
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: (tagRow.modelData.wordCount ?? -1) >= 0
                            text: (tagRow.modelData.wordCount === 1)
                                  ? "1 word"
                                  : (tagRow.modelData.wordCount + " words")
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                        }
                    }

                    // Word-count chip — shown even when wordCount role isn't
                    // populated, falls back to a "view" arrow only.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: viewLabel.implicitWidth + 18
                        implicitHeight: Platform.touchTarget * 0.85
                        radius: Platform.radius
                        color: viewArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        border.color: Platform.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        Text { id: viewLabel; anchors.centerIn: parent; text: qsTr("View"); color: Platform.accentDark; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                        MouseArea {
                            id: viewArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appVM.entryVM.filterByTag(tagRow.modelData.id, tagRow.modelData.name)
                                appVM.currentPage = 0
                            }
                        }
                    }

                    // Rename
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: renameLabel.implicitWidth + 18
                        implicitHeight: Platform.touchTarget * 0.85
                        radius: Platform.radius
                        color: renameArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        border.color: Platform.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        Text { id: renameLabel; anchors.centerIn: parent; text: qsTr("Rename"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase - 1 }
                        MouseArea {
                            id: renameArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: renameTagDialog.openFor(tagRow.modelData.id, tagRow.modelData.name)
                        }
                    }

                    // Delete
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: delLabel.implicitWidth + 18
                        implicitHeight: Platform.touchTarget * 0.85
                        radius: Platform.radius
                        color: delArea.containsMouse ? Platform.danger : "transparent"
                        border.color: Platform.danger
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                        Text {
                            id: delLabel
                            anchors.centerIn: parent
                            text: qsTr("Delete")
                            color: delArea.containsMouse ? Platform.textOnDark : Platform.danger
                            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                            font.pixelSize: Platform.fontBase - 1
                            font.bold: true
                        }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagsPageRoot._openTagDeleteConfirm(tagRow.modelData.id, tagRow.modelData.name)
                        }
                    }
                }
            }

            // Empty state
            EmptyState {
                anchors.centerIn: parent
                width: parent.width
                visible: tagList.count === 0
                readonly property bool _filtered: tagsPageRoot.filterText.length > 0
                icon: TenjinIcons.tags
                title: _filtered ? qsTr("No matches") : qsTr("No tags yet")
                subtitle: _filtered
                          ? qsTr("No tags match \"%1\".").arg(tagsPageRoot.filterText)
                          : qsTr("Tags label words across decks so you can filter and find them fast.")
                ctaText: _filtered ? "" : qsTr("+ Tag")
                onCtaClicked: tagsPageRoot.addTagRequested()
            }
        }
    }

    RenameTagDialog { id: renameTagDialog }

    ConfirmDialog {
        id: deleteTagConfirm
        property int     pendingId:    -1
        property string  pendingName:  ""
        property var     affectedDecks: []
        message: {
            const base = "Delete tag \"" + pendingName + "\"? Words keep their other tags."
            if (affectedDecks.length === 0) return base
            const names = affectedDecks.map(d => "\u2022 " + d.name).join("\n")
            return base + "\n\nThese smart decks filter on this tag and will also be removed:\n\n" + names
        }
        onConfirmed: {
            if (pendingId < 0) return
            if (affectedDecks.length > 0) {
                appVM.deleteTagAndAffectedDecks(pendingId)
            } else {
                appVM.entryVM.deleteTag(pendingId)
            }
            tagsPageRoot.refresh()
        }
    }

    // Helper that callers use instead of opening deleteTagConfirm directly,
    // so the affected-deck lookup runs at the right moment (before the
    // tag is deleted — once it's gone the cascade has already wiped the
    // join-table rows we need to identify the affected decks).
    function _openTagDeleteConfirm(tagId, tagName) {
        deleteTagConfirm.pendingId    = tagId
        deleteTagConfirm.pendingName  = tagName
        deleteTagConfirm.affectedDecks = appVM.smartDecksUsingTag(tagId)
        deleteTagConfirm.open()
    }
}



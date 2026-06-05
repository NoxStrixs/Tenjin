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

        // Title row + + Tag button.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "Tags"
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }
            Rectangle {
                Layout.preferredHeight: Platform.touchTarget
                Layout.preferredWidth: addTagLabel.implicitWidth + 28
                radius: Platform.radius
                color: addTagArea.containsMouse ? Platform.accentDark : Platform.accent
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                scale: addTagArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                Text { id: addTagLabel; anchors.centerIn: parent; text: "+ Tag"; color: Platform.bg; font.pixelSize: Platform.fontBase; font.bold: true }
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
            Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                spacing: 6
                Text { text: "\u2315"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                TextField {
                    id: filterInput
                    Layout.fillWidth: true
                    placeholderText: "Filter tags\u2026"
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    background: Rectangle { color: "transparent" }
                    leftPadding: 0
                    onTextChanged: tagsPageRoot.filterText = text
                }
                Text {
                    visible: filterInput.text.length > 0
                    text: "\u2715"
                    color: clearArea.containsMouse ? Platform.textPrimary : Platform.textMuted
                    font.pixelSize: Platform.fontBase
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
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

                Behavior on color        { ColorAnimation { duration: Platform.durationFast } }
                Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                Behavior on border.width { NumberAnimation { duration: Platform.durationFast } }

                // Subtle hover lift on desktop.
                transform: Translate {
                    y: rowHover.hovered ? -1 : 0
                    Behavior on y { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
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
                        text: "\uD83C\uDFF7\uFE0F"
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
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { id: viewLabel; anchors.centerIn: parent; text: "View"; color: Platform.accentDark; font.pixelSize: Platform.fontBase - 1; font.bold: true }
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
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text { id: renameLabel; anchors.centerIn: parent; text: "Rename"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase - 1 }
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
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text {
                            id: delLabel
                            anchors.centerIn: parent
                            text: "Delete"
                            color: delArea.containsMouse ? Platform.textOnDark : Platform.danger
                            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                            font.pixelSize: Platform.fontBase - 1
                            font.bold: true
                        }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                deleteTagConfirm.pendingId = tagRow.modelData.id
                                deleteTagConfirm.pendingName = tagRow.modelData.name
                                deleteTagConfirm.open()
                            }
                        }
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                visible: tagList.count === 0
                spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uD83C\uDFF7\uFE0F"; font.pixelSize: 52; color: Platform.textMuted }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tagsPageRoot.filterText.length > 0
                          ? "No tags match \"" + tagsPageRoot.filterText + "\"."
                          : "No tags yet.\nTap + Tag to create one."
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    RenameTagDialog { id: renameTagDialog }

    ConfirmDialog {
        id: deleteTagConfirm
        property int pendingId: -1
        property string pendingName: ""
        message: "Delete tag \"" + pendingName + "\"? It will be removed from all words."
        onConfirmed: if (pendingId >= 0) appVM.entryVM.deleteTag(pendingId)
    }
}


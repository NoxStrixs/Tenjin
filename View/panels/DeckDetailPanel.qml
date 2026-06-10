pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Item {
    id: panelRoot
    // Provided by the page so Review can be launched.
    property var reviewLoaderRef: null
    property bool showAnalytics: false

    ColumnLayout {
        anchors { fill: parent; margins: Platform.pagePadding }
        spacing: 14

        // Header: name row + action buttons.
        // On mobile the buttons move to a second row so nothing clips.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: appVM.deckVM.selectedDeckName
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle; font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: appVM.deckVM.selectedDeckIsSmart ? qsTr("(Smart)") : qsTr("(Manual)")
                    color: Platform.textMuted; font.pixelSize: Platform.fontBase
                }

                // Desktop: keep buttons inline with the title.
                Row {
                    visible: !Platform.isMobile
                    spacing: 8
                    ActionButton {
                        text: qsTr("▶ Review"); variant: "success"
                        onClicked: {
                            appVM.reviewVM.startSession(appVM.deckVM.selectedDeckId)
                            if (panelRoot.reviewLoaderRef) panelRoot.reviewLoaderRef.active = true
                        }
                    }
                    ActionButton {
                        text: panelRoot.showAnalytics ? qsTr("Hide analytics") : qsTr("Analytics")
                        onClicked: panelRoot.showAnalytics = !panelRoot.showAnalytics
                    }
                    ActionButton {
                        text: qsTr("Delete"); variant: "danger"
                        onClicked: deleteDeckConfirm.open()
                    }
                }
            }

            // Mobile action bar: full-width row so buttons never overflow.
            RowLayout {
                visible: Platform.isMobile
                Layout.fillWidth: true
                spacing: 8
                ActionButton {
                    Layout.fillWidth: true
                    text: qsTr("▶ Review"); variant: "success"
                    onClicked: {
                        appVM.reviewVM.startSession(appVM.deckVM.selectedDeckId)
                        if (panelRoot.reviewLoaderRef) panelRoot.reviewLoaderRef.active = true
                    }
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: panelRoot.showAnalytics ? qsTr("Hide") : qsTr("Analytics")
                    onClicked: panelRoot.showAnalytics = !panelRoot.showAnalytics
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: qsTr("Delete"); variant: "danger"
                    onClicked: deleteDeckConfirm.open()
                }
            }
        }

        // Analytics (toggled)
        AnalyticsPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 480
            visible: panelRoot.showAnalytics
            deckId: panelRoot.showAnalytics ? appVM.deckVM.selectedDeckId : -1
        }

        // Smart deck: tag-filter editor
        ColumnLayout {
            Layout.fillWidth: true
            visible: appVM.deckVM.selectedDeckIsSmart
            spacing: 6

            Text { text: qsTr("Tag filters"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: appVM.deckVM.tagFilters
                    delegate: TagChip {
                        required property var modelData
                        tagName: modelData.name
                        tagId: modelData.id
                        editable: true
                        onRemoveClicked: (tid) => appVM.deckVM.removeTagFilter(appVM.deckVM.selectedDeckId, tid)
                    }
                }
                // + filter
                Rectangle {
                    id: addFilterBtn
                    width: addFilterText.implicitWidth + 24
                    height: Platform.isMobile ? 36 : 26
                    radius: height / 2
                    color: addFilterArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                    border.color: Platform.border; border.width: 1
                    Text { id: addFilterText; anchors.centerIn: parent; text: qsTr("+ filter"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2 }
                    MouseArea {
                        id: addFilterArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { tagFilterPopup.allTags = appVM.deckVM.allTags(); tagFilterPopup.open() }
                    }
                    Popup {
                        id: tagFilterPopup
                        y: addFilterBtn.height + 4; width: 220; padding: 6
                        property var allTags: []
                        background: Rectangle { color: Platform.surface; radius: Platform.radius; border.color: Platform.border; border.width: 1 }
                        contentItem: ListView {
                            implicitHeight: Math.min(contentHeight, 240); clip: true
                            model: tagFilterPopup.allTags
                            delegate: ItemDelegate {
                                required property var modelData
                                width: ListView.view.width; height: Platform.touchTarget * 0.85
                                background: Rectangle { color: hovered ? Platform.surfaceAlt : "transparent"; radius: Platform.radius - 2 }
                                contentItem: Text { text: modelData.name ?? ""; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; verticalAlignment: Text.AlignVCenter; leftPadding: 6 }
                                onClicked: { appVM.deckVM.addTagFilter(appVM.deckVM.selectedDeckId, modelData.id); tagFilterPopup.close() }
                            }
                            Text { anchors.centerIn: parent; visible: parent.count === 0; text: qsTr("No tags yet"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }
        }

        // Manual deck: add-word control
        RowLayout {
            Layout.fillWidth: true
            visible: !appVM.deckVM.selectedDeckIsSmart
            spacing: 8
            Text {
                text: appVM.deckVM.selectedDeckIsSmart ? qsTr("Matched words") : qsTr("Words")
                color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1
                Layout.fillWidth: true
            }
            Rectangle {
                id: addWordBtn
                implicitWidth: addWordText.implicitWidth + 24
                implicitHeight: Platform.touchTarget * 0.85
                radius: Platform.radius
                color: addWordArea.containsMouse ? Platform.accentDark : Platform.accent
                Text { id: addWordText; anchors.centerIn: parent; text: qsTr("+ Add word"); color: Platform.bg; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                MouseArea {
                    id: addWordArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { wordPicker.allWords = appVM.deckVM.allWords(); wordFilter.text = ""; wordPicker.open(); wordFilter.forceActiveFocus() }
                }
                Popup {
                    id: wordPicker
                    y: addWordBtn.height + 4
                    x: addWordBtn.width - width
                    width: 280; padding: 8
                    property var allWords: []
                    background: Rectangle { color: Platform.surface; radius: Platform.radius; border.color: Platform.border; border.width: 1 }
                    contentItem: ColumnLayout {
                        spacing: 6
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: Platform.touchTarget
                            color: Platform.bg; radius: Platform.radius - 2
                            border.color: wordFilter.activeFocus ? Platform.accent : Platform.border
                            border.width: wordFilter.activeFocus ? 2 : 1
                            TextField {
                                id: wordFilter
                                anchors.fill: parent; anchors.margins: 6
                                placeholderText: qsTr("Filter words…"); placeholderTextColor: Platform.textMuted
                                color: Platform.textPrimary; font.pixelSize: Platform.fontBase; background: null
                            }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 260); clip: true
                            model: wordPicker.allWords.filter(function (w) {
                                return wordFilter.text.length === 0
                                    || (w.word ?? "").toLowerCase().indexOf(wordFilter.text.toLowerCase()) >= 0
                            })
                            delegate: ItemDelegate {
                                required property var modelData
                                width: ListView.view.width; height: Platform.touchTarget * 0.85
                                background: Rectangle { color: hovered ? Platform.surfaceAlt : "transparent"; radius: Platform.radius - 2 }
                                contentItem: Text { text: modelData.word ?? ""; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; verticalAlignment: Text.AlignVCenter; leftPadding: 6 }
                                onClicked: { appVM.deckVM.addWordToDeck(appVM.deckVM.selectedDeckId, modelData.id); wordPicker.close() }
                            }
                            Text { anchors.centerIn: parent; visible: parent.count === 0; text: qsTr("No words"); color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }
                        }
                    }
                }
            }
        }

        // Word list
        ListView {
            id: deckWordList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: appVM.deckVM.deckWords
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            // Header row — count + "tap to open" hint. Hidden when empty.
            header: Item {
                width: deckWordList.width
                height: deckWordList.count > 0 ? Platform.touchTarget * 0.8 : 0
                visible: deckWordList.count > 0
                RowLayout {
                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: deckWordList.count + (deckWordList.count === 1 ? qsTr(" word") : qsTr(" words"))
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                    }
                    Text {
                        text: qsTr("Tap a word to open it")
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.italic: true
                    }
                }
            }

            delegate: ItemDelegate {
                id: wd
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: Platform.touchTarget + 16

                readonly property bool _selected: appVM.entryVM.selectedEntryId === wd.modelData.id

                background: Rectangle {
                    radius: Platform.radius
                    color: wd._selected ? Platform.surfaceAlt
                         : wd.hovered  ? Qt.rgba(Platform.surfaceAlt.r, Platform.surfaceAlt.g, Platform.surfaceAlt.b, 0.6)
                                         : Platform.surface
                    border.color: wd._selected ? Platform.accent
                                : wd.hovered  ? Platform.accent
                                                 : Platform.border
                    border.width: wd._selected ? 2 : 1
                    Behavior on color        { ColorAnimation { duration: Platform.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                    Behavior on border.width { NumberAnimation { duration: Platform.durationFast } }
                }

                // Subtle hover lift on desktop.
                transform: Translate {
                    y: wd.hovered ? -1 : 0
                    Behavior on y { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                }

                scale: wd.pressed ? 0.99 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }

                contentItem: RowLayout {
                    spacing: 10

                    // Position marker — small index pill so users can see
                    // the deck order at a glance.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        implicitWidth: 28
                        implicitHeight: 22
                        radius: 11
                        color: wd._selected ? Platform.accent : Platform.surfaceAlt
                        border.color: Platform.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text {
                            anchors.centerIn: parent
                            text: (wd.index + 1) + ""
                            color: wd._selected ? Platform.bg : Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                            font.bold: true
                        }
                    }

                    // Word text — primary affordance.
                    Text {
                        Layout.fillWidth: true
                        text: wd.modelData.word
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        font.bold: wd._selected
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Chevron — affordance for "tap opens the word".
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "\u203A"
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontTitle
                        rightPadding: 4
                        opacity: wd.hovered ? 1.0 : 0.45
                        Behavior on opacity { NumberAnimation { duration: Platform.durationFast } }
                    }

                    // Remove control — manual decks only. Compact circular
                    // button that turns danger-red on hover so accidental
                    // taps are unlikely.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 6
                        visible: !appVM.deckVM.selectedDeckIsSmart
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: rmArea.containsMouse ? Platform.danger : "transparent"
                        border.color: rmArea.containsMouse ? Platform.danger : Platform.border
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: Platform.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: rmArea.containsMouse ? Platform.textOnDark : Platform.textMuted
                            font.pixelSize: Platform.fontBase
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        }
                        MouseArea {
                            id: rmArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Stop propagation so the row's tap-to-open
                            // doesn't fire underneath.
                            preventStealing: true
                            onClicked: appVM.deckVM.removeWordFromDeck(appVM.deckVM.selectedDeckId, wd.modelData.id)
                        }
                    }
                }

                onClicked: { appVM.entryVM.selectEntry(wd.modelData.id); appVM.currentPage = 0 }
            }

            // Empty state — large icon + helpful prompt.
            Column {
                anchors.centerIn: parent
                visible: deckWordList.count === 0
                spacing: 12
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: appVM.deckVM.selectedDeckIsSmart ? "\u2728" : "\uD83D\uDCD6"
                    font.pixelSize: 52
                    color: Platform.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: appVM.deckVM.selectedDeckIsSmart
                          ? "No words match these tag filters yet."
                          : "No words yet."
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontLarge
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !appVM.deckVM.selectedDeckIsSmart
                    text: qsTr("Use + Add word to populate this deck.")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    ConfirmDialog {
        id: deleteDeckConfirm
        message: "Delete deck \"" + appVM.deckVM.selectedDeckName + "\"?"
        onConfirmed: appVM.deckVM.deleteDeck(appVM.deckVM.selectedDeckId)
    }
}




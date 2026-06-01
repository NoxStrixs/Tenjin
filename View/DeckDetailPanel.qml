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

        // Header — name row + action buttons.
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
                    text: appVM.deckVM.selectedDeckIsSmart ? "(Smart)" : "(Manual)"
                    color: Platform.textMuted; font.pixelSize: Platform.fontBase
                }

                // Desktop: keep buttons inline with the title.
                Row {
                    visible: !Platform.isMobile
                    spacing: 8
                    ActionButton {
                        text: "▶ Review"; variant: "success"
                        onClicked: {
                            appVM.reviewVM.startSession(appVM.deckVM.selectedDeckId)
                            if (panelRoot.reviewLoaderRef) panelRoot.reviewLoaderRef.active = true
                        }
                    }
                    ActionButton {
                        text: panelRoot.showAnalytics ? "Hide analytics" : "Analytics"
                        onClicked: panelRoot.showAnalytics = !panelRoot.showAnalytics
                    }
                    ActionButton {
                        text: "Delete"; variant: "danger"
                        onClicked: deleteDeckConfirm.open()
                    }
                }
            }

            // Mobile action bar — full-width row so buttons never overflow.
            RowLayout {
                visible: Platform.isMobile
                Layout.fillWidth: true
                spacing: 8
                ActionButton {
                    Layout.fillWidth: true
                    text: "▶ Review"; variant: "success"
                    onClicked: {
                        appVM.reviewVM.startSession(appVM.deckVM.selectedDeckId)
                        if (panelRoot.reviewLoaderRef) panelRoot.reviewLoaderRef.active = true
                    }
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: panelRoot.showAnalytics ? "Hide" : "Analytics"
                    onClicked: panelRoot.showAnalytics = !panelRoot.showAnalytics
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: "Delete"; variant: "danger"
                    onClicked: deleteDeckConfirm.open()
                }
            }
        }

        // ── Analytics (toggled) ─────────────────────────────────────
        AnalyticsPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 480
            visible: panelRoot.showAnalytics
            deckId: panelRoot.showAnalytics ? appVM.deckVM.selectedDeckId : -1
        }

        // ── Smart deck: tag-filter editor ───────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: appVM.deckVM.selectedDeckIsSmart
            spacing: 6

            Text { text: "Tag filters"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }

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
                    Text { id: addFilterText; anchors.centerIn: parent; text: "+ filter"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2 }
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
                            Text { anchors.centerIn: parent; visible: parent.count === 0; text: "No tags yet"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }
        }

        // ── Manual deck: add-word control ───────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: !appVM.deckVM.selectedDeckIsSmart
            spacing: 8
            Text {
                text: appVM.deckVM.selectedDeckIsSmart ? "Matched words" : "Words"
                color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1
                Layout.fillWidth: true
            }
            Rectangle {
                id: addWordBtn
                implicitWidth: addWordText.implicitWidth + 24
                implicitHeight: Platform.touchTarget * 0.85
                radius: Platform.radius
                color: addWordArea.containsMouse ? Platform.accentDark : Platform.accent
                Text { id: addWordText; anchors.centerIn: parent; text: "+ Add word"; color: Platform.bg; font.pixelSize: Platform.fontBase - 1; font.bold: true }
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
                                placeholderText: "Filter words…"; placeholderTextColor: Platform.textMuted
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
                            Text { anchors.centerIn: parent; visible: parent.count === 0; text: "No words"; color: Platform.textMuted; font.pixelSize: Platform.fontBase - 1 }
                        }
                    }
                }
            }
        }

        // Word list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: appVM.deckVM.deckWords
            clip: true; spacing: 2

            delegate: ItemDelegate {
                id: wd
                required property var modelData
                width: ListView.view.width
                implicitHeight: Platform.touchTarget

                contentItem: RowLayout {
                    Text { Layout.fillWidth: true; text: wd.modelData.word; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                    // Manual decks can remove; smart decks are computed.
                    ToolButton {
                        id: rmBtn
                        visible: !appVM.deckVM.selectedDeckIsSmart
                        text: "✕"
                        implicitWidth: Platform.touchTarget; implicitHeight: Platform.touchTarget
                        contentItem: Text { text: rmBtn.text; color: Platform.danger; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: appVM.deckVM.removeWordFromDeck(appVM.deckVM.selectedDeckId, wd.modelData.id)
                    }
                }
                background: Rectangle { color: hovered ? Platform.surfaceAlt : "transparent"; radius: Platform.radius - 2 }
                onClicked: { appVM.wordVM.selectWord(wd.modelData.id); appVM.currentPage = 0 }
            }

            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: appVM.deckVM.selectedDeckIsSmart
                      ? "No words match these tag filters yet."
                      : "No words yet — use + Add word."
                color: Platform.textMuted; font.pixelSize: Platform.fontBase
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - 40; wrapMode: Text.WordWrap
            }
        }
    }

    ConfirmDialog {
        id: deleteDeckConfirm
        message: "Delete deck \"" + appVM.deckVM.selectedDeckName + "\"?"
        onConfirmed: appVM.deckVM.deleteDeck(appVM.deckVM.selectedDeckId)
    }
}


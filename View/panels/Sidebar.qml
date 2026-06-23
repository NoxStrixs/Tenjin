import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebarRoot
    color: Platform.surface

    signal addEntryRequested()
    signal addDeckRequested()
    signal addTagRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Mode tabs: Words | Decks. Tags are unified into the standalone
        // Tags page (reached from the header / mobile drawer / universal
        // search); the previous in-sidebar tag tree was a duplicate of
        // that page and was confusing to keep in sync.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Platform.surface
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Platform.border
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: [qsTr("Words"), qsTr("Decks")]
                    Rectangle {
                        width: parent.width / 2
                        height: 38
                        color: tabHover.containsMouse && !active ? Platform.surfaceAlt : "transparent"
                        property bool active: sidebarMode === index
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Platform.fontSmall
                            font.bold: parent.active
                            color: parent.active ? Platform.accent : Platform.textMuted
                            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 2
                            color: parent.active ? Platform.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        }
                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sidebarMode = index
                                // Mode 0 → Words page (0), mode 1 → Decks page (1).
                                appVM.currentPage = index
                            }
                        }
                    }
                }
            }
        }

        // Filter input removed — the header SearchBox is now the universal
        // search across words, tags, and decks. Sidebar list is shown in
        // full and filtered only by the global tag-filter popup.

        // Add button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Platform.surface
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Platform.border
            }
            Rectangle {
                id: addBtn
                anchors.centerIn: parent
                width: parent.width - 16
                height: 28
                radius: Platform.radius
                color: addBtnArea.containsMouse ? Platform.accentDark : Platform.accent
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                scale: addBtnArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: sidebarMode === 0 ? qsTr("+ Word") : qsTr("+ Deck")
                    color: Platform.bg
                    font.pixelSize: Platform.fontSmall
                    font.bold: true
                }
                MouseArea {
                    id: addBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sidebarMode === 0) sidebarRoot.addEntryRequested()
                        else sidebarRoot.addDeckRequested()
                    }
                }
            }
        }

        // Lists
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: sidebarMode

            // Words
            ColumnLayout {
                spacing: 6

                // Tag filter — single trigger button that opens the shared
                // TagFilterPopup. Replaces the previous always-visible chip
                // flow that duplicated the mobile filter UI; the same component
                // now renders on both platforms (TagFilterPopup.qml).
                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: Platform.spacingMd
                    Layout.rightMargin: Platform.spacingMd
                    Layout.topMargin: Platform.spacingSm
                    implicitHeight: tagFilter.implicitHeight
                    // Hide entirely when there are no tags in the collection
                    // — nothing to filter by, so the trigger would be a no-op.
                    visible: tagFilter._anyTags

                    TagFilterPopup {
                        id: tagFilter
                        // Anchor left + right so the component spans the full
                        // sidebar width. The popup's desktop width follows
                        // root.width, so this is what makes the dropdown
                        // match the sidebar instead of hugging the trigger.
                        anchors.left: parent.left
                        anchors.right: parent.right
                        // Local convenience: cache the result of getAllTags()
                        // for the visibility check so we don't re-call it on
                        // every relayout.
                        property var _allTags: appVM.entryVM.getAllTags()
                        readonly property bool _anyTags: _allTags.length > 0
                        Connections {
                            target: appVM.entryVM
                            function onEntryListChanged() {
                                tagFilter._allTags = appVM.entryVM.getAllTags()
                            }
                        }
                    }
                }

                ListView {
                    id: wordListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: appVM.entryVM.getAllEntries()

                    Connections {
                        target: appVM.entryVM
                        function onEntryListChanged() {
                            wordListView.model = appVM.entryVM.getAllEntries()
                        }
                        function onTagFiltersChanged() {
                            wordListView.model = appVM.entryVM.getAllEntries()
                        }
                    }

                delegate: Rectangle {
                    id: wordRow
                    width: ListView.view.width
                    height: 38
                    readonly property bool _selected: appVM.entryVM.selectedEntryId === modelData.wordId
                    color: _selected ? Platform.surfaceAlt
                         : wordRowArea.containsMouse ? Qt.rgba(Platform.surfaceAlt.r, Platform.surfaceAlt.g, Platform.surfaceAlt.b, 0.5)
                                                      : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                    Rectangle {
                        anchors { left: parent.left; bottom: parent.bottom }
                        width: 3; height: parent.height
                        color: Platform.accent
                        visible: wordRow._selected
                    }

                    Text {
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 14
                        }
                        text: modelData.word
                        font.pixelSize: Platform.fontBase
                        color: Platform.textPrimary
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: Platform.border; opacity: 0.5
                    }
                    MouseArea {
                        id: wordRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appVM.entryVM.selectEntry(modelData.wordId)
                            appVM.currentPage = 0
                        }
                    }
                }

                // Empty state
                EmptyState {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: wordListView.count === 0
                    icon: TenjinIcons.words
                    title: qsTr("No words yet")
                    subtitle: qsTr("Add your first word to start building your collection.")
                    ctaText: qsTr("+ Word")
                    onCtaClicked: sidebarRoot.addEntryRequested()
                }
            }
            }

            // Tags removed — TagsPage is the canonical tag UI. The previous
            // expandable tag → word tree here duplicated TagsPage and drifted
            // out of sync with it; universal search + the standalone page
            // cover the same affordances with one source of truth.

            // Decks
            ListView {
                id: deckListView
                clip: true
                model: appVM.deckVM.deckModel

                // Bumped to force the per-row due badges to re-query deckStats
                property int deckRefresh: 0
                Connections {
                    target: appVM.deckVM.deckModel
                    function onModelReset() { deckListView.deckRefresh++ }
                }
                Connections {
                    target: appVM.reviewVM
                    function onSessionChanged() { deckListView.deckRefresh++ }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 38
                    color: appVM.deckVM.selectedDeckId === model.deckId
                           ? Platform.surfaceAlt : "transparent"

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: Platform.accent
                        visible: appVM.deckVM.selectedDeckId === model.deckId
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: model.deckName
                            font.pixelSize: Platform.fontBase
                            color: Platform.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "✦"
                            font.pixelSize: Platform.fontTiny
                            color: Platform.textMuted
                            visible: model.isSmart
                        }
                        // Due badge / next-due hint. Recomputed when the deck model changes.
                        Rectangle {
                            id: dueBadge
                            property var stats: (deckListView.deckRefresh, appVM.deckVM.deckStats(model.deckId))
                            visible: stats.total > 0
                            implicitWidth: dueText.implicitWidth + 12
                            implicitHeight: 18
                            radius: height / 2
                            color: stats.due > 0 ? Platform.accent : "transparent"
                            border.color: stats.due > 0 ? Platform.accent : Platform.border
                            border.width: 1
                            Text {
                                id: dueText
                                anchors.centerIn: parent
                                text: dueBadge.stats.due > 0
                                      ? dueBadge.stats.due + " due"
                                      : (dueBadge.stats.nextDue.length > 0 ? "✓" : "✓")
                                color: dueBadge.stats.due > 0 ? Platform.bg : Platform.textMuted
                                font.pixelSize: Platform.fontTiny
                                font.bold: dueBadge.stats.due > 0
                            }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: Platform.border; opacity: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appVM.deckVM.selectDeck(model.deckId)
                            appVM.currentPage = 1
                        }
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: deckListView.count === 0
                    icon: TenjinIcons.decks
                    title: qsTr("No decks yet")
                    subtitle: qsTr("Group related words into a deck to start reviewing.")
                    ctaText: qsTr("+ Deck")
                    onCtaClicked: sidebarRoot.addDeckRequested()
                }
            }
        }

        // Tags shortcut — leads to the Tags page (the canonical tag UI).
        // Lives above Import/Export so the most-used navigation control is
        // closer to the lists.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Platform.surface
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1; color: Platform.border
            }
            readonly property bool _active: appVM.currentPage === 2
            Rectangle {
                anchors.fill: parent
                color: tagsShortcutArea.containsMouse || parent._active ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
            }
            // Active-indicator bar on the left when the Tags page is open.
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 3
                color: parent._active ? Platform.accent : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10
                Text {
                    text: TenjinIcons.tags
                    font.family: TenjinIcons.family
                    font.pixelSize: Platform.iconSize
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Manage tags")
                    color: parent.parent._active ? Platform.accent : Platform.textPrimary
                    font.pixelSize: Platform.fontSmall
                    font.bold: parent.parent._active
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                }
                Text {
                    text: TenjinIcons.chevronRight
                    font.family: TenjinIcons.family
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontLarge
                }
            }
            MouseArea {
                id: tagsShortcutArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: appVM.currentPage = 2  // PageTags
            }
        }

        // Import / Export footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: Platform.surface
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1; color: Platform.border
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8
                Repeater {
                    model: [{ label: qsTr("Import"), act: 0 }, { label: qsTr("Export"), act: 1 }]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Platform.radius
                        color: ieArea.containsMouse ? Platform.surfaceAlt : Platform.bg
                        border.color: Platform.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: Platform.accentDark
                            font.pixelSize: Platform.fontSmall
                            font.bold: true
                        }
                        MouseArea {
                            id: ieArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData.act === 0) {
                                    // Import — show the QML picker that
                                    // lists files in appVM.documentsFolder.
                                    importPickerDialog.open()
                                } else {
                                    // Export — write to Documents folder,
                                    // toast the resulting path so the user
                                    // can find it (Files app on iOS,
                                    // ~/Documents on desktop).
                                    const path = appVM.exportToDocuments()
                                    if (path && path.length > 0)
                                        appVM.statusMessage = "Exported to " + path
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // FileDialog was the wrong abstraction for cross-platform export/import:
    // QtQuick.Dialogs.FileDialog emits "no native option" on iOS (no
    // platform picker, no Quick fallback). Replaced with:
    //   Export → appVM.exportToDocuments() writes a timestamped JSON to
    //            ~/Documents (or the iOS sandboxed Documents that's
    //            visible via Files.app) and toasts the path.
    //   Import → ImportPickerDialog lists existing JSON exports in that
    //            folder and lets the user pick one.
    ImportPickerDialog { id: importPickerDialog }

    // Mode state
    property int sidebarMode: 0
}






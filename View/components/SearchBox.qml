pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Search field with a live dropdown of word/tag matches and a toggle to also match inside content blocks.
// Clicking a word opens it; clicking a tag filters the word list to that tag.
Item {
    id: root
    implicitHeight: Platform.touchTarget
    // On mobile the parent sets Layout.fillWidth=true so the search bar
    // expands to use all the remaining header space naturally.
    // On desktop keep the fixed cap so it doesn't blow up on wide windows.
    Layout.preferredWidth: Platform.isMobile ? -1 : Math.min(260, parentWidth * 0.32)
    Layout.fillWidth: Platform.isMobile
    Layout.minimumWidth: 120
    Layout.preferredHeight: Platform.touchTarget

    // Provided by parent so width can scale with the window.
    property real parentWidth: 800

    // When false, the live results popup is suppressed.
    property bool dropdownEnabled: true

    // Keep the field in sync with the VM query across page switches / recreation.
    property string queryText: appVM.entryVM.searchQuery

    Rectangle {
        id: field
        anchors.fill: parent
        color: Platform.bg
        radius: Platform.radius
        border.color: searchField.activeFocus ? Platform.accent : Platform.border
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
            spacing: 6

            Text { text: "\u2315"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }

            TextField {
                id: searchField
                Layout.fillWidth: true
                text: root.queryText
                placeholderText: "Search words & tags\u2026"
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                leftPadding: 0
                onTextChanged: {
                    appVM.entryVM.searchQuery = text
                    if (root.dropdownEnabled && text.length > 0) dropdown.open()
                    else dropdown.close()
                }
                Keys.onEscapePressed: { text = ""; dropdown.close() }
            }

            // Clear button
            Text {
                visible: searchField.text.length > 0
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
                    onClicked: { searchField.text = ""; dropdown.close() }
                }
            }

            // Content-search toggle. Always visible (works on mobile where the
            // results dropdown is suppressed). Glyph toggles accent when active;
            // matches inside content blocks, not just the word/tag name.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Platform.isMobile ? 34 : 26
                implicitHeight: Platform.isMobile ? 34 : 26
                radius: Platform.radius - 1
                color: appVM.entryVM.searchInContent ? Platform.accent : Platform.surfaceAlt
                border.color: appVM.entryVM.searchInContent ? Platform.accent : Platform.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\u2630"   // list/lines glyph = search within content
                    font.pixelSize: Platform.fontBase
                    font.bold: true
                    color: appVM.entryVM.searchInContent ? Platform.textOnDark : Platform.textMuted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.entryVM.searchInContent = !appVM.entryVM.searchInContent
                    ToolTip.visible: pressed
                    ToolTip.text: "Also search content blocks"
                }
            }
        }
    }

    Popup {
        id: dropdown
        y: field.height + 4
        width: field.width
        padding: 6
        // Don't steal focus from the text field while typing.
        closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

        background: Rectangle {
            color: Platform.surface
            radius: Platform.radius
            border.color: Platform.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 4

            // Results
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 280)
                clip: true
                model: appVM.entryVM.searchResults
                interactive: true

                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    height: (modelData.kind === "word" && (modelData.snippet ?? "").length > 0)
                            ? Platform.touchTarget * 1.5 : Platform.touchTarget

                    background: Rectangle {
                        color: hovered ? Platform.surfaceAlt : "transparent"
                        radius: Platform.radius - 2
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        // Kind badge
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4
                            implicitWidth: kindText.implicitWidth + 12
                            implicitHeight: 18
                            radius: height / 2
                            color: modelData.kind === "tag" ? Platform.accentDark : Platform.surfaceAlt
                            border.color: Platform.border
                            border.width: 1
                            Text {
                                id: kindText
                                anchors.centerIn: parent
                                text: modelData.kind === "tag" ? "tag" : "word"
                                color: modelData.kind === "tag" ? Platform.textOnDark : Platform.accentDark
                                font.pixelSize: Platform.fontBase - 4
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Platform.textPrimary
                                font.pixelSize: Platform.fontBase
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: modelData.kind === "word"
                                         && (modelData.snippet ?? "").length > 0
                                text: modelData.snippet ?? ""
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase - 3
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                    onClicked: {
                        if (modelData.kind === "tag") {
                            appVM.entryVM.filterByTag(modelData.id, modelData.label)
                        } else {
                            appVM.entryVM.selectEntry(modelData.id)
                            appVM.currentPage = 0
                        }
                        searchField.text = ""
                        dropdown.close()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "No matches"
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                }
            }
        }
    }
}







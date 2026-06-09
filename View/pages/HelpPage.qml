import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top-level Help destination. Driven by appVM.currentPage === PageHelp (=3).
// Scrollable column of sections. Replaces the previous inline helpPopup; the
// content is identical so users get the same six sections, just as a
// navigable page now rather than a modal.
Item {
    id: helpRoot

    // Asks Main.qml to return to Words. Wired in Main.qml's StackLayout host.
    signal backRequested()

    readonly property var sections: [
        { h: "Getting started",
          b: "Tenjin organizes the things you want to remember into Words, gathered into Decks, and labelled with Tags. Everything lives locally on this device unless you export it." },
        { h: "Adding a word",
          b: "From the Words page, tap + Word. Give it a headword, then add content blocks below — plain text, formulas (LaTeX), images, audio, video, or links. Drag handles let you arrange the layout." },
        { h: "Decks & reviews",
          b: "On the Decks page, create a deck and add words to it. Open a deck and start a Review session — Tenjin uses spaced repetition to schedule what you see next based on how well you knew it." },
        { h: "Tags & filtering",
          b: "Tag words on the word's detail page or from the Tags page. The Tags filter in the sidebar / mobile filter bar lets you narrow the Words list to any combination, in Any or All mode." },
        { h: "Import & export",
          b: "Your entire collection exports to a single JSON file (Settings → Export collection). Import the same JSON on another device to move everything across." },
        { h: "Re-run the walkthrough",
          b: "Settings → Show welcome again. The carousel will re-open immediately and play through all four steps." }
    ]

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: helpRoot.width
            spacing: Platform.spacingMd

            // Desktop title row with back arrow — mobile shows the title
            // in the window header.
            RowLayout {
                visible: !Platform.isMobile
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.topMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                Layout.bottomMargin: Platform.spacingSm
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: Platform.touchTarget
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: helpBackArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2039"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                    MouseArea {
                        id: helpBackArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: helpRoot.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Help"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
            }

            Repeater {
                model: helpRoot.sections
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.leftMargin: Platform.pagePadding
                    Layout.rightMargin: Platform.pagePadding
                    Layout.topMargin: Platform.isMobile && index === 0 ? Platform.pagePadding : 0
                    spacing: Platform.spacingSm

                    Text {
                        Layout.fillWidth: true
                        text: modelData.h
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.b
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Platform.spacingSm
                        Layout.preferredHeight: Platform.borderWidth
                        color: Platform.border
                        opacity: 0.5
                    }
                }
            }

            Item { Layout.preferredHeight: Platform.spacingXl + Platform.safeAreaBottom }
        }
    }
}


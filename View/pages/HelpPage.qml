import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top-level Help destination. Driven by appVM.currentPage === PageHelp (=3).
// Scrollable column of sections covering the full feature set.
Item {
    id: helpRoot

    signal backRequested()

    readonly property var sections: [
        {
            h: qsTr("Getting started"),
            b: qsTr("Tenjin organizes everything worth remembering into three layers. " +
                    "Words are individual entries — a vocabulary term, a phrase, a fact. " +
                    "Decks group related words for spaced-repetition review. Tags label " +
                    "words across decks so you can filter and find them instantly. Start " +
                    "by adding a few words from the Words page, then group them into a deck.")
        },
        {
            h: qsTr("Adding a word"),
            b: qsTr("On the Words page, tap the + button. Give the word a title and choose " +
                    "its language. Each word holds rich content blocks: formatted text, " +
                    "math formulas, images, audio, and video. Add as many blocks as you " +
                    "need — a definition, an example sentence, a pronunciation clip. Use " +
                    "the formatting toolbar for bold, italics, underline, strikethrough, " +
                    "and bullet lists. Tap a block's menu to reorder or delete it.")
        },
        {
            h: qsTr("Content blocks"),
            b: qsTr("Text blocks support inline formatting and color. Formula blocks render " +
                    "LaTeX math — type an expression and it displays as typeset notation. " +
                    "Media blocks hold an image, audio file, or video; on mobile, drop files " +
                    "into Tenjin's Documents folder via the Files app, then pick them from " +
                    "the media picker. You can also paste a web or video URL directly.")
        },
        {
            h: qsTr("Decks & reviews"),
            b: qsTr("On the Decks page, create a manual deck and add words to it, or build a " +
                    "smart deck that automatically includes every word matching a set of tags. " +
                    "Open a deck and tap Review to start a session. Tenjin shows each card, " +
                    "you reveal the answer, then rate how well you knew it from 0 (forgot) to " +
                    "3 (easy). The spaced-repetition schedule uses your ratings to decide when " +
                    "each card comes back — cards you find hard return sooner, easy ones later.")
        },
        {
            h: qsTr("Tags & filtering"),
            b: qsTr("Tag words on the word detail view or while adding them. On the Tags page " +
                    "you can rename or delete tags across your whole collection. Use the tag " +
                    "filter on the Words page to narrow the list to one or more tags at once. " +
                    "Smart decks use the same tags, so tagging a word can automatically add it " +
                    "to the right decks.")
        },
        {
            h: qsTr("Search"),
            b: qsTr("The search box looks across words, tags, and decks at the same time. " +
                    "Matching words jump to the entry; matching tags highlight on the Tags " +
                    "page; matching decks open the deck. Search matches titles and content, " +
                    "so you can find a word by something written inside one of its blocks.")
        },
        {
            h: qsTr("Import & export"),
            b: qsTr("Your entire collection exports to a single JSON file from Settings. On " +
                    "desktop a save dialog appears; on mobile the file is written to Tenjin's " +
                    "Documents folder, reachable from the Files app. To import, pick a " +
                    "previously exported file. Import merges into your existing collection — " +
                    "it never overwrites everything, so you can combine collections safely.")
        },
        {
            h: qsTr("Themes & language"),
            b: qsTr("Toggle light and dark mode from the header or Settings at any time; the " +
                    "change applies instantly. Tenjin's interface is available in several " +
                    "languages — pick yours under Settings ▸ Language. This is separate from " +
                    "the language you assign to individual words, so you can study Japanese " +
                    "vocabulary with a Spanish interface, for example.")
        },
        {
            h: qsTr("Reminders & notifications"),
            b: qsTr("Tenjin can remind you when cards are due for review. Grant notification " +
                    "permission when prompted, and reminders arrive even when the app is " +
                    "closed. You stay in control — reminders are optional and can be turned " +
                    "off at any time.")
        },
        {
            h: qsTr("Send feedback"),
            b: qsTr("Found a bug or have an idea? Open Settings ▸ Send feedback. Describe what " +
                    "happened, and optionally include diagnostic logs that help us fix issues " +
                    "faster. Your logs are used only for diagnosis and are never shared publicly.")
        },
        {
            h: qsTr("Re-run the walkthrough"),
            b: qsTr("Want to see the welcome tour again? Open Settings ▸ Show welcome again " +
                    "to replay the introduction at any time.")
        }
    ]

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: helpRoot.width
            spacing: Platform.spacingMd

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
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Back")
                    Accessible.onPressAction: helpRoot.backRequested()

                    Text {
                        anchors.centerIn: parent
                        text: TenjinIcons.chevronLeft
                        font.family: TenjinIcons.family
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.weight: Font.Normal
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
                    text: qsTr("Help")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
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
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.b
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                        Accessible.role: Accessible.StaticText
                        Accessible.name: text
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

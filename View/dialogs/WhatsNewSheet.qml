import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// "What's new" sheet shown once after an app update (driven by
// appVM.consumeJustUpdated()). Lists highlights for the current version.
// Edit `entries` each release. Keep it short — 3-5 bullets.
ThemedDialog {
    id: root
    title: qsTr("What's new")
    modal: true
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 420, 420) : 420
    padding: 20

    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    // Per-release highlights. Update on each version bump.
    readonly property var entries: [
        {
            icon: TenjinIcons.download,
            title: qsTr("Anki import"),
            body: qsTr("Import your existing Anki decks from .apkg files — "
                       + "cards, fields, and tags come across automatically.")
        },
        {
            icon: TenjinIcons.autoAwesome,
            title: qsTr("Consistent icons everywhere"),
            body: qsTr("A new icon set renders identically on every device, "
                       + "light or dark.")
        },
        {
            icon: TenjinIcons.bugReport,
            title: qsTr("Send feedback"),
            body: qsTr("Report bugs and suggestions right from Settings, with "
                       + "optional diagnostic logs.")
        }
    ]

    standardButtons: Dialog.Ok

    ColumnLayout {
        spacing: Platform.spacingLg
        width: parent.width

        Text {
            Layout.fillWidth: true
            text: qsTr("Version %1").arg(Qt.application.version)
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
        }

        Repeater {
            model: root.entries
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Platform.spacingMd

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    width: 40; height: 40
                    radius: Platform.radius
                    color: Platform.surfaceAlt
                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.iconSizeLg
                        color: Platform.accent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.body
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }
            }
        }
    }
}

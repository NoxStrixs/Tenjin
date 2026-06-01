import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Dialog {
    id: root
    property string message: "Are you sure?"
    signal confirmed

    title: "Confirm"
    modal: true
    anchors.centerIn: parent
    padding: 20
    standardButtons: Dialog.Ok | Dialog.Cancel

    width: Platform.isMobile ? Math.min(parent.width - 32, 340) : 340

    onAccepted: root.confirmed()

    // Solves clipping inside dialog by nesting standard wrap semantics inside a safe structural item
    ColumnLayout {
        width: parent.width
        Text {
            Layout.fillWidth: true
            text: root.message
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            wrapMode: Text.WordWrap
        }
    }

    background: Rectangle {
        color: Platform.bg; radius: Platform.radiusLarge
        border.color: Platform.border; border.width: 1
    }

    // Themed title bar (replaces the dark default header).
    header: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        // Square off the bottom corners so it meets the body cleanly.
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: Platform.surface }
        implicitHeight: titleText.implicitHeight + 24
        Text {
            id: titleText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Platform.border }
    }

    // Themed footer with cream-styled OK / Cancel buttons.
    footer: DialogButtonBox {
        padding: 16
        spacing: 8
        alignment: Qt.AlignRight
        background: Rectangle { color: "transparent" }

        delegate: Button {
            id: btn
            implicitHeight: Platform.touchTarget
            padding: 10
            contentItem: Text {
                text: btn.text
                color: btn.down ? Platform.textOnDark : Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Platform.radius
                color: btn.down ? Platform.accent
                     : btn.hovered ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1
            }
        }
    }
}

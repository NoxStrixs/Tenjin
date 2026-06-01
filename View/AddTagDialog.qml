import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Dialog {
    id: root
    title: "Create Tag"
    modal: true
    anchors.centerIn: parent
    width: Platform.isMobile ? Math.min(parent.width - 32, 340) : 320
    padding: 20
    standardButtons: Dialog.Ok | Dialog.Cancel

    onAboutToShow: tagNameInput.text = ""
    onAccepted: {
        const name = tagNameInput.text.trim()
        if (name.length > 0)
            appVM.wordVM.createTag(name)
    }

    background: Rectangle {
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
    }

    // Themed title bar (matches ConfirmDialog).
    header: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        implicitHeight: tagTitle.implicitHeight + 24
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: Platform.surface }
        Text {
            id: tagTitle
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Platform.border }
    }

    footer: DialogButtonBox {
        padding: 16
        spacing: 8
        alignment: Qt.AlignRight
        background: Rectangle { color: "transparent" }
        delegate: Button {
            id: tagBtn
            implicitHeight: Platform.touchTarget
            padding: 10
            contentItem: Text {
                text: tagBtn.text
                color: tagBtn.down ? Platform.textOnDark : Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Platform.radius
                color: tagBtn.down ? Platform.accent
                     : tagBtn.hovered ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1
            }
        }
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Text { text: "Name:"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }

        Rectangle {
            Layout.fillWidth: true
            height: Platform.touchTarget
            radius: Platform.radius
            color: Platform.surface
            border.color: tagNameInput.activeFocus ? Platform.accent : Platform.border
            border.width: tagNameInput.activeFocus ? 2 : 1

            TextField {
                id: tagNameInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                placeholderText: "e.g. verb, JLPT N3, chapter 1"
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                Keys.onReturnPressed: root.accept()
            }
        }
    }
}

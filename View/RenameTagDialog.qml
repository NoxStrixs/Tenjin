import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Modal to rename an existing tag. Open via openFor(id, currentName).
Dialog {
    id: root
    title: "Rename Tag"
    modal: true
    anchors.centerIn: parent
    width: Platform.isMobile ? Math.min(parent.width - 32, 340) : 320
    padding: 20
    standardButtons: Dialog.Ok | Dialog.Cancel

    property int tagId: -1

    function openFor(id, currentName) {
        tagId = id
        renameField.text = currentName
        open()
        renameField.forceActiveFocus()
        renameField.selectAll()
    }

    onAccepted: {
        const name = renameField.text.trim()
        if (name.length > 0 && tagId >= 0)
            appVM.wordVM.renameTag(tagId, name)
    }

    background: Rectangle {
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
    }

    header: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        implicitHeight: renameTitle.implicitHeight + 24
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: Platform.surface }
        Text {
            id: renameTitle
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Platform.border }
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
            border.color: renameField.activeFocus ? Platform.accent : Platform.border
            border.width: renameField.activeFocus ? 2 : 1

            TextField {
                id: renameField
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                placeholderText: "Tag name"
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                Keys.onReturnPressed: root.accept()
            }
        }
    }
}

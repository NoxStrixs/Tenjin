import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

ThemedDialog {
    id: root
    title: "Create Tag"
    width: Platform.isMobile ? Math.min(parent.width - 32, 340) : 320
    padding: 20

    onAboutToShow: { tagNameInput.text = ""; tagNameInput.forceActiveFocus() }
    onAccepted: {
        const name = tagNameInput.text.trim()
        if (name.length > 0)
            appVM.entryVM.createTag(name)
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


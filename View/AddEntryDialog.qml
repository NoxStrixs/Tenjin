import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: Platform.isMobile ? Math.min(parent.width - 32, 400) : 400
    padding: 24
    topPadding: 0
    standardButtons: Dialog.Ok | Dialog.Cancel

    background: Rectangle {
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
        layer.enabled: true
        layer.effect: null
    }

    header: Rectangle {
        width: parent.width
        height: 50
        color: Platform.surface
        radius: Platform.radiusLarge
        // Square off bottom corners
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Platform.radiusLarge
            color: Platform.surface
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1; color: Platform.border
        }
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: "Add Word"
            font.pixelSize: 15
            font.bold: true
            color: Platform.textPrimary
        }
    }

    onAboutToShow: {
        wordInput.text = ""
        wordInput.forceActiveFocus()
    }
    onAccepted: {
        const w = wordInput.text.trim()
        if (w.length > 0) appVM.entryVM.addWord(w)
    }

    ColumnLayout {
        width: parent.width
        spacing: 14

        Text {
            text: "Word"
            font.pixelSize: Platform.fontBase
            font.bold: true
            color: Platform.textPrimary
        }

        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: Platform.radius
            color: Platform.bg
            border.color: wordInput.activeFocus ? Platform.accent : Platform.border
            border.width: wordInput.activeFocus ? 2 : 1

            TextField {
                id: wordInput
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                placeholderText: "e.g. ephemeral"
                font.pixelSize: 15
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                Keys.onReturnPressed: root.accept()
            }
        }

        Text {
            text: "The word will appear in your list. Open it to add definitions, notes, and media."
            font.pixelSize: 11
            color: Platform.textMuted
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}




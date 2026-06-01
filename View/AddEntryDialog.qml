import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ThemedDialog {
    id: root
    title: "Add Word"
    width: Platform.isMobile ? Math.min(parent.width - 32, 400) : 400
    padding: 24

    onAboutToShow: {
        wordInput.text = ""
        wordInput.forceActiveFocus()
    }
    onAccepted: {
        const w = wordInput.text.trim()
        if (w.length > 0) appVM.entryVM.addWord(w)
    }

    ColumnLayout {
        id: _col
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
            height: Platform.touchTarget
            radius: Platform.radius
            color: Platform.bg
            border.color: wordInput.activeFocus ? Platform.accent : Platform.border
            border.width: wordInput.activeFocus ? 2 : 1

            TextField {
                id: wordInput
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                placeholderText: "e.g. ephemeral"
                font.pixelSize: Platform.fontBase
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


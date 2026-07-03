import TenjinView
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// "Add Word" dialog. On accept, the new entry is created and the dialog
// immediately navigates to that entry's detail page so the user can keep
// editing — saves a round-trip through the Words list (item #9 in the
// improvement plan).
ThemedDialog {
    id: root
    title: qsTr("Add Word")
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 400, 400) : 400
    padding: 24

    // Explicit centering — keeps the dialog from inheriting whatever
    // coordinates Overlay.overlay last held.
    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    onAboutToShow: {
        wordInput.text = ""
        wordInput.forceActiveFocus()
    }
    onAccepted: {
        const w = wordInput.text.trim()
        if (w.length === 0) return
        // addWord returns the new entry's id, or -1 on failure.
        const newId = appVM.entryVM.addWord(w)
        if (newId >= 0) {
            appVM.entryVM.selectEntry(newId)
            appVM.currentPage = 0  // PageWords — the entry list / detail page.
            // Drop straight into edit mode so the user can add content
            // blocks right away. beginEdit is a public slot on EntryViewModel.
            appVM.entryVM.beginEdit()
        }
    }

    ColumnLayout {
        id: _col
        width: parent.width
        spacing: 14

        Text {
            text: qsTr("Word")
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
            Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
            Behavior on border.width { NumberAnimation { duration: Platform.effDurationFast } }

            TextField {
                id: wordInput
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: qsTr("e.g. ephemeral")
                placeholderTextColor: Platform.textMuted
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                background: Rectangle { color: "transparent" }
                Keys.onReturnPressed: root.accept()
            }
        }

        Text {
            text: qsTr("We'll open the new word so you can add definitions, notes, and media right away.")
            font.pixelSize: Platform.fontSmall
            color: Platform.textMuted
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}



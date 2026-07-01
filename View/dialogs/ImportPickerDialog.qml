import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Cross-platform import picker. Avoids QtQuick.Dialogs.FileDialog
// entirely because the latter emits "no native option" on iOS (no
// platform picker available, no Quick fallback rendered).
//
// Lists JSON files currently in the app's Documents folder
// (appVM.documentsFolder). On desktop that's ~/Documents; on iOS that's
// the sandboxed Documents directory visible via the Files app — drop
// a tenjin-export-*.json file there and it shows up here. On accept,
// calls appVM.importFromPath(picked.path).
ThemedDialog {
    id: root
    title: qsTr("Import collection")
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 480, 480) : 480
    padding: 20

    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property var _files: []
    property string _selectedPath: ""

    onAboutToShow: {
        _files = appVM.availableImports()
        _selectedPath = ""
    }

    onAccepted: {
        if (_selectedPath.length > 0) appVM.importFromPath(_selectedPath)
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Text {
            Layout.fillWidth: true
            text: qsTr("Pick a Tenjin (.json) or Anki (.apkg) file from your Documents folder.")
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: appVM.documentsFolder
            color: Platform.textMuted
            font.pixelSize: Platform.fontTiny
            font.family: Platform.fontMono
            elide: Text.ElideMiddle
            wrapMode: Text.NoWrap
        }

        // File list.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(filesList.contentHeight + 8, 320)
            radius: Platform.radius
            color: Platform.bg
            border.color: Platform.border
            border.width: 1

            ListView {
                id: filesList
                anchors { fill: parent; margins: 4 }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: root._files

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool _selected: root._selectedPath === modelData.path
                    width: filesList.width
                    height: Platform.touchTarget + 8
                    radius: Platform.radius - 2
                    color: _selected ? Platform.accent
                         : fileHover.containsMouse ? Platform.surfaceAlt
                                                     : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8

                        Text {
                            text: TenjinIcons.document
                            font.family: TenjinIcons.family
                            font.pixelSize: Platform.fontLarge
                            color: parent.parent._selected ? Platform.bg : Platform.textMuted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: parent.parent.parent.modelData.name
                                color: parent.parent.parent.parent._selected ? Platform.textOnDark : Platform.textPrimary
                                font.pixelSize: Platform.fontBase
                                font.bold: parent.parent.parent.parent._selected
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                text: parent.parent.parent.modelData.modified +
                                      "  ·  " + parent.parent.parent.modelData.sizeStr
                                color: parent.parent.parent.parent._selected ? Platform.textOnDark : Platform.textMuted
                                font.pixelSize: Platform.fontSmall
                            }
                        }
                    }
                    MouseArea {
                        id: fileHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._selectedPath = parent.modelData.path
                        onDoubleClicked: { root._selectedPath = parent.modelData.path; root.accept() }
                    }
                }

                // Empty state.
                Column {
                    anchors.centerIn: parent
                    visible: filesList.count === 0
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: TenjinIcons.folder
                        font.family: TenjinIcons.family
                        font.pixelSize: 40
                        color: Platform.textMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No .json or .apkg files found.\n") +
                              "Drop one in your Documents folder, then reopen this dialog."
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    standardButtons: root._selectedPath.length > 0 ? (Dialog.Ok | Dialog.Cancel) : Dialog.Cancel
}



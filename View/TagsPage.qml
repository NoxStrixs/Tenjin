pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Tag management. Lists every tag with rename + delete. Tapping a tag's name
// filters the Words page to that tag and navigates there. Reached on mobile via
// the drawer (page index 2). On desktop, tag browsing stays in the sidebar
// tree, so currentPage never becomes 2 there and this page is inert.
Item {
    id: tagsPageRoot

    property var allTags: appVM.entryVM.getAllTags()
    function refresh() { allTags = appVM.entryVM.getAllTags() }

    Connections {
        target: appVM.entryVM
        function onEntryListChanged() { tagsPageRoot.refresh() }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Platform.pagePadding }
        spacing: 12

        Text {
            text: "Tags"
            color: Platform.textPrimary
            font.pixelSize: Platform.fontTitle
            font.bold: true
        }

        ListView {
            id: tagList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: tagsPageRoot.allTags

            delegate: Rectangle {
                id: tagRow
                required property var modelData
                width: ListView.view.width
                implicitHeight: Platform.touchTarget + 12
                radius: Platform.radius
                color: rowHover.hovered ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1

                HoverHandler { id: rowHover }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: tagRow.modelData.name
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appVM.entryVM.filterByTag(tagRow.modelData.id, tagRow.modelData.name)
                                appVM.currentPage = 0   // jump to Words, filtered
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: renameLabel.implicitWidth + 18
                        implicitHeight: Platform.touchTarget * 0.8
                        radius: Platform.radius
                        color: renameArea.containsMouse ? Platform.surfaceAlt : "transparent"
                        border.color: Platform.border
                        border.width: 1
                        Text { id: renameLabel; anchors.centerIn: parent; text: "Rename"; color: Platform.accentDark; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                        MouseArea {
                            id: renameArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: renameTagDialog.openFor(tagRow.modelData.id, tagRow.modelData.name)
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: delLabel.implicitWidth + 18
                        implicitHeight: Platform.touchTarget * 0.8
                        radius: Platform.radius
                        color: delArea.containsMouse ? Platform.danger : "transparent"
                        border.color: Platform.danger
                        border.width: 1
                        Text { id: delLabel; anchors.centerIn: parent; text: "Delete"; color: delArea.containsMouse ? Platform.textOnDark : Platform.danger; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                deleteTagConfirm.pendingId = tagRow.modelData.id
                                deleteTagConfirm.pendingName = tagRow.modelData.name
                                deleteTagConfirm.open()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 48
                visible: tagList.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No tags yet.\nTap + Tag to create one."
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
            }
        }
    }

    RenameTagDialog { id: renameTagDialog }

    ConfirmDialog {
        id: deleteTagConfirm
        property int pendingId: -1
        property string pendingName: ""
        message: "Delete tag \"" + pendingName + "\"? It will be removed from all words."
        onConfirmed: if (pendingId >= 0) appVM.entryVM.deleteTag(pendingId)
    }
}



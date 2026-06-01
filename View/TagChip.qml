import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Rectangle {
    id: root
    property string tagName: ""
    property int    tagId:   -1
    property bool   editable: false

    signal removeClicked(int tid)

    height: Platform.isMobile ? 36 : 24
    width:  row.implicitWidth + 16
    radius: height / 2
    color: Platform.surfaceAlt
    border.color: Platform.border
    border.width: 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.tagName
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase - 2
            font.bold: true
        }

        Text {
            visible: root.editable
            text: "✕"
            color: Platform.danger
            font.pixelSize: Platform.fontBase - 2
            font.bold: true

            MouseArea {
                anchors.fill: parent
                anchors.margins: Platform.isMobile ? -8 : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeClicked(root.tagId)
            }
        }
    }
}

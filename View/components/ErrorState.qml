import QtQuick
import QtQuick.Layouts
import TenjinView

// Reusable error placeholder: a warning icon, a title, an optional detail line,
// and an optional retry button. Shares EmptyState's layout so empty / loading /
// error read as one family.
//
// Usage:
//   ErrorState {
//       title: qsTr("Couldn't load news")
//       detail: qsTr("Check your connection and try again.")
//       retryText: qsTr("Retry")
//       onRetry: appVM.refreshNews()
//   }
Item {
    id: root

    property string icon:      TenjinIcons.warning
    property string title:     qsTr("Something went wrong")
    property string detail:    ""
    property string retryText: ""

    signal retry()

    implicitWidth:  parent ? parent.width : 280
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(root.width - Platform.pagePadding * 2, 360)
        spacing: Platform.spacingMd

        Text {
            visible: root.icon.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            font.family: TenjinIcons.family
            font.pixelSize: Platform.iconSizeHero
            color: Platform.danger
            opacity: 0.75
        }

        Text {
            visible: root.title.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.detail.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.detail
            color: Platform.textMuted
            font.pixelSize: Platform.fontBase
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: root.retryText.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Platform.spacingSm
            implicitWidth: retryLabel.implicitWidth + Platform.spacingXl * 2
            implicitHeight: Platform.touchTarget
            radius: Platform.radius
            color: retryArea.containsMouse ? Platform.accentDark : Platform.accent
            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

            Text {
                id: retryLabel
                anchors.centerIn: parent
                text: root.retryText
                color: Platform.bg
                font.pixelSize: Platform.fontBase
                font.bold: true
            }
            MouseArea {
                id: retryArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.retry()
            }
        }
    }
}

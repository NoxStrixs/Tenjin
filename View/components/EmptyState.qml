import QtQuick
import QtQuick.Layouts
import TenjinView

// Reusable empty-state placeholder: an icon, a title, an optional subtitle,
// and an optional call-to-action button. Used wherever a list or page has
// no content yet, to guide the user toward their first action.
//
// Usage:
//   EmptyState {
//       icon: TenjinIcons.words
//       title: qsTr("No words yet")
//       subtitle: qsTr("Add your first word to start building your collection.")
//       ctaText: qsTr("+ Word")
//       onCtaClicked: addEntryDialog.open()
//   }
Item {
    id: root

    property string icon:     ""
    property string title:    ""
    property string subtitle: ""
    property string ctaText:  ""

    signal ctaClicked()

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
            color: Platform.textMuted
            opacity: 0.55
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
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Text {
            visible: root.subtitle.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.subtitle
            color: Platform.textMuted
            font.pixelSize: Platform.fontBase
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }

        // CTA button
        Rectangle {
            visible: root.ctaText.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Platform.spacingSm
            implicitWidth: ctaLabel.implicitWidth + Platform.spacingXl * 2
            implicitHeight: Platform.touchTarget
            radius: Platform.radius
            color: ctaArea.pressed ? Qt.darker(Platform.accent, 1.15)
                 : ctaArea.containsMouse ? Qt.lighter(Platform.accent, 1.05)
                 : Platform.accent
            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
            scale: ctaArea.pressed ? 0.97 : 1.0
            Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }

            Accessible.role: Accessible.Button
            Accessible.name: root.ctaText
            Accessible.onPressAction: root.ctaClicked()

            Text {
                id: ctaLabel
                anchors.centerIn: parent
                text: root.ctaText
                color: Platform.bg
                font.pixelSize: Platform.fontBase
                font.bold: true
            }
            MouseArea {
                id: ctaArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.ctaClicked()
            }
        }
    }
}

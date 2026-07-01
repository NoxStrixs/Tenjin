import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import TenjinView

// A large centered "sheet" popup used to host secondary destinations (News,
// Help) as pop-outs instead of full pages — matching the language menu pattern.
// Hosts arbitrary content via its default property and provides a title bar with
// a close button. The content fills the area below the title.
Popup {
    id: root
    parent: Overlay.overlay
    modal: true
    dim: true
    padding: 0

    property string title: ""
    default property alias content: contentHost.data

    width:  Platform.isMobile ? Math.min((parent ? parent.width : 400) - 24, 560)
                              : Math.min((parent ? parent.width : 800) - 80, 720)
    height: Platform.isMobile ? (parent ? parent.height : 600) - Platform.safeAreaTop - Platform.safeAreaBottom - 48
                              : Math.min((parent ? parent.height : 600) - 80, 760)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? Math.max(Platform.safeAreaTop + 12, (parent.height - height) / 2) : 0

    background: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Title bar with close button.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + 12
            color: "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingSm }
                spacing: Platform.spacingMd
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
                Rectangle {
                    Layout.preferredWidth: Platform.touchTarget
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: closeArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: TenjinIcons.close
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontLarge
                        color: Platform.textMuted
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Platform.border
            }
        }

        // Content area — the embedded page fills this.
        Item {
            id: contentHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }
}

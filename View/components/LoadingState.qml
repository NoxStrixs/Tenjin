import QtQuick
import QtQuick.Layouts
import TenjinView

// Reusable loading placeholder: a lightweight spinner arc with an optional
// label. Matches EmptyState / ErrorState so the three states feel unified.
// The spinner only animates while visible (no idle cost) and is replaced by a
// static ring under Platform.reducedMotion.
//
// Usage:  LoadingState { label: qsTr("Loading decks…") }
Item {
    id: root

    property string label: qsTr("Loading…")
    property int size: Platform.iconSizeXl

    implicitWidth:  parent ? parent.width : 280
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: Platform.spacingMd

        Item {
            Layout.alignment: Qt.AlignHCenter
            width: root.size
            height: root.size

            // Full faint track.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: Platform.border
            }

            // Rotating accent arc, drawn cheaply with Canvas. Repaints once per
            // rotation frame only while running; static when reduced motion.
            Canvas {
                id: arc
                anchors.fill: parent
                rotation: 0
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var w = width, h = height, lw = 3
                    ctx.lineWidth = lw
                    ctx.strokeStyle = Platform.accent
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    // ~90° arc starting at top.
                    ctx.arc(w / 2, h / 2, (w - lw) / 2, -Math.PI / 2, 0)
                    ctx.stroke()
                }
                // Repaint when the accent colour changes (theme switch).
                Connections {
                    target: Platform
                    function onThemeChanged() { arc.requestPaint() }
                }
                RotationAnimator {
                    target: arc
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: !Platform.reducedMotion && root.visible
                }
            }
        }

        Text {
            visible: root.label.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: Platform.textMuted
            font.pixelSize: Platform.fontBase
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

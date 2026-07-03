import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import TenjinView

// Custom numeric stepper. Replaces QtQuick.Controls SpinBox so the control is
// visually consistent with the rest of the UI (no inherited native styling per
// the styling mandate). Wraps around at the bounds (useful for hour/minute
// fields). Emits valueModified(int) on user change only — not on programmatic
// `value` assignment — so bindings don't loop.
Item {
    id: root

    property int from: 0
    property int to: 59
    property int value: 0
    property int step: 1
    // Zero-pad to two digits by default (time fields); override for other uses.
    property bool padTwo: true

    signal valueModified(int newValue)

    function _wrap(v) {
        const span = root.to - root.from + 1
        if (v > root.to)   return root.from + ((v - root.from) % span)
        if (v < root.from) return root.to - ((root.from - v - 1) % span)
        return v
    }
    function _display(v) {
        return (root.padTwo && v < 10 ? "0" : "") + v
    }
    function _bump(delta) {
        const nv = _wrap(root.value + delta)
        if (nv !== root.value) {
            root.value = nv
            root.valueModified(nv)
        }
    }

    implicitWidth: stepRow.implicitWidth
    implicitHeight: Platform.touchTarget

    RowLayout {
        id: stepRow
        anchors.fill: parent
        spacing: 0

        component StepButton: Rectangle {
            id: sb
            property string glyph: ""
            signal tapped()
            Layout.preferredWidth: Platform.touchTarget
            Layout.fillHeight: true
            color: sbArea.pressed ? Platform.accent
                 : sbArea.containsMouse ? Platform.surfaceAlt : Platform.surface
            border.color: Platform.border
            border.width: Platform.borderWidth
            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
            Text {
                anchors.centerIn: parent
                text: sb.glyph
                font.family: TenjinIcons.family
                font.pixelSize: Platform.fontLarge
                color: sbArea.pressed ? Platform.textOnDark : Platform.textPrimary
            }
            MouseArea {
                id: sbArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sb.tapped()
                // Hold-to-repeat for fast adjustment.
                property int _held: 0
                Timer {
                    id: repeatTimer
                    interval: 110; repeat: true
                    onTriggered: sb.tapped()
                }
                onPressed: { repeatDelay.restart() }
                onReleased: { repeatDelay.stop(); repeatTimer.stop() }
                onCanceled: { repeatDelay.stop(); repeatTimer.stop() }
                Timer { id: repeatDelay; interval: 350; onTriggered: repeatTimer.start() }
            }
        }

        StepButton {
            glyph: TenjinIcons.remove
            // Left cell: round the outer corners only.
            radius: 0
            onTapped: root._bump(-root.step)
        }

        Rectangle {
            Layout.preferredWidth: Math.max(48, valueText.implicitWidth + Platform.spacingMd * 2)
            Layout.fillHeight: true
            color: Platform.bg
            border.color: Platform.border
            border.width: Platform.borderWidth
            Text {
                id: valueText
                anchors.centerIn: parent
                text: root._display(root.value)
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.family: Platform.fontMono
            }
        }

        StepButton {
            glyph: TenjinIcons.add
            onTapped: root._bump(root.step)
        }
    }
}

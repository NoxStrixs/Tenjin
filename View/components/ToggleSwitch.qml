import QtQuick
import TenjinView

// App-styled on/off toggle, extracted from the duplicated Settings switches
// (theme, reduced motion). Pure visual + a toggled() signal; the caller owns
// the state. Honors reduced motion (knob slide animation collapses to instant).
//
// Usage:
//   ToggleSwitch { checked: appVM.reducedMotion; onToggled: appVM.setReducedMotion(!appVM.reducedMotion) }
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 52
    implicitHeight: 28
    radius: height / 2
    color: checked ? Platform.accent : Platform.border
    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

    Rectangle {
        id: knob
        width: 22
        height: 22
        radius: height / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: Platform.bg
        Behavior on x {
            NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}

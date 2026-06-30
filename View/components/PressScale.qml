import QtQuick
import TenjinView

// Subtle press feedback: wrap or attach to a tappable item to make it scale
// down slightly while pressed, springing back on release. Gives mobile taps a
// responsive, physical feel. No-op under Platform.reducedMotion.
//
// Two ways to use it:
//
// 1. As the MouseArea itself (simplest) — it scales its `target`:
//      Rectangle {
//          id: card
//          PressScale { anchors.fill: parent; target: card; onTapped: open() }
//      }
//
// 2. Drive `pressed` yourself from an existing MouseArea/TapHandler:
//      PressScale { target: card; pressed: myArea.pressed }
MouseArea {
    id: root

    // Item to scale. Defaults to the parent.
    property Item target: parent
    // Scale applied while pressed.
    property real pressedScale: 0.97
    // External press driver. If using this as the MouseArea, leave as-is.
    property bool pressed: root.containsPress

    signal tapped()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.tapped()

    onPressedChanged: _apply()
    Component.onCompleted: _apply()

    function _apply() {
        if (!target)
            return
        var to = (pressed && !Platform.reducedMotion) ? pressedScale : 1.0
        target.transformOrigin = Item.Center
        if (Platform.reducedMotion) {
            target.scale = to
        } else {
            scaleAnim.target = target
            scaleAnim.to = to
            scaleAnim.restart()
        }
    }

    NumberAnimation {
        id: scaleAnim
        property: "scale"
        duration: Platform.effDurationFast
        easing.type: Easing.OutCubic
    }
}

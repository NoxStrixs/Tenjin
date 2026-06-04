import QtQuick
import QtQuick.Layouts
import TenjinView

// A square icon button for the top bar. Emits activated() on click and exposes
// hovered so callers can drive hover popups.
Rectangle {
    id: ib
    property string glyph: ""
    property bool   active: false
    property alias  hovered: ibArea.containsMouse
    signal activated()

    Layout.preferredWidth: Math.round(Platform.touchTarget * 0.9)
    Layout.preferredHeight: Math.round(Platform.touchTarget * 0.9)
    radius: Platform.radius
    color: ibArea.containsMouse || active ? Platform.surfaceAlt : "transparent"
    border.color: active ? Platform.accent : "transparent"
    border.width: 1

    Behavior on color        { ColorAnimation { duration: Platform.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }

    // Slight press feedback. Falls back to 1.0 when not pressed.
    scale: ibArea.pressed ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: ib.glyph
        color: ib.active ? Platform.accent : Platform.textMuted
        font.pixelSize: Platform.fontLarge
        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
    }
    MouseArea {
        id: ibArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ib.activated()
    }
}


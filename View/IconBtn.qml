import QtQuick
import QtQuick.Layouts
import TenjinView

// A square icon button for the top bar. Emits activated() on click and exposes
// hovered so callers can drive hover popups (e.g. the About info card).
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

    Text {
        anchors.centerIn: parent
        text: ib.glyph
        color: ib.active ? Platform.accent : Platform.textMuted
        font.pixelSize: Platform.fontLarge
    }
    MouseArea {
        id: ibArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ib.activated()
    }
}

import QtQuick
import QtQuick.Controls
import TenjinView

Button {
    id: control

    property string variant: "neutral"

    // Button maps `text` to Accessible.name automatically.
    Accessible.role: Accessible.Button
    Accessible.name: control.text

    implicitHeight: Platform.touchTarget

    readonly property color _bg: variant === "primary" ? Platform.accent
                               : variant === "success" ? Platform.success
                               : variant === "danger"  ? Platform.danger
                                                        : Platform.surfaceAlt
    readonly property color _fg: (variant === "neutral") ? Platform.textPrimary
                                                          : Platform.textOnDark
    readonly property bool _bordered: variant === "neutral"

    // Press feedback — scale slightly down on press for tactile feel.
    scale: control.down ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }

    background: Rectangle {
        color: control.down ? Qt.darker(control._bg, 1.15)
             : control.hovered ? Qt.lighter(control._bg, 1.05)
             : control._bg
        radius: Platform.radius
        border.color: Platform.border
        border.width: control._bordered ? 1 : 0
        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
    }

    contentItem: Text {
        text: control.text
        color: control._fg
        font.pixelSize: Platform.fontBase
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        leftPadding: 8
        rightPadding: 8
    }
}


import QtQuick
import QtQuick.Controls
import TenjinView

Button {
    id: control

    property string variant: "neutral"

    implicitHeight: Platform.touchTarget

    readonly property color _bg: variant === "primary" ? Platform.accent
                               : variant === "success" ? Platform.success
                               : variant === "danger"  ? Platform.danger
                                                        : Platform.surfaceAlt
    readonly property color _fg: (variant === "neutral") ? Platform.textPrimary
                                                          : Platform.textOnDark
    readonly property bool _bordered: variant === "neutral"

    background: Rectangle {
        color: control.down ? Qt.darker(control._bg, 1.15) : control._bg
        radius: Platform.radius
        border.color: Platform.border
        border.width: control._bordered ? 1 : 0
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


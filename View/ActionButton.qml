import QtQuick
import QtQuick.Controls
import TenjinView

// A small themed text button used in page headers. Centralizes the styling so
// pages don't repeat background/contentItem blocks (and avoids the `parent.text`
// pattern, which QML's static checker can't resolve).
Button {
    id: control

    // Visual variant: "neutral" (surface), "primary" (accent),
    // "success", or "danger".
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


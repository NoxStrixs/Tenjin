import QtQuick
import QtQuick.Controls.Basic
import TenjinView

// A themed Dialog base:
//  themed header bar,
//  themed OK/Cancel
//  footer,
//  when the on-screen keyboard is up it caps its own height and sits in the top region so its buttons are never
//  covered by the keyboard.
//  Stays horizontally centered.

Dialog {
    id: root
    modal: true

    property string okText: "OK"
    property string cancelText: "Cancel"
    standardButtons: Dialog.Ok | Dialog.Cancel

    // Tapping the dimmed area outside (CloseOnPressOutside is default for modal)
    // dismisses the keyboard too.
    onClosed: Qt.inputMethod.hide()

    // Keyboard height in device-independent px (0 when hidden).
    // Platform.devicePixelRatio routes through Qt.application.screens so we
    // don't pull QtQuick.Window's Screen singleton (which won't link reliably
    // on the iOS static build).
    readonly property real _kb: Qt.inputMethod.visible
        ? Qt.inputMethod.keyboardRectangle.height / Platform.devicePixelRatio
        : 0

    // Sit near the top when the keyboard is up; otherwise vertically centered.
    x: Math.round((parent.width - width) / 2)
    y: _kb > 0
       ? Platform.headerHeight
       : Math.round((parent.height - height) / 2)

    // Never let the dialog extend under the keyboard: cap height to the space
    // above it. The content scrolls if it doesn't fit.
    readonly property real _avail: (parent ? parent.height : 0) - _kb - Platform.headerHeight * 2
    height: Math.min(implicitHeight, _avail > 120 ? _avail : implicitHeight)

    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // Snappy fade-and-rise enter / fade-and-sink exit. Subclasses inherit this
    // automatically — every Add*/Confirm/Rename dialog now lands the same way.
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0;    to: 1; duration: Platform.effDurationMed }
            NumberAnimation { property: "scale";   from: 0.96; to: 1; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0;    duration: Platform.effDurationFast }
            NumberAnimation { property: "scale";   from: 1; to: 0.97; duration: Platform.effDurationFast }
        }
    }

    background: Rectangle {
        implicitWidth: 320
        implicitHeight: 120
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
        MouseArea {
            anchors.fill: parent
            onClicked: { root.forceActiveFocus(); Qt.inputMethod.hide() }
        }
    }

    header: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        implicitHeight: _hdrText.implicitHeight + 24
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: Platform.surface }
        Text {
            id: _hdrText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Platform.border }
    }

    footer: DialogButtonBox {
        padding: 16
        spacing: 8
        alignment: Qt.AlignRight
        background: Rectangle { color: "transparent" }

        delegate: Button {
            id: _btn
            implicitHeight: Platform.touchTarget
            implicitWidth: Math.max(88, _btnText.implicitWidth + 28)
            padding: 10
            scale: _btn.down ? 0.97 : 1.0
            Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
            contentItem: Text {
                id: _btnText
                text: _btn.text
                color: _btn.down ? Platform.textOnDark : Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Platform.radius
                color: _btn.down ? Platform.accent
                     : _btn.hovered ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
            }
        }
    }
}


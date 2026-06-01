import QtQuick
import QtQuick.Controls
import TenjinView

// A themed Dialog base: dark background, themed header bar, themed OK/Cancel
// footer (no white system button bar), and — on mobile — it lifts above the
// on-screen keyboard instead of being covered by it. Keeps the dialog centered
// horizontally; vertically it sits in the upper area when the keyboard is up.
//
// Usage: set `title`, optionally `okText`/`cancelText`, put content as children,
// and handle onAccepted/onRejected as usual.
Dialog {
    id: root
    modal: true

    property string okText: "OK"
    property string cancelText: "Cancel"

    // Horizontal centering always; vertical position reacts to the keyboard.
    x: Math.round((parent.width - width) / 2)
    y: {
        const kb = Qt.inputMethod.visible
                   ? Qt.inputMethod.keyboardRectangle.height / Screen.devicePixelRatio
                   : 0
        if (kb > 0) {
            // Keyboard up: sit in the upper area, fully above the keyboard.
            const avail = parent.height - kb
            return Math.max(Platform.headerHeight,
                            Math.round(avail / 2 - height / 2))
        }
        return Math.round((parent.height - height) / 2)
    }
    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    background: Rectangle {
        color: Platform.bg
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
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

        Button {
            text: root.cancelText
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: root.okText
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }

        delegate: Button {
            id: _btn
            implicitHeight: Platform.touchTarget
            padding: 10
            contentItem: Text {
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
            }
        }
    }
}


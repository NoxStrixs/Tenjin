import QtQuick
import QtQuick.Controls.Basic
import TenjinView

// App-consistent ComboBox skin. Extracted from the language-filter combo so
// every picker shares one style instead of duplicating ~70 lines. Callers set
// model / textRole / valueRole / delegate / onActivated as usual; override the
// delegate when a richer row is needed (e.g. flags + name).
ComboBox {
    id: control
    font.pixelSize: Platform.fontBase

    background: Rectangle {
        radius: Platform.radius
        color: Platform.surface
        border.color: control.activeFocus ? Platform.accent : Platform.border
        border.width: control.activeFocus ? 2 : 1
        Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
    }

    contentItem: Text {
        leftPadding: 12
        rightPadding: control.indicator.width + 6
        text: control.displayText
        color: Platform.textPrimary
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: Platform.spacingLg
        }
        text: "\u25BE"
        color: Platform.textMuted
        font.pixelSize: Platform.fontBase
    }

    popup: Popup {
        y: control.height + 2
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight, 320)
        padding: 1
        background: Rectangle {
            color: Platform.surface
            radius: Platform.radius
            border.color: Platform.border
            border.width: 1
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }

    // Default text-only delegate. Expects modelData.label; override for flags.
    delegate: ItemDelegate {
        id: del
        required property var modelData
        required property int index
        width: control.width
        height: 32
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            leftPadding: 10
            text: del.modelData.label !== undefined ? del.modelData.label
                                                    : del.modelData
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: del.highlighted ? Platform.surfaceAlt : "transparent"
        }
    }
}

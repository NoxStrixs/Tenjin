import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

Rectangle {
    id: chip

    property string tagName:     ""
    property int    tagId:       -1
    property bool   active:      false
    property bool   interactive: false
    property bool   removable:   false
    property bool   editable:    false   // legacy alias for `removable`
    property bool   compact:     false

    signal clicked()
    signal removeClicked(int tid)

    readonly property bool _showRemove: removable || editable
    readonly property int  _h: compact ? Platform.chipHeightSm : Platform.chipHeight
    readonly property int  _fontPx: compact ? Platform.fontTiny : Platform.fontSmall
    readonly property bool _hovered: interactive && bodyArea.containsMouse

    implicitHeight: _h
    implicitWidth:  row.implicitWidth + 2 * Platform.chipPaddingH
    radius: _h / 2

    color:        active ? Platform.accent
               : _hovered ? Platform.surfaceAlt
                          : Platform.surface
    border.color: active ? Platform.accent : Platform.border
    border.width: Platform.borderWidth

    Behavior on color        { ColorAnimation { duration: Platform.effDurationFast } }
    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }

    // Subtle press feedback for tappable chips. No-op when non-interactive.
    scale: chip.interactive && bodyArea.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }

    // bodyArea is declared FIRST so it sits behind the row's children.
    MouseArea {
        id: bodyArea
        anchors.fill: parent
        enabled: chip.interactive
        hoverEnabled: chip.interactive
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: chip.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Platform.spacingSm

        Text {
            text: chip.tagName
            color: chip.active ? Platform.textOnDark
                               : (chip._hovered ? Platform.textPrimary : Platform.accentDark)
            font.pixelSize: chip._fontPx
            font.bold: chip.active
            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
        }

        // ✕ button — only when removable/editable.
        Item {
            visible: chip._showRemove
            Layout.preferredWidth: removeText.implicitWidth
            Layout.preferredHeight: removeText.implicitHeight
            Text {
                id: removeText
                anchors.centerIn: parent
                text: "✕"
                color: chip.active ? Platform.textOnDark : Platform.danger
                font.pixelSize: chip._fontPx
                font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                // Mobile gets a slightly larger hit zone so the ✕ is
                // actually tappable next to text.
                anchors.margins: Platform.isMobile ? -Platform.spacingMd : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.removeClicked(chip.tagId)
            }
        }
    }
}


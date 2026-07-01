import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import TenjinView

// Cross-platform HSV + hex colour picker. Pure QtQuick — no native ColorDialog
// (which does not exist on iOS/Android). Emits `picked(color)` when the user
// commits. Business rule (hex validation/persistence) lives in AppViewModel;
// this component only gathers a colour and reports it.
Popup {
    id: root
    parent: Overlay.overlay
    modal: true
    dim: true
    anchors.centerIn: Overlay.overlay
    width: Platform.isMobile ? Math.min((parent ? parent.width : 360) - 32, 340) : 340
    padding: Platform.spacingLg
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Inbound: the colour being edited. Outbound: picked(color).
    property color initial: "#d4a373"
    property string title: qsTr("Pick a colour")
    signal picked(color chosen)

    // HSV working state (0..1).
    property real _h: 0
    property real _s: 0
    property real _v: 1
    property bool _syncing: false

    function _fromColor(c) {
        _syncing = true
        _h = c.hsvHue    < 0 ? 0 : c.hsvHue
        _s = c.hsvSaturation
        _v = c.hsvValue
        hexField.text = _toHex()
        _syncing = false
    }
    function _current() { return Qt.hsva(_h, _s, _v, 1) }
    function _toHex() {
        var c = _current()
        function h2(x) { var s = Math.round(x * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return "#" + h2(c.r) + h2(c.g) + h2(c.b)
    }

    onAboutToShow: _fromColor(initial)

    background: Rectangle {
        implicitWidth: root.width
        implicitHeight: pickerCol.implicitHeight + Platform.spacingLg * 2
        color: Platform.surface
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: Platform.borderWidth
    }

    contentItem: ColumnLayout {
        id: pickerCol
        spacing: Platform.spacingMd

        Text {
            text: root.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            font.bold: true
        }

        // ── Saturation / Value plane ────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 160

            Rectangle {
                id: svPlane
                anchors.fill: parent
                radius: Platform.radius
                // Base hue, white overlaid left→right, black overlaid top→bottom.
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ffffff" }
                    GradientStop { position: 1.0; color: Qt.hsva(root._h, 1, 1, 1) }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#ff000000" }
                    }
                }
                // Selector reticle.
                Rectangle {
                    width: 16; height: 16; radius: 8
                    border.color: "#ffffff"; border.width: 2
                    color: "transparent"
                    x: root._s * (svPlane.width - width)
                    y: (1 - root._v) * (svPlane.height - height)
                    Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: "transparent"; border.color: "#000000"; border.width: 1 }
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: (m) => _update(m)
                    onPositionChanged: (m) => { if (pressed) _update(m) }
                    function _update(m) {
                        root._s = Math.max(0, Math.min(1, m.x / width))
                        root._v = Math.max(0, Math.min(1, 1 - m.y / height))
                        if (!root._syncing) hexField.text = root._toHex()
                    }
                }
            }
        }

        // ── Hue strip ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Rectangle {
                id: hueStrip
                anchors.fill: parent
                radius: Platform.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: "#ff0000" }
                    GradientStop { position: 0.167; color: "#ffff00" }
                    GradientStop { position: 0.333; color: "#00ff00" }
                    GradientStop { position: 0.500; color: "#00ffff" }
                    GradientStop { position: 0.667; color: "#0000ff" }
                    GradientStop { position: 0.833; color: "#ff00ff" }
                    GradientStop { position: 1.000; color: "#ff0000" }
                }
                Rectangle {
                    width: 6; height: parent.height + 4; y: -2
                    x: root._h * (hueStrip.width - width)
                    color: "transparent"; border.color: "#ffffff"; border.width: 2; radius: 3
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: (m) => _update(m)
                    onPositionChanged: (m) => { if (pressed) _update(m) }
                    function _update(m) {
                        root._h = Math.max(0, Math.min(0.999, m.x / width))
                        if (!root._syncing) hexField.text = root._toHex()
                    }
                }
            }
        }

        // ── Hex field + live preview ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Platform.spacingMd

            Rectangle {
                Layout.preferredWidth: Platform.touchTarget
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: root._current()
                border.color: Platform.border
                border.width: Platform.borderWidth
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                placeholderText: "#rrggbb"
                color: Platform.textPrimary
                placeholderTextColor: Platform.textMuted
                font.pixelSize: Platform.fontBase
                background: Rectangle {
                    color: Platform.bg
                    radius: Platform.radius
                    border.color: Platform.border
                    border.width: Platform.borderWidth
                }
                // Manual hex entry drives the HSV state.
                onEditingFinished: {
                    var c = Qt.color(text)
                    if (c.a > 0 || text.length > 0) {
                        // Qt.color returns an invalid (fully transparent black)
                        // colour for bad input; guard against that.
                        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(text))
                            root._fromColor(Qt.color(text))
                    }
                }
            }
        }

        // ── Actions ─────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Platform.spacingSm

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Cancel")
                implicitHeight: Platform.touchTarget
                onClicked: root.close()
                background: Rectangle { radius: Platform.radius; color: cancelHover.hovered ? Platform.surfaceAlt : "transparent"; border.color: Platform.border; border.width: Platform.borderWidth }
                HoverHandler { id: cancelHover }
                contentItem: Text { text: parent.text; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: qsTr("Apply")
                implicitHeight: Platform.touchTarget
                onClicked: { root.picked(root._current()); root.close() }
                background: Rectangle { radius: Platform.radius; color: Platform.accent }
                contentItem: Text { text: parent.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
}

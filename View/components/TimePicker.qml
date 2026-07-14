pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Time picker. Native OS wheel picker on iOS/Android (tap the time to open it);
// inline text entry on desktop. 12h/24h follows the device locale. Emits
// timeModified(hour, minute) on user change; hour/minute are 24h.
//
// The native picker (timePicker context object, a TimePickerService) is
// presented on tap via pickTime(); its timePicked signal updates the value.
// One native picker exists at a time, so this connects to the shared service.
Item {
    id: root

    property int hour: 0
    property int minute: 0
    signal timeModified(int hour, int minute)

    readonly property bool use12h:
        Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1
    readonly property bool _native: Platform.isMobile && timePicker.hasNativePicker()

    implicitWidth: _native ? 120 : (use12h ? 150 : 110)
    implicitHeight: Platform.touchTarget

    function _fmt(h24, m) {
        var mm = String(m).padStart(2, "0")
        if (!use12h) return String(h24).padStart(2, "0") + ":" + mm
        var pm = h24 >= 12
        var h = h24 % 12; if (h === 0) h = 12
        return String(h) + ":" + mm + " " + (pm ? qsTr("PM") : qsTr("AM"))
    }

    // ── Native (mobile): a tappable field that opens the OS picker ────────────
    Loader {
        anchors.fill: parent
        active: root._native
        sourceComponent: Rectangle {
            radius: Platform.radius
            color: tapArea.pressed ? Platform.surfaceAlt : Platform.bg
            border.color: Platform.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root._fmt(root.hour, root.minute)
                font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
            }
            MouseArea {
                id: tapArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root._awaiting = true
                    timePicker.pickTime(root.hour, root.minute)
                }
            }
        }
    }

    // Guard so only the picker instance that initiated the request consumes the
    // shared service's result.
    property bool _awaiting: false
    Connections {
        target: timePicker
        enabled: root._native
        function onTimePicked(h, m) {
            if (!root._awaiting) return
            root._awaiting = false
            root.hour = h; root.minute = m
            root.timeModified(h, m)
        }
        function onPickCancelled() { root._awaiting = false }
    }

    // ── Desktop: inline text entry ────────────────────────────────────────────
    Loader {
        anchors.fill: parent
        active: !root._native
        sourceComponent: Row {
            spacing: 6

            component TimeField: Rectangle {
                id: timeField
                property alias text: field.text
                property int lo: 0
                property int hi: 59
                signal committed(int value)
                width: 44
                height: Platform.touchTarget
                radius: Platform.radius
                color: Platform.bg
                border.color: field.activeFocus ? Platform.accent : Platform.border
                TextField {
                    id: field
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                    font.pixelSize: Platform.fontBase
                    color: Platform.textPrimary
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: timeField.lo; top: timeField.hi }
                    background: null
                    onEditingFinished: timeField.committed(parseInt(text || "0"))
                }
            }

            TimeField {
                lo: root.use12h ? 1 : 0
                hi: root.use12h ? 12 : 23
                text: {
                    var h = root.hour
                    if (root.use12h) { h = h % 12; if (h === 0) h = 12 }
                    return String(h).padStart(2, "0")
                }
                onCommitted: (v) => {
                    var h24 = v
                    if (root.use12h) {
                        var pm = root.hour >= 12
                        h24 = (v % 12) + (pm ? 12 : 0)
                    }
                    root.hour = h24
                    root.timeModified(root.hour, root.minute)
                }
            }
            Text {
                text: ":"; color: Platform.textPrimary; height: Platform.touchTarget
                font.pixelSize: Platform.fontBase
                verticalAlignment: Text.AlignVCenter
            }
            TimeField {
                lo: 0; hi: 59
                text: String(root.minute).padStart(2, "0")
                onCommitted: (v) => {
                    root.minute = Math.min(59, v)
                    root.timeModified(root.hour, root.minute)
                }
            }
            Button {
                visible: root.use12h
                height: Platform.touchTarget
                text: (root.hour >= 12) ? qsTr("PM") : qsTr("AM")
                onClicked: {
                    root.hour = (root.hour + 12) % 24
                    root.timeModified(root.hour, root.minute)
                }
                background: Rectangle { radius: Platform.radius; color: Platform.surfaceAlt; border.color: Platform.border }
                contentItem: Text {
                    text: parent.text
                    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                    color: Platform.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}

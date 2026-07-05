pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Reusable time picker. Mobile: dual Tumbler wheels with explicit sizing.
// Desktop: text entry (no +/- buttons). 12h/24h follows the system locale.
// Emits timeModified(hour, minute) on user change only; hour/minute are 24h.
//
// All dimensions are explicit (no Layout.fillHeight): a Tumbler resolves to
// zero height when its Layout parent is unconstrained (as under a Loader that
// anchors.fill a zero-content Item), which renders no wheel. Fixed heights
// guarantee the wheels appear on every platform.
Item {
    id: root

    property int hour: 0        // 0-23
    property int minute: 0      // 0-59
    signal timeModified(int hour, int minute)

    readonly property bool use12h:
        Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1

    // Explicit wheel geometry (mobile).
    readonly property int _wheelH: 132
    readonly property int _wheelW: 60
    readonly property int _rowH: Platform.isMobile ? _wheelH : Platform.touchTarget

    implicitWidth: Platform.isMobile ? (use12h ? 210 : 150) : 160
    implicitHeight: _rowH

    function _displayHour(h24) {
        if (!use12h) return h24
        var h = h24 % 12
        return h === 0 ? 12 : h
    }
    function _isPm(h24) { return h24 >= 12 }
    function _to24(displayHour, pm) {
        if (!use12h) return displayHour
        var h = displayHour % 12
        return pm ? h + 12 : h
    }

    // Shared Tumbler delegate factory via inline Component.
    component WheelText: Text {
        required property int index
        required property bool current
        font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
        font.pixelSize: Platform.fontLarge
        color: current ? Platform.accent : Platform.textMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: current ? 1.0 : 0.45
    }

    // ── Mobile: Tumbler wheels ────────────────────────────────────────────────
    Component {
        id: mobilePicker
        Row {
            spacing: 6

            Tumbler {
                id: hourTumbler
                width: root._wheelW
                height: root._wheelH
                model: root.use12h ? 12 : 24
                visibleItemCount: 3
                wrap: true
                currentIndex: root.use12h ? (root._displayHour(root.hour) - 1) : root.hour
                background: Rectangle {
                    radius: Platform.radius
                    color: Platform.surfaceAlt
                    border.color: Platform.border
                }
                delegate: WheelText {
                    text: root.use12h ? String(index + 1) : String(index).padStart(2, "0")
                }
                onCurrentIndexChanged: {
                    var dh = root.use12h ? currentIndex + 1 : currentIndex
                    var h24 = root._to24(dh, root._isPm(root.hour))
                    if (h24 !== root.hour) { root.hour = h24; root.timeModified(root.hour, root.minute) }
                }
            }

            Text {
                text: ":"
                height: root._wheelH
                font.pixelSize: Platform.fontLarge
                font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                color: Platform.textPrimary
                verticalAlignment: Text.AlignVCenter
            }

            Tumbler {
                id: minuteTumbler
                width: root._wheelW
                height: root._wheelH
                model: 60
                visibleItemCount: 3
                wrap: true
                currentIndex: root.minute
                background: Rectangle {
                    radius: Platform.radius
                    color: Platform.surfaceAlt
                    border.color: Platform.border
                }
                delegate: WheelText {
                    text: String(index).padStart(2, "0")
                }
                onCurrentIndexChanged: {
                    if (currentIndex !== root.minute) {
                        root.minute = currentIndex
                        root.timeModified(root.hour, root.minute)
                    }
                }
            }

            // AM/PM toggle (12h only).
            Button {
                visible: root.use12h
                width: 52
                height: root._wheelH
                text: root._isPm(root.hour) ? qsTr("PM") : qsTr("AM")
                onClicked: {
                    var dh = root._displayHour(root.hour)
                    root.hour = root._to24(dh, !root._isPm(root.hour))
                    root.timeModified(root.hour, root.minute)
                }
                background: Rectangle {
                    radius: Platform.radius
                    color: Platform.surfaceAlt
                    border.color: Platform.border
                }
                contentItem: Text {
                    text: parent.text
                    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                    font.pixelSize: Platform.fontBase
                    color: Platform.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── Desktop: text entry ───────────────────────────────────────────────────
    Component {
        id: desktopPicker
        Row {
            spacing: 6

            component TimeField: Rectangle {
                property alias text: field.text
                property int lo: 0
                property int hi: 59
                signal committed(int value)
                width: 46
                height: Platform.touchTarget
                radius: Platform.radius
                color: Platform.surfaceAlt
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
                    validator: IntValidator { bottom: parent.lo; top: parent.hi }
                    background: null
                    onEditingFinished: parent.committed(parseInt(text || "0"))
                }
            }

            TimeField {
                lo: root.use12h ? 1 : 0
                hi: root.use12h ? 12 : 23
                text: String(root._displayHour(root.hour)).padStart(2, "0")
                onCommitted: (v) => {
                    root.hour = root._to24(v, root._isPm(root.hour))
                    root.timeModified(root.hour, root.minute)
                }
            }
            Text {
                text: ":"; color: Platform.textPrimary
                height: Platform.touchTarget
                font.pixelSize: Platform.fontBase
                font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
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
                text: root._isPm(root.hour) ? qsTr("PM") : qsTr("AM")
                onClicked: {
                    var dh = root._displayHour(root.hour)
                    root.hour = root._to24(dh, !root._isPm(root.hour))
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

    Loader {
        id: pickerLoader
        // Size to content, centered — no anchors.fill (which gave the Layout
        // child zero height under a zero-content Item).
        anchors.centerIn: parent
        sourceComponent: Platform.isMobile ? mobilePicker : desktopPicker
    }
}

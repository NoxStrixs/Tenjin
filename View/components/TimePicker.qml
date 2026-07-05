pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Reusable time picker. Mobile: dual Tumbler wheels (touch-friendly). Desktop:
// text entry (no +/- buttons). 12h/24h follows the system locale. Emits
// timeModified(hour, minute) on user change only; `hour`/`minute` are 24h.
//
// Business logic (locale format detection) is read from Qt.locale() — a
// presentation concern, kept in QML per the architecture split.
Item {
    id: root

    property int hour: 0        // 0-23
    property int minute: 0      // 0-59
    signal timeModified(int hour, int minute)

    // 12h if the locale's time format contains an AM/PM designator.
    readonly property bool use12h: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1

    implicitWidth: Platform.isMobile ? 220 : 160
    implicitHeight: Platform.isMobile ? 160 : Platform.touchTarget

    // Convert 24h -> display hour for 12h mode.
    function _displayHour(h24) {
        if (!use12h) return h24
        var h = h24 % 12
        return h === 0 ? 12 : h
    }
    function _isPm(h24) { return h24 >= 12 }
    // Compose 24h from a 12h display hour + am/pm.
    function _to24(displayHour, pm) {
        if (!use12h) return displayHour
        var h = displayHour % 12
        return pm ? h + 12 : h
    }

    // ── Mobile: Tumbler wheels ────────────────────────────────────────────────
    Component {
        id: mobilePicker
        RowLayout {
            spacing: 4

            Tumbler {
                id: hourTumbler
                Layout.fillHeight: true
                Layout.preferredWidth: 64
                model: root.use12h ? 12 : 24
                currentIndex: root.use12h ? (root._displayHour(root.hour) - 1) : root.hour
                visibleItemCount: 3
                delegate: Text {
                    required property int index
                    required property bool current
                    text: root.use12h ? (index + 1) : String(index).padStart(2, "0")
                    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                    font.pixelSize: Platform.fontLarge
                    color: current ? Platform.accent : Platform.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    opacity: current ? 1.0 : 0.5
                }
                onCurrentIndexChanged: {
                    var dh = root.use12h ? currentIndex + 1 : currentIndex
                    var h24 = root._to24(dh, root._isPm(root.hour))
                    if (h24 !== root.hour) { root.hour = h24; root.timeModified(root.hour, root.minute) }
                }
            }

            Text {
                text: ":"
                font.pixelSize: Platform.fontLarge
                color: Platform.textPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            Tumbler {
                id: minuteTumbler
                Layout.fillHeight: true
                Layout.preferredWidth: 64
                model: 60
                currentIndex: root.minute
                visibleItemCount: 3
                delegate: Text {
                    required property int index
                    required property bool current
                    text: String(index).padStart(2, "0")
                    font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                    font.pixelSize: Platform.fontLarge
                    color: current ? Platform.accent : Platform.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    opacity: current ? 1.0 : 0.5
                }
                onCurrentIndexChanged: {
                    if (currentIndex !== root.minute) { root.minute = currentIndex; root.timeModified(root.hour, root.minute) }
                }
            }

            // AM/PM toggle (12h only).
            Button {
                visible: root.use12h
                Layout.alignment: Qt.AlignVCenter
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
        RowLayout {
            spacing: 6

            component TimeField: TextField {
                property int maxVal: 59
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignHCenter
                font.family: Platform.fontFamily !== "" ? Platform.fontFamily : font.family
                font.pixelSize: Platform.fontBase
                color: Platform.textPrimary
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 59 }
                background: Rectangle {
                    radius: Platform.radius
                    color: Platform.surfaceAlt
                    border.color: parent && parent.activeFocus ? Platform.accent : Platform.border
                }
            }

            TimeField {
                id: hourField
                maxVal: root.use12h ? 12 : 23
                text: String(root._displayHour(root.hour)).padStart(2, "0")
                validator: IntValidator { bottom: root.use12h ? 1 : 0; top: root.use12h ? 12 : 23 }
                onEditingFinished: {
                    var v = parseInt(text || "0")
                    root.hour = root._to24(v, root._isPm(root.hour))
                    root.timeModified(root.hour, root.minute)
                }
            }
            Text { text: ":"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; Layout.alignment: Qt.AlignVCenter }
            TimeField {
                id: minuteField
                text: String(root.minute).padStart(2, "0")
                onEditingFinished: {
                    root.minute = Math.min(59, parseInt(text || "0"))
                    root.timeModified(root.hour, root.minute)
                }
            }
            Button {
                visible: root.use12h
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
        anchors.fill: parent
        sourceComponent: Platform.isMobile ? mobilePicker : desktopPicker
    }
}

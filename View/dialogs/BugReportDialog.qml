import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

ThemedDialog {
    id: root
    title: qsTr("Send feedback")
    width:   Platform.isMobile ? Math.min(parent ? parent.width - 32 : 480, 480) : 480
    padding: 20

    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property bool _sending: false

    onAboutToShow: {
        descInput.text = ""
        includeLogsCheck.checked = true
        _sending       = false
        statusText.text = ""
    }

    // Enable OK only when there's enough text and not mid-send.
    standardButtons: (!_sending && descInput.text.trim().length > 10)
                     ? (Dialog.Ok | Dialog.Cancel)
                     : Dialog.Cancel

    onAccepted: {
        const desc = descInput.text.trim()
        if (desc.length < 10) return

        _sending = true
        statusText.text = qsTr("Sending\u2026")

        const details = {
            type:        "bug",
            description: desc,
        }

        // Collect log snapshot from the in-process log model.
        const logSnap = includeLogsCheck.checked ? logModel.snapshot(300) : []

        if (cloudService.available) {
            cloudService.postReport(details, logSnap)
        } else {
            statusText.text = qsTr("No cloud endpoint configured.\n"
                                 + "Email your report to support@tenjin.app")
            _sending = false
        }
    }

    Connections {
        target: cloudService
        function onReportSubmitted() {
            root._sending = false
            root.statusText.text = qsTr("Report sent. Thank you!")
            Qt.callLater(function() { root.close() })
        }
        function onNetworkError(msg) {
            root._sending = false
            root.statusText.text = qsTr("Send failed: ") + msg
        }
    }

    ColumnLayout {
        spacing: Platform.spacingMd
        width: parent.width

        Text {
            Layout.fillWidth: true
            text: qsTr("What happened? What did you expect instead?")
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: Platform.radius
            color: Platform.bg
            border.color: descInput.activeFocus ? Platform.accent : Platform.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                TextArea {
                    id: descInput
                    placeholderText: qsTr("e.g. The app froze when I tapped Delete on a deck.")
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    wrapMode: TextArea.Wrap
                    background: null
                    enabled: !root._sending
                }
            }
        }

        // Include logs checkbox
        Row {
            spacing: Platform.spacingSm
            CheckBox {
                id: includeLogsCheck
                checked: true
                enabled: !root._sending
                palette.windowText: Platform.textPrimary
            }
            Text {
                anchors.verticalCenter: includeLogsCheck.verticalCenter
                text: qsTr("Include app logs and crash data")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontSmall
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Logs help us diagnose the issue and are never shared publicly.")
            color: Platform.textMuted
            font.pixelSize: Platform.fontTiny
            wrapMode: Text.WordWrap
            visible: includeLogsCheck.checked
        }

        Text {
            id: statusText
            Layout.fillWidth: true
            visible: text.length > 0
            color: text.startsWith(qsTr("Report sent")) ? Platform.success : Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Version %1 \u00B7 %2").arg(Qt.application.version).arg(Qt.platform.os)
            color: Platform.textMuted
            font.pixelSize: Platform.fontTiny
            opacity: 0.7
        }
    }
}

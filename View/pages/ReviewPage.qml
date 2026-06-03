pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

Rectangle {
    color: Platform.reviewBg
    signal sessionEnded

    StackLayout {
        anchors.fill: parent
        currentIndex: !appVM.reviewVM.active ? 0 : appVM.reviewVM.complete ? 2 : 1

        Item {
            Text { anchors.centerIn: parent; text: "No active session."; color: Platform.textMuted; font.pixelSize: Platform.fontBase }
        }

        Item {
        ColumnLayout {
            anchors { fill: parent; margins: Platform.pagePadding }
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Card " + (appVM.reviewVM.currentIndex + 1) + " / " + appVM.reviewVM.totalCards
                    color: Platform.textMuted; font.pixelSize: Platform.fontBase
                }
                Item { Layout.fillWidth: true }
                Button {
                    id: stopBtn
                    text: "✕ Stop"; implicitHeight: Platform.touchTarget
                    onClicked: { appVM.reviewVM.stopSession(); sessionEnded() }
                    background: Rectangle { color: Platform.surface; radius: Platform.radius; border.color: Platform.border; border.width: 1 }
                    contentItem: Text { text: stopBtn.text; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            ProgressBar {
                id: reviewProgress
                Layout.fillWidth: true
                from: 0; to: appVM.reviewVM.totalCards; value: appVM.reviewVM.currentIndex
                background: Rectangle { color: Platform.surface; radius: 4; border.color: Platform.border; border.width: 1 }
                contentItem: Item {
                    implicitHeight: 6
                    Rectangle {
                        width: reviewProgress.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: Platform.accent
                    }
                }
            }

            // Card Canvas Window
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: Platform.surface; radius: Platform.radiusLarge
                border.color: Platform.border; border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 24
                    width: parent.width - 40
                    Text { Layout.alignment: Qt.AlignHCenter; text: appVM.reviewVM.currentWord; color: Platform.textPrimary; font.pixelSize: Platform.fontTitle; font.bold: true }

                    Button {
                        id: showBtn
                        Layout.alignment: Qt.AlignHCenter
                        visible: !appVM.reviewVM.showingAnswer
                        text: "Show Answer"
                        implicitHeight: Platform.touchTarget; implicitWidth: 140
                        onClicked: appVM.reviewVM.revealAnswer()
                        background: Rectangle { color: Platform.accent; radius: Platform.radius }
                        contentItem: Text { text: showBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: appVM.reviewVM.showingAnswer; spacing: 14
                        Text { Layout.alignment: Qt.AlignLeft; Layout.fillWidth: true; text: appVM.reviewVM.currentAnswer; textFormat: Text.RichText; color: Platform.accentDark; font.pixelSize: Platform.fontLarge; horizontalAlignment: Text.AlignLeft; wrapMode: Text.WordWrap }
                    }
                }
            }

            // Quality Input Bar
            RowLayout {
                Layout.fillWidth: true
                visible: appVM.reviewVM.showingAnswer; spacing: Platform.isMobile ? 4 : 8
                Repeater {
                    model: [
                        { q: 0, label: Platform.isMobile ? "0" : "0 - Forgot", color: "#e74c3c" },
                        { q: 1, label: Platform.isMobile ? "1" : "1 - Hard",   color: "#e67e22" },
                        { q: 2, label: Platform.isMobile ? "2" : "2 - Good",   color: "#2ecc71" },
                        { q: 3, label: Platform.isMobile ? "3" : "3 - Easy",   color: "#3498db" }
                    ]
                    Button {
                        id: qBtn
                        required property var modelData
                        property color color: modelData.color
                        Layout.fillWidth: true
                        implicitHeight: Platform.touchTarget + (Platform.isMobile ? 8 : 0)
                        text: modelData.label
                        onClicked: appVM.reviewVM.submitQuality(modelData.q)
                        background: Rectangle { color: qBtn.color; radius: Platform.radius }
                        contentItem: Text { text: qBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
        }

        Item {
        ColumnLayout {
            anchors.centerIn: parent; spacing: 20
            Text { Layout.alignment: Qt.AlignHCenter; text: "🎉 Session complete!"; color: Platform.success; font.pixelSize: Platform.fontTitle; font.bold: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: "All " + appVM.reviewVM.totalCards + " cards reviewed."; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
            Button {
                id: backBtn
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: Platform.touchTarget; implicitWidth: 160
                text: "Back to Deck"
                onClicked: { appVM.reviewVM.stopSession(); sessionEnded() }
                background: Rectangle { color: Platform.accent; radius: Platform.radius }
                contentItem: Text { text: backBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        }
    }
}

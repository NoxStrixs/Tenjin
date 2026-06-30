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

        // ── Idle: "Today" overview (F1) ─────────────────────────────────────
        // Due-today, streak, and reviewed-today pulled from globalStats (all
        // already provided by the backend). Refreshed each time this state
        // becomes visible. No binding loop — _refresh is called explicitly.
        Item {
            id: idleState

            property var stats: ({})
            function _refresh() { idleState.stats = appVM.deckVM.globalStats() }
            Component.onCompleted: _refresh()
            // Refresh whenever we return to idle (session ended, data changed).
            Connections {
                target: appVM.reviewVM
                function onActiveChanged() { if (!appVM.reviewVM.active) idleState._refresh() }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - Platform.pagePadding * 2, 420)
                spacing: Platform.spacingLg

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Today")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }

                // Due-today hero number.
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (idleState.stats.dueToday !== undefined ? idleState.stats.dueToday : 0)
                        color: Platform.accent
                        font.pixelSize: Platform.iconSizeHero
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("cards due")
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                    }
                }

                // Stat row: streak + reviewed today + next 7 days.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Platform.spacingMd

                    component StatCell: Rectangle {
                        id: statCell
                        property string value
                        property string label
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: Platform.radius
                        color: Platform.surface
                        border.color: Platform.border
                        border.width: 1
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: statCell.value
                                color: Platform.textPrimary
                                font.pixelSize: Platform.fontLarge
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: statCell.label
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontSmall
                            }
                        }
                    }

                    StatCell {
                        value: "\uD83D\uDD25 " + (idleState.stats.currentStreakDays !== undefined ? idleState.stats.currentStreakDays : 0)
                        label: qsTr("day streak")
                    }
                    StatCell {
                        value: (idleState.stats.reviewsToday !== undefined ? idleState.stats.reviewsToday : 0)
                        label: qsTr("reviewed")
                    }
                    StatCell {
                        value: (idleState.stats.dueNext7Days !== undefined ? idleState.stats.dueNext7Days : 0)
                        label: qsTr("next 7 days")
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Platform.spacingSm
                    visible: (idleState.stats.dueToday === undefined || idleState.stats.dueToday === 0)
                    text: qsTr("Nothing due right now — pick a deck to study ahead.")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Leech warning — only when some cards are flagged.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Platform.spacingXs
                    spacing: Platform.spacingXs
                    visible: (idleState.stats.leechCount !== undefined && idleState.stats.leechCount > 0)
                    Text {
                        text: TenjinIcons.warning
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontSmall
                        color: Platform.danger
                    }
                    Text {
                        text: qsTr("%1 leech card(s) need attention").arg(
                                  idleState.stats.leechCount !== undefined ? idleState.stats.leechCount : 0)
                        color: Platform.danger
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }
                }
            }
        }

        Item {
        ColumnLayout {
            anchors { fill: parent; margins: Platform.pagePadding }
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Card %1 / %2").arg(appVM.reviewVM.currentIndex + 1).arg(appVM.reviewVM.totalCards)
                    color: Platform.textMuted; font.pixelSize: Platform.fontBase
                }
                Item { Layout.fillWidth: true }
                Button {
                    id: stopBtn
                    text: qsTr("✕ Stop"); implicitHeight: Platform.touchTarget
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

                    // Leech badge — shown when this card has been failed many
                    // times, cueing the user to slow down and study it.
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        visible: appVM.reviewVM.currentIsLeech
                        implicitWidth: leechRow.implicitWidth + Platform.spacingMd * 2
                        implicitHeight: leechRow.implicitHeight + Platform.spacingXs * 2
                        radius: height / 2
                        // Tinted danger background without fading the content:
                        // a low-alpha fill drawn behind full-opacity text.
                        color: "transparent"
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Platform.danger
                            opacity: 0.15
                        }
                        RowLayout {
                            id: leechRow
                            anchors.centerIn: parent
                            spacing: Platform.spacingXs
                            Text {
                                text: TenjinIcons.warning
                                font.family: TenjinIcons.family
                                font.pixelSize: Platform.fontBase
                                color: Platform.danger
                            }
                            Text {
                                text: qsTr("Leech — give this one extra attention")
                                color: Platform.danger
                                font.pixelSize: Platform.fontSmall
                                font.bold: true
                            }
                        }
                    }

                    Text { Layout.alignment: Qt.AlignHCenter; text: appVM.reviewVM.currentWord; color: Platform.textPrimary; font.pixelSize: Platform.fontTitle; font.bold: true }

                    Button {
                        id: showBtn
                        Layout.alignment: Qt.AlignHCenter
                        visible: !appVM.reviewVM.showingAnswer
                        text: qsTr("Show Answer")
                        implicitHeight: Platform.touchTarget; implicitWidth: 140
                        onClicked: { haptics.light(); appVM.reviewVM.revealAnswer() }
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
                        { q: 0, label: Platform.isMobile ? qsTr("0") : qsTr("0 – Forgot"), color: "#e74c3c" },
                        { q: 1, label: Platform.isMobile ? qsTr("1") : qsTr("1 – Hard"),   color: "#e67e22" },
                        { q: 2, label: Platform.isMobile ? qsTr("2") : qsTr("2 – Good"),   color: "#2ecc71" },
                        { q: 3, label: Platform.isMobile ? qsTr("3") : qsTr("3 – Easy"),   color: "#3498db" }
                    ]
                    Button {
                        id: qBtn
                        required property var modelData
                        property color color: modelData.color
                        Layout.fillWidth: true
                        implicitHeight: Platform.touchTarget + (Platform.isMobile ? 8 : 0)
                        text: modelData.label
                        onClicked: { haptics.medium(); appVM.reviewVM.submitQuality(modelData.q) }
                        background: Rectangle { color: qBtn.color; radius: Platform.radius }
                        contentItem: Text { text: qBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
        }
        }

        Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Platform.pagePadding * 2, 420)
            spacing: Platform.spacingLg

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("🎉 Session complete!")
                color: Platform.success
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }

            // Accuracy hero.
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Math.round(appVM.reviewVM.sessionAccuracy * 100) + "%"
                    color: Platform.accent
                    font.pixelSize: Platform.iconSizeHero
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("accuracy")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                }
            }

            // Breakdown row.
            RowLayout {
                Layout.fillWidth: true
                spacing: Platform.spacingMd

                component SumCell: Rectangle {
                    id: sumCell
                    property string value
                    property string label
                    property color valueColor: Platform.textPrimary
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: Platform.radius
                    color: Platform.surface
                    border.color: Platform.border
                    border.width: 1
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: sumCell.value
                            color: sumCell.valueColor
                            font.pixelSize: Platform.fontLarge
                            font.bold: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: sumCell.label
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                        }
                    }
                }

                SumCell {
                    value: appVM.reviewVM.totalCards
                    label: qsTr("cards")
                }
                SumCell {
                    value: appVM.reviewVM.sessionCorrect
                    label: qsTr("correct")
                    valueColor: Platform.success
                }
                SumCell {
                    // mm:ss elapsed.
                    value: {
                        var s = appVM.reviewVM.sessionElapsedSeconds
                        var m = Math.floor(s / 60)
                        var r = s % 60
                        return m + ":" + (r < 10 ? "0" : "") + r
                    }
                    label: qsTr("time")
                }
            }

            Button {
                id: backBtn
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Platform.spacingSm
                implicitHeight: Platform.touchTarget; implicitWidth: 160
                text: qsTr("Back to Deck")
                onClicked: { appVM.reviewVM.stopSession(); sessionEnded() }
                background: Rectangle { color: Platform.accent; radius: Platform.radius }
                contentItem: Text { text: backBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        }
    }
}


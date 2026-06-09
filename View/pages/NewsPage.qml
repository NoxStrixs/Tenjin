import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top-level News destination. Driven by appVM.currentPage === PageNews (=4).
// Reads the news list from appVM.newsItems (populated in C++ from bundled
// defaults; will be augmented by a network fetch once Qt6::Network is added
// to the ViewModels module).
Item {
    id: newsRoot

    // Asks Main.qml to return to Words. Wired in Main.qml's StackLayout host.
    signal backRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Desktop title + refresh control. Mobile gets the same controls but
        // below the window header (which already says "News").
        RowLayout {
            visible: !Platform.isMobile
            Layout.fillWidth: true
            Layout.leftMargin: Platform.pagePadding
            Layout.topMargin: Platform.pagePadding
            Layout.rightMargin: Platform.pagePadding
            Layout.bottomMargin: Platform.spacingMd

            // Back to Words.
            Rectangle {
                Layout.preferredWidth: Platform.touchTarget
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: newsBackArea.containsMouse ? Platform.surfaceAlt : "transparent"
                border.color: Platform.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                Text {
                    anchors.centerIn: parent
                    text: "\u2039"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
                MouseArea {
                    id: newsBackArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: newsRoot.backRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "News"
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }
            Rectangle {
                Layout.preferredWidth: refreshLabel.implicitWidth + 28
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: refreshArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                scale: refreshArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                Text {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: "Refresh"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.refreshNews("https://localhost")
                }
            }
        }

        // Mobile refresh button (compact row below the header).
        Rectangle {
            visible: Platform.isMobile
            Layout.fillWidth: true
            Layout.preferredHeight: Platform.touchTarget + 8
            color: "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: Platform.pagePadding; rightMargin: Platform.pagePadding }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: mRefreshLabel.implicitWidth + 28
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: mRefreshArea.pressed ? Platform.accentDark : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text {
                        id: mRefreshLabel
                        anchors.centerIn: parent
                        text: "Refresh"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                    }
                    MouseArea {
                        id: mRefreshArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appVM.refreshNews("https://localhost")
                    }
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Platform.border; opacity: 0.5 }
        }

        ListView {
            id: newsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appVM.newsItems
            spacing: Platform.spacingMd
            topMargin: Platform.spacingLg
            bottomMargin: Platform.spacingLg + Platform.safeAreaBottom
            leftMargin: Platform.pagePadding
            rightMargin: Platform.pagePadding
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width - 2 * Platform.pagePadding
                implicitHeight: newsCol.implicitHeight + 2 * Platform.spacingMd
                radius: Platform.radiusLarge
                color: Platform.surface
                border.color: cardHover.hovered ? Platform.accent : Platform.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                HoverHandler { id: cardHover }

                ColumnLayout {
                    id: newsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Platform.spacingMd }
                    spacing: Platform.spacingXs
                    Text {
                        text: modelData.date
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontTiny
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontLarge
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.body
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                visible: newsList.count === 0
                spacing: 12
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u2709"; font.pixelSize: 52; color: Platform.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No news yet."
                    color: Platform.textMuted; font.pixelSize: Platform.fontLarge
                }
            }
        }
    }
}


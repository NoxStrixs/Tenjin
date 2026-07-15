import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Collection-wide statistics dashboard. Pulls appVM.deckVM.globalStats()
// (aggregated across every deck) and renders:
//   • A top strip of headline metrics unique to the global view
//     (current streak, due today, due in 7 days, words).
//   • The existing AnalyticsPanel for the charts/heatmap, fed the same
//     daily[] / totalReviews / retention shape it already understands.
Item {
    id: statsRoot

    signal backRequested()

    property var stats: ({
        totalReviews: 0, totalWords: 0, dueToday: 0, dueNext7Days: 0,
        retention: 0, currentStreakDays: 0, longestStreakDays: 0,
        reviewsToday: 0, daily: []
    })

    function refresh() {
        try {
            if (appVM && appVM.deckVM)
                stats = appVM.deckVM.globalStats()
        } catch (e) {
            console.warn("StatsPage.refresh failed:", e)
        }
    }

    // Refresh whenever the page becomes visible or reviews change.
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: appVM.reviewVM
        function onSessionChanged() { if (statsRoot.visible) statsRoot.refresh() }
    }

    component HeadlineCard: Rectangle {
        property string value: ""
        property string label: ""
        property string glyph: ""
        property color  accent: Platform.accent
        Layout.fillWidth: true
        Layout.preferredHeight: Platform.isMobile ? 92 : 104
        radius: Platform.radiusLarge
        color: Platform.surface
        border.color: Platform.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Platform.spacingMd
            spacing: Platform.spacingXs
            RowLayout {
                spacing: Platform.spacingSm
                Text {
                    text: glyph
                    font.family: TenjinIcons.family
                    font.pixelSize: Platform.fontLarge
                    color: accent
                }
                Item { Layout.fillWidth: true }
            }
            Item { Layout.fillHeight: true }
            Text {
                text: value
                color: Platform.textPrimary
                font.pixelSize: Platform.isMobile ? 26 : 30
                font.bold: true
            }
            Text {
                text: label
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: statsRoot.width
            spacing: Platform.spacingLg

            // Header (back button on mobile / narrow)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                Layout.topMargin: Platform.pagePadding
                spacing: Platform.spacingMd

                Rectangle {
                    visible: true
                    Layout.preferredWidth: Platform.touchTarget
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: statsBackArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border
                    border.width: 1
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Back")
                    Text {
                        anchors.centerIn: parent
                        text: TenjinIcons.chevronLeft
                        font.family: TenjinIcons.family
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                    }
                    MouseArea {
                        id: statsBackArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: statsRoot.backRequested()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Statistics")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Rectangle {
                    Layout.preferredWidth: Platform.touchTarget
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: statsRefreshArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Refresh statistics")
                    Text {
                        anchors.centerIn: parent
                        text: TenjinIcons.refresh
                        font.family: TenjinIcons.family
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontLarge
                    }
                    MouseArea {
                        id: statsRefreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: statsRoot.refresh()
                    }
                }
            }

            // Headline metric strip — global-only figures.
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                columns: Platform.useWideLayout ? 4 : 2
                columnSpacing: Platform.spacingMd
                rowSpacing: Platform.spacingMd

                HeadlineCard {
                    value: statsRoot.stats.currentStreakDays + ""
                    label: statsRoot.stats.currentStreakDays === 1 ? qsTr("day streak")
                                                                   : qsTr("day streak")
                    glyph: TenjinIcons.autoAwesome
                    accent: Platform.accent
                }
                HeadlineCard {
                    value: statsRoot.stats.dueToday + ""
                    label: qsTr("due today")
                    glyph: TenjinIcons.decks
                    accent: statsRoot.stats.dueToday > 0 ? Platform.danger : Platform.success
                }
                HeadlineCard {
                    value: statsRoot.stats.dueNext7Days + ""
                    label: qsTr("due in 7 days")
                    glyph: TenjinIcons.news
                }
                HeadlineCard {
                    value: statsRoot.stats.totalWords + ""
                    label: qsTr("words")
                    glyph: TenjinIcons.words
                }
            }

            // Secondary strip: reviews today, retention, best streak.
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                columns: Platform.useWideLayout ? 3 : 3
                columnSpacing: Platform.spacingMd
                rowSpacing: Platform.spacingMd

                HeadlineCard {
                    value: statsRoot.stats.reviewsToday + ""
                    label: qsTr("reviews today")
                    glyph: TenjinIcons.check
                }
                HeadlineCard {
                    value: Math.round(statsRoot.stats.retention * 100) + "%"
                    label: qsTr("retention")
                    glyph: TenjinIcons.autoAwesome
                }
                HeadlineCard {
                    value: statsRoot.stats.longestStreakDays + ""
                    label: qsTr("best streak")
                    glyph: TenjinIcons.pin
                }
            }

            // Charts / heatmap reuse the deck AnalyticsPanel, fed global data.
            AnalyticsPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                embedded: true
                deckId: -1
                analytics: ({
                    totalReviews: statsRoot.stats.totalReviews,
                    retention:    statsRoot.stats.retention,
                    daily:        statsRoot.stats.daily
                })
            }

            // Empty state when there's no review history yet.
            EmptyState {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: statsRoot.stats.totalReviews === 0
                icon: TenjinIcons.decks
                title: qsTr("No review history yet")
                subtitle: qsTr("Review a deck to start building your statistics.")
            }

            Item { Layout.preferredHeight: Platform.spacingXl + Platform.safeAreaBottom }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import TenjinView

// Card wrapper for an embedded chart. Adds: optional subtitle / trend chip,
// fade-in for the plot area when data first arrives, hover lift on desktop.
Rectangle {
    id: card
    property string title:    ""
    property string subtitle: ""
    property string trend:    ""   // e.g. "+12%", "-3%". Empty hides the chip.
    property string emptyText: ""
    property Item   chart:    null

    Layout.preferredHeight: 220
    radius: Platform.radiusLarge
    color: Platform.surface
    border.color: cardHover.hovered ? Platform.accent : Platform.border
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }

    // Subtle hover lift on desktop. No-op on mobile (HoverHandler.hovered
    // stays false without a pointing device).
    transform: Translate {
        y: cardHover.hovered ? -1 : 0
        Behavior on y { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
    }
    HoverHandler { id: cardHover }

    onChartChanged: {
        if (chart) {
            chart.parent = plotArea
            chart.anchors.fill = plotArea
        }
    }

    // Determines whether the trend chip leans positive or negative.
    readonly property bool _trendPositive: trend.length > 0 && trend.charAt(0) === "+"
    readonly property bool _trendNegative: trend.length > 0 && trend.charAt(0) === "-"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Title row — title at left, optional trend chip on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: card.title
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                visible: card.trend.length > 0
                implicitWidth: trendText.implicitWidth + 12
                implicitHeight: trendText.implicitHeight + 4
                radius: implicitHeight / 2
                color: card._trendPositive ? Qt.rgba(Platform.success.r, Platform.success.g, Platform.success.b, 0.18)
                     : card._trendNegative ? Qt.rgba(Platform.danger.r,  Platform.danger.g,  Platform.danger.b,  0.18)
                                            : Platform.surfaceAlt
                Text {
                    id: trendText
                    anchors.centerIn: parent
                    text: card.trend
                    color: card._trendPositive ? Platform.success
                         : card._trendNegative ? Platform.danger
                                                : Platform.textMuted
                    font.pixelSize: Platform.fontTiny
                    font.bold: true
                }
            }
        }

        // Optional subtitle (e.g. "Last 7 days").
        Text {
            visible: card.subtitle.length > 0
            text: card.subtitle
            color: Platform.textMuted
            font.pixelSize: Platform.fontTiny
        }

        // Plot region — fades in once content lands. Empty-state text sits
        // centered inside the same region for parity.
        Item {
            id: plotArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: card.emptyText.length > 0 ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: Platform.durationMed } }

            Text {
                anchors.centerIn: parent
                visible: card.emptyText.length > 0
                text: card.emptyText
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase - 1
                font.italic: true
            }
        }
    }
}


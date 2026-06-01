import QtQuick
import QtQuick.Layouts
import TenjinView

// A titled card that hosts a hand-drawn chart. Pass the chart as the `chart`
// Item; it is reparented to fill the plot area. `emptyText` (when non-empty)
// is shown instead of the chart.
Rectangle {
    id: card
    property string title: ""
    property string emptyText: ""
    property Item   chart: null

    Layout.preferredHeight: 200
    radius: Platform.radiusLarge
    color: Platform.surface
    border.color: Platform.border
    border.width: 1

    onChartChanged: {
        if (chart) {
            chart.parent = plotArea
            chart.anchors.fill = plotArea
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: card.title
            color: Platform.textPrimary
            font.pixelSize: Platform.fontBase
            font.bold: true
        }

        Item {
            id: plotArea
            Layout.fillWidth: true
            Layout.fillHeight: true

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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Deck analytics: summary stats + hand-drawn charts (no external charting
// dependency). Reads from DeckViewModel.deckAnalytics(deckId), which aggregates
// the review_log table.
Item {
    id: root
    property int deckId: -1

    property var analytics: ({ totalReviews: 0, retention: 0, daily: [] })

    function refresh() {
        if (deckId >= 0)
            analytics = appVM.deckVM.deckAnalytics(deckId)
    }

    onDeckIdChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: appVM.reviewVM
        function onSessionChanged() { root.refresh() }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: root.width
            spacing: 16

            // ── Summary cards ──
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Platform.pagePadding
                spacing: 12

                Repeater {
                    model: [
                        { label: "Total reviews", value: root.analytics.totalReviews + "" },
                        { label: "Retention", value: Math.round(root.analytics.retention * 100) + "%" },
                        { label: "Active days", value: root.analytics.daily.length + "" }
                    ]
                    delegate: Rectangle {
                        id: summaryCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: Platform.radiusLarge
                        color: Platform.surface
                        border.color: Platform.border
                        border.width: 1
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: summaryCard.modelData.value
                                color: Platform.accentDark
                                font.pixelSize: Platform.fontTitle
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: summaryCard.modelData.label
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase - 1
                            }
                        }
                    }
                }
            }

            // ── Reviews per day (bar chart) ──
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                title: "Reviews per day"
                emptyText: root.analytics.daily.length === 0 ? "No reviews yet." : ""

                chart: Canvas {
                    id: barCanvas
                    anchors.fill: parent
                    property var data: root.analytics.daily
                    onDataChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const d = data
                        if (!d || d.length === 0) return
                        let maxC = 1
                        for (let i = 0; i < d.length; i++) maxC = Math.max(maxC, d[i].count)
                        const pad = 24
                        const w = width - pad * 2
                        const h = height - pad * 2
                        const bw = Math.max(2, w / d.length * 0.7)
                        const gap = w / d.length
                        ctx.fillStyle = Platform.accent
                        for (let i = 0; i < d.length; i++) {
                            const bh = (d[i].count / maxC) * h
                            const x = pad + i * gap + (gap - bw) / 2
                            const y = pad + h - bh
                            ctx.fillRect(x, y, bw, bh)
                        }
                        // baseline
                        ctx.strokeStyle = Platform.border
                        ctx.beginPath(); ctx.moveTo(pad, pad + h); ctx.lineTo(pad + w, pad + h); ctx.stroke()
                    }
                }
            }

            // ── Accuracy over time (line chart, avg grade 0..3) ──
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                Layout.bottomMargin: Platform.pagePadding
                title: "Average grade per day (0–3)"
                emptyText: root.analytics.daily.length === 0 ? "No reviews yet." : ""

                chart: Canvas {
                    id: lineCanvas
                    anchors.fill: parent
                    property var data: root.analytics.daily
                    onDataChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const d = data
                        if (!d || d.length === 0) return
                        const pad = 24
                        const w = width - pad * 2
                        const h = height - pad * 2
                        const maxQ = 3
                        function px(i) { return d.length === 1 ? pad + w / 2 : pad + (i / (d.length - 1)) * w }
                        function py(q) { return pad + h - (q / maxQ) * h }

                        // gridlines at 1,2,3
                        ctx.strokeStyle = Platform.border
                        ctx.globalAlpha = 0.4
                        for (let g = 1; g <= 3; g++) {
                            ctx.beginPath(); ctx.moveTo(pad, py(g)); ctx.lineTo(pad + w, py(g)); ctx.stroke()
                        }
                        ctx.globalAlpha = 1

                        // line
                        ctx.strokeStyle = Platform.accentDark
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        for (let i = 0; i < d.length; i++) {
                            const x = px(i), y = py(d[i].avgQuality)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // points
                        ctx.fillStyle = Platform.accent
                        for (let i = 0; i < d.length; i++) {
                            ctx.beginPath(); ctx.arc(px(i), py(d[i].avgQuality), 3, 0, Math.PI * 2); ctx.fill()
                        }
                    }
                }
            }
        }
    }

    // Repaint charts when the theme changes (colors are read at paint time).
    Connections {
        target: Platform
        function onThemeChanged() { root.refresh() }
    }
}

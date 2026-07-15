import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Deck analytics — surfaces every metric we can derive from the daily review
// log without new C++ plumbing:
//
//   KPIs (6, in a 3-col grid that re-flows to 2-col on narrow screens)
//     • Total reviews    — sum of count
//     • Retention        — server-provided exponential moving avg
//     • Active days      — daily.length
//     • Avg / day        — totalReviews / activeDays
//     • Streak           — consecutive recent days with activity (today
//                          can be empty without breaking the streak)
//     • Best day         — max count in a single day
//
//   Charts
//     • Reviews per day  — animated bar growth
//     • Avg grade / day  — animated line draw
//     • Activity heatmap — 13×7 calendar grid, today bottom-right; cell
//                          color blends Platform.surfaceAlt → accent.
//     • Retention curve  — running quality average over the daily window.
//
// All derived metrics are pure JS over `analytics.daily`. A future batch
// can add per-tag / per-state breakdowns once EntryService grows the
// corresponding queries.
Item {
    id: root
    property int deckId: -1
    // When true, the panel reports its content height via implicitHeight and
    // does not scroll internally — for embedding inside another ScrollView
    // (e.g. the global StatsPage). When false it fills its parent and scrolls.
    property bool embedded: false

    property var analytics: ({ totalReviews: 0, retention: 0, daily: [] })

    // Drives the bar growth, line draw, heatmap fade-in, and curve sweep.
    property real _chartProgress: 0
    NumberAnimation on _chartProgress {
        id: chartIntro
        running: false
        from: 0
        to: 1
        duration: Platform.reducedMotion ? 0 : 700
        easing.type: Easing.OutCubic
    }

    function refresh() {
        if (deckId >= 0)
            analytics = appVM.deckVM.deckAnalytics(deckId)
    }

    onAnalyticsChanged: { _chartProgress = 0; chartIntro.restart() }
    onDeckIdChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: appVM.reviewVM
        function onSessionChanged() { root.refresh() }
    }
    Connections {
        target: Platform
        function onThemeChanged() { root.refresh() }
    }

    // ── Derived metrics ────────────────────────────────────────────────────
    function _split(arr, key) {
        if (!arr || arr.length < 2) return { first: 0, second: 0, ok: false }
        const half = Math.floor(arr.length / 2)
        let a = 0, b = 0
        for (let i = 0;     i < half;       i++) a += (key === "count" ? arr[i].count : arr[i].avgQuality)
        for (let i = half;  i < arr.length; i++) b += (key === "count" ? arr[i].count : arr[i].avgQuality)
        return { first: a, second: b, ok: true }
    }
    function _trendStr(split) {
        if (!split.ok || split.first === 0) return ""
        const pct = Math.round(((split.second - split.first) / split.first) * 100)
        if (pct === 0)  return ""
        if (pct > 0)    return "+" + pct + "%"
        return pct + "%"
    }

    // Streak — walk back from today, counting consecutive days with activity.
    // Today being empty doesn't break the streak (typical UX — let the user
    // study later in the day).
    function _streak(daily) {
        if (!daily || daily.length === 0) return 0
        const set = {}
        for (let i = 0; i < daily.length; i++) set[daily[i].date] = true
        const today = new Date()
        let streak = 0
        let started = false
        for (let i = 0; i < 365; i++) {
            const d = new Date(today.getTime())
            d.setDate(today.getDate() - i)
            const key = d.getFullYear() + "-" +
                        String(d.getMonth() + 1).padStart(2, "0") + "-" +
                        String(d.getDate()).padStart(2, "0")
            if (set[key]) { streak++; started = true }
            else if (started) break
        }
        return streak
    }
    function _bestDay(daily) {
        if (!daily || daily.length === 0) return 0
        let best = 0
        for (let i = 0; i < daily.length; i++) best = Math.max(best, daily[i].count)
        return best
    }

    readonly property var _reviewsTrend: _split(analytics.daily, "count")
    readonly property var _qualityTrend: _split(analytics.daily, "quality")
    readonly property int _currentStreak: _streak(analytics.daily)
    readonly property int _bestDayCount:  _bestDay(analytics.daily)

    implicitHeight: root.embedded ? _content.implicitHeight : 0

    // Scroll container. Standalone, this Flickable scrolls the content. Embedded
    // inside the stats page's own ScrollView, a nested scroller would swallow
    // wheel events (the "dead zone" on the lower half), so when embedded we make
    // this Flickable inert AND zero-height-contributing: interactive off, and
    // contentHeight clamped to the viewport so it never scrolls or grabs wheel.
    // The content's real height is exposed through the panel's implicitHeight
    // (above) so the OUTER page scrolls everything as one surface.
    Flickable {
        id: _flick
        anchors.fill: parent
        clip: !root.embedded
        contentWidth: width
        contentHeight: root.embedded ? height : _content.implicitHeight
        interactive: !root.embedded
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: root.embedded ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded }

        ColumnLayout {
            id: _content
            width: root.width
            spacing: 16

            // ── KPI grid ────────────────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Platform.pagePadding
                columnSpacing: 12
                rowSpacing: 12
                // 3 columns on wide displays, 2 on narrow / mobile.
                columns: Platform.isMobile || root.width < 720 ? 2 : 3

                Repeater {
                    model: [
                        { label: qsTr("Total reviews"),
                          value: root.analytics.totalReviews + "",
                          trend: root._trendStr(root._reviewsTrend) },
                        { label: qsTr("Retention"),
                          value: Math.round(root.analytics.retention * 100) + "%",
                          trend: "" },
                        { label: qsTr("Active days"),
                          value: root.analytics.daily.length + "",
                          trend: "" },
                        { label: qsTr("Avg / day"),
                          value: root.analytics.daily.length > 0
                                 ? (root.analytics.totalReviews / root.analytics.daily.length).toFixed(1)
                                 : "0",
                          trend: root._trendStr(root._qualityTrend) },
                        { label: qsTr("Current streak"),
                          value: root._currentStreak + (root._currentStreak === 1 ? " day" : " days"),
                          trend: "" },
                        { label: qsTr("Best day"),
                          value: root._bestDayCount + (root._bestDayCount === 1 ? " card" : " cards"),
                          trend: "" }
                    ]
                    delegate: Rectangle {
                        id: kpiCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: Platform.radiusLarge
                        color: cardHover.hovered ? Platform.surfaceAlt : Platform.surface
                        border.color: cardHover.hovered ? Platform.accent : Platform.border
                        border.width: 1

                        Behavior on color        { ColorAnimation { duration: Platform.effDurationFast } }
                        Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }

                        transform: Translate {
                            y: cardHover.hovered ? -2 : 0
                            Behavior on y { NumberAnimation { duration: Platform.effDurationFast; easing.type: Easing.OutCubic } }
                        }
                        HoverHandler { id: cardHover }

                        readonly property bool _trendPositive: kpiCard.modelData.trend.length > 0 && kpiCard.modelData.trend.charAt(0) === "+"
                        readonly property bool _trendNegative: kpiCard.modelData.trend.length > 0 && kpiCard.modelData.trend.charAt(0) === "-"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Platform.spacingXs
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: kpiCard.modelData.value
                                color: Platform.accentDark
                                font.pixelSize: Platform.fontTitle
                                font.bold: true
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6
                                Text {
                                    text: kpiCard.modelData.label
                                    color: Platform.textMuted
                                    font.pixelSize: Platform.fontBase - 1
                                }
                                Rectangle {
                                    visible: kpiCard.modelData.trend.length > 0
                                    implicitWidth: kpiTrend.implicitWidth + 10
                                    implicitHeight: kpiTrend.implicitHeight + 2
                                    radius: implicitHeight / 2
                                    color: kpiCard._trendPositive ? Qt.rgba(Platform.success.r, Platform.success.g, Platform.success.b, 0.18)
                                         : kpiCard._trendNegative ? Qt.rgba(Platform.danger.r,  Platform.danger.g,  Platform.danger.b,  0.18)
                                                                   : Platform.surfaceAlt
                                    Text {
                                        id: kpiTrend
                                        anchors.centerIn: parent
                                        text: kpiCard.modelData.trend
                                        color: kpiCard._trendPositive ? Platform.success
                                             : kpiCard._trendNegative ? Platform.danger
                                                                       : Platform.textMuted
                                        font.pixelSize: Platform.fontTiny
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Reviews per day (animated bars) ─────────────────────────────
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                title: qsTr("Reviews per day")
                subtitle: root.analytics.daily.length > 0
                          ? root.analytics.daily.length + " days of data" : ""
                trend: root._trendStr(root._reviewsTrend)
                emptyText: root.analytics.daily.length === 0 ? "No reviews yet." : ""

                chart: Canvas {
                    anchors.fill: parent
                    property var data: root.analytics.daily
                    property real progress: root._chartProgress
                    onDataChanged:     requestPaint()
                    onProgressChanged: requestPaint()
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
                            const bh = (d[i].count / maxC) * h * progress
                            const x = pad + i * gap + (gap - bw) / 2
                            const y = pad + h - bh
                            ctx.fillRect(x, y, bw, bh)
                        }
                        ctx.strokeStyle = Platform.border
                        ctx.beginPath(); ctx.moveTo(pad, pad + h); ctx.lineTo(pad + w, pad + h); ctx.stroke()
                    }
                }
            }

            // ── Average grade per day (animated line) ───────────────────────
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                title: qsTr("Average grade per day (0–3)")
                subtitle: root.analytics.daily.length > 0
                          ? "Higher is better recall on first attempt" : ""
                trend: root._trendStr(root._qualityTrend)
                emptyText: root.analytics.daily.length === 0 ? "No reviews yet." : ""

                chart: Canvas {
                    anchors.fill: parent
                    property var data: root.analytics.daily
                    property real progress: root._chartProgress
                    onDataChanged:     requestPaint()
                    onProgressChanged: requestPaint()
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

                        ctx.strokeStyle = Platform.border
                        ctx.globalAlpha = 0.4
                        for (let g = 1; g <= 3; g++) {
                            ctx.beginPath(); ctx.moveTo(pad, py(g)); ctx.lineTo(pad + w, py(g)); ctx.stroke()
                        }
                        ctx.globalAlpha = 1

                        const limit = Math.max(1, Math.ceil(d.length * progress))
                        ctx.strokeStyle = Platform.accentDark
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        for (let i = 0; i < limit; i++) {
                            const x = px(i), y = py(d[i].avgQuality)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        ctx.fillStyle = Platform.accent
                        const r = 3 * progress
                        for (let i = 0; i < limit; i++) {
                            ctx.beginPath(); ctx.arc(px(i), py(d[i].avgQuality), r, 0, Math.PI * 2); ctx.fill()
                        }
                    }
                }
            }

            // ── 91-day activity heatmap (GitHub-style calendar) ─────────────
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                title: qsTr("Activity (last 13 weeks)")
                subtitle: qsTr("Color intensity = reviews that day")
                emptyText: root.analytics.daily.length === 0 ? "No reviews yet." : ""

                chart: Item {
                    id: heatmap
                    anchors.fill: parent

                    // Build a date → count map whenever analytics changes.
                    property var countByDate: ({})
                    property int windowMax: 1
                    Connections {
                        target: root
                        function onAnalyticsChanged() { heatmap._rebuild() }
                    }
                    Component.onCompleted: _rebuild()

                    function _rebuild() {
                        const m = {}
                        let max = 1
                        const d = root.analytics.daily || []
                        for (let i = 0; i < d.length; i++) {
                            m[d[i].date] = d[i].count
                            if (d[i].count > max) max = d[i].count
                        }
                        countByDate = m
                        windowMax = max
                    }

                    // 91 sequential days, today as the last cell.
                    readonly property var windowDays: {
                        const days = []
                        const today = new Date()
                        for (let i = 90; i >= 0; i--) {
                            const dd = new Date(today.getTime())
                            dd.setDate(today.getDate() - i)
                            const key = dd.getFullYear() + "-" +
                                        String(dd.getMonth() + 1).padStart(2, "0") + "-" +
                                        String(dd.getDate()).padStart(2, "0")
                            days.push({ key: key, weekday: dd.getDay() })
                        }
                        return days
                    }

                    GridLayout {
                        anchors.centerIn: parent
                        columns: 13
                        rowSpacing: 3
                        columnSpacing: 3
                        Repeater {
                            model: heatmap.windowDays
                            delegate: Rectangle {
                                required property var modelData
                                readonly property int  _count: heatmap.countByDate[modelData.key] || 0
                                readonly property real _ratio: heatmap.windowMax > 0 ? _count / heatmap.windowMax : 0
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 2
                                // A faint border keeps the grid visible even when
                                // a cell is empty and its fill matches the card
                                // background (notably in light mode, where
                                // surfaceAlt ≈ surface).
                                border.width: 1
                                border.color: Platform.border
                                color: _count === 0
                                    ? Platform.surfaceAlt
                                    : Qt.rgba(
                                        Platform.surfaceAlt.r + (Platform.accent.r - Platform.surfaceAlt.r) * _ratio,
                                        Platform.surfaceAlt.g + (Platform.accent.g - Platform.surfaceAlt.g) * _ratio,
                                        Platform.surfaceAlt.b + (Platform.accent.b - Platform.surfaceAlt.b) * _ratio,
                                        1
                                    )
                                opacity: 0.2 + 0.8 * root._chartProgress
                                Behavior on opacity { NumberAnimation { duration: Platform.effDurationFast } }

                                ToolTip.visible: cellHover.hovered
                                ToolTip.text: modelData.key + "  •  " + _count + (_count === 1 ? qsTr(" review") : qsTr(" reviews"))
                                ToolTip.delay: 250
                                HoverHandler { id: cellHover }
                            }
                        }
                    }
                }
            }

            // ── Retention curve — running quality average ───────────────────
            ChartCard {
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                Layout.bottomMargin: Platform.pagePadding
                title: qsTr("Retention curve")
                subtitle: qsTr("Running average of daily grade; trending up = improving recall")
                emptyText: root.analytics.daily.length < 2 ? "Not enough data yet." : ""

                chart: Canvas {
                    anchors.fill: parent
                    property var data: root.analytics.daily
                    property real progress: root._chartProgress
                    onDataChanged:     requestPaint()
                    onProgressChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const d = data
                        if (!d || d.length < 2) return

                        // Build a running average series.
                        const series = []
                        let sum = 0
                        for (let i = 0; i < d.length; i++) {
                            sum += d[i].avgQuality
                            series.push(sum / (i + 1))
                        }

                        const pad = 24
                        const w = width - pad * 2
                        const h = height - pad * 2
                        const maxQ = 3
                        function px(i) { return pad + (i / (series.length - 1)) * w }
                        function py(q) { return pad + h - (q / maxQ) * h }

                        // Filled area under the curve, animated.
                        const limit = Math.max(2, Math.ceil(series.length * progress))
                        ctx.fillStyle = Qt.rgba(Platform.accent.r, Platform.accent.g, Platform.accent.b, 0.18)
                        ctx.beginPath()
                        ctx.moveTo(px(0), pad + h)
                        for (let i = 0; i < limit; i++) ctx.lineTo(px(i), py(series[i]))
                        ctx.lineTo(px(limit - 1), pad + h)
                        ctx.closePath()
                        ctx.fill()

                        // Curve stroke.
                        ctx.strokeStyle = Platform.accentDark
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        for (let i = 0; i < limit; i++) {
                            const x = px(i), y = py(series[i])
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
            }
        }
    }
}



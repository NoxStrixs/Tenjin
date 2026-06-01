pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import TenjinView

// Row-grouped grid of content blocks.
//
// Layout model (matches the DB row/col/rowSpan/colSpan columns):
//   - Blocks are grouped by their `row`. Each group renders as a horizontal
//     band; blocks within a band are ordered by `col` and share the band width
//     in proportion to their colSpan.
//   - Dividers (blockType 3) always render full-width on their own band.
//   - Edit mode adds: drag a block left/right to change its column / move
//     between bands; drag the right edge to grow/shrink colSpan; per-block
//     controls to push to a new row.
//   - "Merge" visual: adjacent same-type blocks in the same column with no gap
//     render with a shared edge (no inter-block margin) — handled by comparing
//     neighbors in the band.
Flickable {
    id: root
    contentWidth: width
    // Never let content collapse below the viewport, otherwise the centered
    // empty-state text is positioned against a zero-height content rect and
    // gets clipped at the top.
    contentHeight: Math.max(bands.implicitHeight, height)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 6
            radius: 3
            color: Platform.border
            opacity: parent.pressed ? 0.9 : 0.5
        }
    }

    property bool editMode: false
    readonly property int colGap: 10
    readonly property int rowGap: 12

    // Build a row-grouped structure from the flat model.
    // Returns an array of bands; each band = { row, blocks:[{index, id, type, content, row, col, colSpan}] }.
    function buildBands() {
        const m = appVM.entryVM.contentModel

        // 1. Safety Guard: If model is null or rowCount is 0, exit immediately
        if (!m || m.rowCount() === 0) {
            return []
        }

        const n = m.rowCount()
        const byRow = {}

        for (let i = 0; i < n; ++i) {
            const idx = m.index(i, 0)

            // 2. Safety Guard: Ensure data exists before using it
            const rawRow = m.data(idx, Qt.UserRole + 5)
            const row = (rawRow !== undefined && rawRow !== null) ? Number(rawRow) : 0

            const b = {
                index: i,
                id:       m.data(idx, Qt.UserRole + 1) ?? 0,
                type:     m.data(idx, Qt.UserRole + 3) ?? 0,
                content:  m.data(idx, Qt.UserRole + 4) ?? "",
                row:      row,
                col:      m.data(idx, Qt.UserRole + 6) ?? 0,
                colSpan:  m.data(idx, Qt.UserRole + 8) ?? 1,
                pos:      m.data(idx, Qt.UserRole + 9) ?? ""
            }
            if (!byRow[row]) byRow[row] = []
            byRow[row].push(b)
        }

        const keys = Object.keys(byRow);
        // 3. Safety Guard: Ensure we have keys to sort
        if (keys.length === 0) return []

        const sortedKeys = keys.sort((a, b) => Number(a) - Number(b));

        return sortedKeys.map(key => ({
            row: Number(key),
            blocks: byRow[key].sort((a, b) => a.col - b.col)
        }))
    }

    property var bandData: []
    function refresh() { bandData = buildBands() }
    Component.onCompleted: refresh()

    // Rebuild whenever the model changes.
    Connections {
        target: appVM.entryVM.contentModel
        function onModelReset()              { root.refresh() }
        function onRowsInserted()            { root.refresh() }
        function onRowsRemoved()             { root.refresh() }
        function onRowsMoved()               { root.refresh() }
        function onDataChanged()             { root.refresh() }
    }
    Connections {
        target: appVM.entryVM
        function onEditModeChanged()         { root.refresh() }
    }

    Column {
        id: bands
        width: root.width
        spacing: root.rowGap

        Repeater {
            model: root.bandData

            // One horizontal band per row.
            delegate: Item {
                id: band
                required property var modelData
                required property int index
                width: bands.width
                height: bandRow.implicitHeight

                readonly property int totalSpan: {
                    let s = 0
                    for (const b of band.modelData.blocks) s += Math.max(1, b.colSpan)
                    return Math.max(s, 1)
                }
                readonly property bool isDividerBand:
                    band.modelData.blocks.length === 1 && band.modelData.blocks[0].type === 3

                Row {
                    id: bandRow
                    width: parent.width
                    spacing: root.colGap

                    Repeater {
                        model: band.modelData.blocks

                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index

                            // Proportional width by colSpan, minus gaps.
                            width: {
                                const gaps = (band.modelData.blocks.length - 1) * root.colGap
                                const avail = bandRow.width - gaps
                                return avail * Math.max(1, cell.modelData.colSpan) / band.totalSpan
                            }
                            height: cell.modelData.type === 4 ? formula.implicitHeight
                                                              : content.implicitHeight

                            // Divider renders as a labeled rule, full band width.
                            // Inlined (not a Loader+Component) so it reads
                            // cell.modelData directly from its own scope — avoids the
                            // cross-boundary id resolution that fails under
                            // ComponentBehavior: Bound.
                            Item {
                                id: divItem
                                anchors.fill: parent
                                visible: cell.modelData.type === 3

                                RowLayout {
                                    id: divRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Text {
                                        visible: text.length > 0
                                        text: cell.modelData.content
                                        color: Platform.textMuted
                                        font.pixelSize: Platform.fontBase - 1
                                        font.bold: true
                                    }
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border }
                                    ToolButton {
                                        id: divEdit
                                        visible: root.editMode
                                        text: "\u270E"
                                        implicitWidth: Platform.touchTarget * 0.8
                                        implicitHeight: Platform.touchTarget * 0.8
                                        contentItem: Text { text: divEdit.text; color: Platform.textMuted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: divNameDialog.open()
                                    }
                                    ToolButton {
                                        id: divDel
                                        visible: root.editMode
                                        text: "\u2715"
                                        implicitWidth: Platform.touchTarget * 0.8
                                        implicitHeight: Platform.touchTarget * 0.8
                                        contentItem: Text { text: divDel.text; color: Platform.danger; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: appVM.entryVM.deleteContentBlock(cell.modelData.id)
                                    }
                                }
                                ThemedDialog {
                                    id: divNameDialog
                                    parent: Overlay.overlay
                                    title: "Divider label"
                                    padding: 20
                                    width: 300

                                    TextField {
                                        id: divNameField
                                        width: 240
                                        text: cell.modelData.content
                                        placeholderText: "Optional label"
                                        color: Platform.textPrimary
                                        background: Rectangle {
                                            radius: Platform.radius
                                            color: Platform.surface
                                            border.color: divNameField.activeFocus ? Platform.accent : Platform.border
                                            border.width: divNameField.activeFocus ? 2 : 1
                                        }
                                    }
                                    onAccepted: appVM.entryVM.updateContentBlockText(cell.modelData.id, divNameField.text)
                                }
                            }

                            // Normal block. Stays in place during drag — a separate
                            // floating proxy (below) carries the Drag payload, which
                            // avoids the reparent-to-root stranding seen previously.
                            ContentBlock {
                                id: content
                                width: parent.width
                                visible: cell.modelData.type !== 3 && cell.modelData.type !== 4
                                blockId:      cell.modelData.id
                                blockType:    cell.modelData.type
                                blockContent: cell.modelData.content
                                blockPos:     cell.modelData.pos
                                editMode:     root.editMode

                                property int blockRow: cell.modelData.row
                                property int blockCol: cell.modelData.col

                                held:         cellDrag.drag.active
                                z:            cellDrag.drag.active ? 5 : 1
                                visualIndex:  cell.modelData.index

                                onDeleteRequested: (bid) => appVM.entryVM.deleteContentBlock(bid)
                                onContentEdited:   (bid, t) => appVM.entryVM.updateContentBlockText(bid, t)
                                onPosEdited:       (bid, p) => appVM.entryVM.setBlockPartOfSpeech(bid, p)
                            }

                            // Formula block (content type 4 / Formula). Renders LaTeX
                            // natively via appVM.renderFormula() (a LaTeX-subset →
                            // Qt rich-text converter; no WebView, fully offline).
                            // Same edit/content contract as ContentBlock.
                            FormulaBlock {
                                id: formula
                                width: parent.width
                                visible: cell.modelData.type === 4
                                blockId:      cell.modelData.id
                                blockContent: cell.modelData.content
                                editMode:     root.editMode
                                held:         cellDrag.drag.active
                                z:            cellDrag.drag.active ? 5 : 1
                                visualIndex:  cell.modelData.index

                                onDeleteRequested: (bid) => appVM.entryVM.deleteContentBlock(bid)
                                onContentEdited:   (bid, t) => appVM.entryVM.updateContentBlockText(bid, t)
                            }

                            // Floating drag proxy: carries the Drag payload so the
                            // real block never leaves the layout. Parented to the
                            // Flickable root so it can travel over any band/cell.
                            Item {
                                id: dragProxy
                                parent: root
                                width: cell.width
                                height: cell.height
                                visible: cellDrag.drag.active
                                z: 50

                                property int blockId:  cell.modelData.id
                                property int blockRow: cell.modelData.row
                                property int blockCol: cell.modelData.col

                                Drag.active: cellDrag.drag.active
                                Drag.source: dragProxy
                                Drag.keys: ["content-block"]
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Rectangle {
                                    anchors.fill: parent
                                    color: Platform.surfaceAlt
                                    border.color: Platform.accent
                                    border.width: 2
                                    radius: Platform.radius
                                    opacity: 0.85
                                }
                            }

                            // Drag handle (top-left), edit mode only.
                            MouseArea {
                                id: cellDrag
                                z: 10
                                width: Platform.touchTarget
                                height: Platform.touchTarget
                                anchors { left: parent.left; top: parent.top; margins: 6 }
                                enabled: root.editMode && cell.modelData.type !== 3
                                visible: enabled
                                cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor

                                // Drag the floating proxy, not the real block.
                                drag.target: dragProxy

                                onPressed: {
                                    const gp = content.mapToItem(root, 0, 0)
                                    dragProxy.x = gp.x
                                    dragProxy.y = gp.y
                                }
                                onReleased: {
                                    // MouseArea-driven drags do NOT auto-emit a drop
                                    // event — we must call Drag.drop() explicitly so
                                    // the DropArea under the cursor gets onDropped.
                                    dragProxy.Drag.drop()
                                }
                            }

                            // Resize handle (bottom-right corner), edit mode only.
                            MouseArea {
                                id: spanHandle
                                z: 10
                                width: 24
                                height: 24
                                anchors { right: parent.right; bottom: parent.bottom }
                                enabled: root.editMode && cell.modelData.type !== 3
                                visible: enabled
                                cursorShape: Qt.SizeFDiagCursor
                                property real accum: 0
                                property int  startSpan: 1
                                property int  lastSpan: 1
                                onPressed: {
                                    accum = 0
                                    startSpan = Math.max(1, cell.modelData.colSpan)
                                    lastSpan = startSpan
                                }
                                onPositionChanged: (m) => {
                                    if (!pressed) return
                                    // mouseX is relative to this handle (12px wide),
                                    // so offset from center accumulates drag distance.
                                    accum += (m.x - width / 2)
                                    // Each ~120px of drag = one column-span step.
                                    const delta = Math.round(accum / 120)
                                    const newSpan = Math.max(1, startSpan + delta)
                                    // Compare against the last value WE committed, not
                                    // cell.modelData.colSpan (a stale snapshot), so we
                                    // only write when the span actually changes.
                                    if (newSpan !== lastSpan) {
                                        lastSpan = newSpan
                                        appVM.entryVM.setBlockSpan(cell.modelData.id, 1, newSpan)
                                    }
                                }
                                Rectangle {
                                    id: grabPad
                                    width: 18
                                    height: 18
                                    radius: 3
                                    anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                                    color: spanHandle.pressed ? Platform.accent : Platform.surfaceAlt
                                    border.color: Platform.accentDark
                                    border.width: 1
                                    visible: spanHandle.enabled
                                    // Two diagonal grip lines (Rectangles, not Canvas,
                                    // so they always render).
                                    Rectangle {
                                        width: 10; height: 1.5
                                        color: Platform.accentDark
                                        x: parent.width - 13; y: parent.height - 5
                                        rotation: -45
                                        transformOrigin: Item.Center
                                    }
                                    Rectangle {
                                        width: 6; height: 1.5
                                        color: Platform.accentDark
                                        x: parent.width - 9; y: parent.height - 4
                                        rotation: -45
                                        transformOrigin: Item.Center
                                    }
                                }
                            }

                            // Drop target: dropping block B onto this cell places
                            // B into the SAME band, beside the target — this is how
                            // a multi-column row is created.
                            DropArea {
                                id: cellDrop
                                z: 9
                                anchors.fill: parent
                                keys: ["content-block"]
                                onDropped: (drop) => {
                                    const src = drop.source
                                    // C++ setBlockGrid does not reflow, so pick a
                                    // column past every existing block in this band
                                    // to avoid an overlap collision.
                                    let maxCol = 0
                                    for (const b of band.modelData.blocks)
                                        if (b.id !== src.blockId)
                                            maxCol = Math.max(maxCol, b.col)
                                    appVM.entryVM.setBlockPosition(src.blockId, band.modelData.row, maxCol + 1)
                                    drop.accept()
                                }
                                // Highlight when a block hovers, so the target is clear.
                                Rectangle {
                                    anchors.fill: parent
                                    visible: cellDrop.containsDrag
                                    color: "transparent"
                                    border.color: Platform.accent
                                    border.width: 2
                                    radius: Platform.radius
                                }
                            }
                        }
                    }
                }
            }
        }

        // Dedicated DropArea to push blocks to a completely new row
        DropArea {
            id: newRowDrop
            width: parent.width
            height: 40
            visible: root.editMode
            keys: ["content-block"]

            Rectangle {
                anchors.fill: parent
                color: newRowDrop.containsDrag ? Platform.border : "transparent"
                border.color: Platform.border
                border.width: 1
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: "+ Drop here for new row"
                    color: Platform.textMuted
                }
            }

            onDropped: (drop) => {
                const src = drop.source
                if (!src || src.blockId === undefined) return
                const nextRow = appVM.entryVM.rowCountForLayout()
                appVM.entryVM.setBlockPosition(src.blockId, nextRow, 0)
                drop.accept()
            }
        }
    }

    // Empty state.
    Text {
        anchors.centerIn: parent
        visible: root.bandData.length === 0
        text: root.editMode ? "No content yet — use the buttons below to add some."
                            : "No content yet. Click Edit to start."
        color: Platform.textMuted
        font.pixelSize: Platform.fontBase
        horizontalAlignment: Text.AlignHCenter
    }
}



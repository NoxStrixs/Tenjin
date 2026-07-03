pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQml.Models
import TenjinView

// Layout model (matches the DB row/col/rowSpan/colSpan columns):
//   - Blocks are grouped by their `row`. Each group renders as a horizontal
//     band, and are ordered by their `col`. They share the band width
//     in proportion to their colSpan.
//   - Dividers always render full-width on their own band.
//   - Edit mode adds: drag a block left/right to change its column / move
//     between bands; drag the right edge to grow/shrink colSpan; per-block
//     controls to push to a new row.
//   - "Merge" visual: adjacent same-type blocks in the same column with no gap
//     render with a shared edge

Flickable {
    id: root
    contentWidth: width
    // Never let content collapse below the viewport, otherwise the centered
    // empty-state text is positioned against a zero-height content rect and
    // gets clipped at the top.
    // Add the keyboard's height as extra scrollable space when it's up, so a
    // focused block can be scrolled clear of the on-screen keyboard instead of sitting under it.
    readonly property real _kb: Qt.inputMethod.visible
        ? Qt.inputMethod.keyboardRectangle.height / Platform.devicePixelRatio
        : 0
    contentHeight: Math.max(bands.implicitHeight + _kb, height)
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
    function buildBands() {
        const m = appVM.entryVM.contentModel

        if (!m || m.rowCount() === 0) {
            return []
        }

        const n = m.rowCount()
        const byRow = {}

        for (let i = 0; i < n; i++) {
            const idx = m.index(i, 0)

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
        if (keys.length === 0) return []

        const sortedKeys = keys.sort((a, b) => Number(a) - Number(b));

        return sortedKeys.map(key => ({
            row: Number(key),
            blocks: byRow[key].sort((a, b) => a.col - b.col)
        }))
    }

    property var bandData: []
    property bool _refreshing: false
    function refresh() {
        // Guard against re-entrancy: building the bands can, on some Qt
        // versions, cause a child to emit a model signal mid-layout, which would
        // re-enter refresh() and trip a "Binding loop for model" warning.
        if (_refreshing)
            return
        _refreshing = true
        bandData = buildBands()
        _refreshing = false
    }
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
                            // Inlined so it reads cell.modelData directly from its own scope.
                            // This avoids the cross-boundary id resolution that fails under
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
                                    Rectangle {
                                        id: divEdit
                                        visible: root.editMode
                                        implicitWidth: divEditLabel.implicitWidth + 18
                                        implicitHeight: Platform.touchTarget * 0.8
                                        radius: Platform.radius
                                        color: divEditArea.containsMouse ? Platform.surfaceAlt : "transparent"
                                        border.color: Platform.border
                                        border.width: 1
                                        Text { id: divEditLabel; anchors.centerIn: parent; text: qsTr("Edit"); color: Platform.accentDark; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                                        MouseArea { id: divEditArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: divNameDialog.open() }
                                    }
                                    Rectangle {
                                        id: divDel
                                        visible: root.editMode
                                        implicitWidth: divDelLabel.implicitWidth + 18
                                        implicitHeight: Platform.touchTarget * 0.8
                                        radius: Platform.radius
                                        color: divDelArea.containsMouse ? Platform.danger : "transparent"
                                        border.color: Platform.danger
                                        border.width: 1
                                        Text { id: divDelLabel; anchors.centerIn: parent; text: qsTr("Delete"); color: divDelArea.containsMouse ? Platform.textOnDark : Platform.danger; font.pixelSize: Platform.fontBase - 1; font.bold: true }
                                        MouseArea { id: divDelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appVM.entryVM.deleteContentBlock(cell.modelData.id) }
                                    }
                                }
                                ThemedDialog {
                                    id: divNameDialog
                                    parent: Overlay.overlay
                                    title: qsTr("Divider label")
                                    padding: 20
                                    width: 300

                                    TextField {
                                        id: divNameField
                                        width: 240
                                        text: cell.modelData.content
                                        placeholderText: qsTr("Optional label")
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

                            // Normal block. Stays in place during drag, a separate
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
                                blockColSpan: cell.modelData.colSpan ?? 1
                                blockRowSpan: cell.modelData.rowSpan ?? 1
                                editMode:     root.editMode

                                property int blockRow: cell.modelData.row
                                property int blockCol: cell.modelData.col

                                held:         cellDrag.drag.active
                                z:            cellDrag.drag.active ? 5 : 1
                                visualIndex:  cell.modelData.index

                                onDeleteRequested: (bid) => appVM.entryVM.deleteContentBlock(bid)
                                onContentEdited:   (bid, t) => appVM.entryVM.updateContentBlockText(bid, t)
                                onPosEdited:       (bid, p) => appVM.entryVM.setBlockPartOfSpeech(bid, p)
                                onSpanChanged:     (bid, rs, cs) => appVM.entryVM.setBlockSpan(bid, rs, cs)
                            }

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

                                drag.target: dragProxy

                                onPressed: {
                                    const gp = content.mapToItem(root, 0, 0)
                                    dragProxy.x = gp.x
                                    dragProxy.y = gp.y
                                }
                                onReleased: {
                                    // MouseArea-driven drags do NOT auto-emit a drop
                                    // event. Must call Drag.drop() explicitly so
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
                                    const delta = Math.round(accum / 120)
                                    const newSpan = Math.max(1, startSpan + delta)
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
                            // B into the SAME band, beside the target.
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
                    text: qsTr("+ Drop here for new row")
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
        text: root.editMode ? qsTr("No content yet. Use the buttons below to add some.")
                            : "No content yet. Click Edit to start."
        color: Platform.textMuted
        font.pixelSize: Platform.fontBase
        horizontalAlignment: Text.AlignHCenter
    }
}






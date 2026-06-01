pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// A LaTeX formula block (content kind "formula").
//
// Edit mode : a LaTeX text field plus a palette of buttons that insert snippets
//             at the cursor — the user never has to know LaTeX syntax.
// View mode : the formula rendered via KaTeX inside a WebEngineView when
//             WEBVIEW_SUPPORT was compiled in; otherwise a monospaced raw-LaTeX
//             fallback so the block is still legible.
//
// Presentational only: it emits contentEdited(bid, newLatex) and deleteRequested
// exactly like the other block delegates; persistence is the ViewModel's job.
Rectangle {
    id: root

    property int    blockId
    property string blockContent      // the LaTeX source
    property bool   editMode: false
    property bool   held: false
    property int    visualIndex: -1

    signal deleteRequested(int bid)
    signal contentEdited(int bid, string newContent)

    // Whether offline LaTeX rendering (QtWebView + bundled KaTeX) is available,
    // set by the app via appVM. When false we show a raw-LaTeX text fallback.
    property bool renderAvailable: (typeof appVM !== "undefined"
                                    && appVM.formulaRenderingAvailable !== undefined)
                                   ? appVM.formulaRenderingAvailable : false

    // Palette: label shown on the button, and the LaTeX snippet inserted.
    // "$1" (if present) marks where the caret should land after insertion.
    readonly property var palette: [
        { label: "x²",  snippet: "^{$1}" },
        { label: "x₂",  snippet: "_{$1}" },
        { label: "a/b", snippet: "\\frac{$1}{}" },
        { label: "√",   snippet: "\\sqrt{$1}" },
        { label: "∫",   snippet: "\\int_{$1}^{} \\, dx" },
        { label: "∑",   snippet: "\\sum_{$1}^{}" },
        { label: "∏",   snippet: "\\prod_{$1}^{}" },
        { label: "lim", snippet: "\\lim_{$1 \\to }" },
        { label: "π",   snippet: "\\pi" },
        { label: "θ",   snippet: "\\theta" },
        { label: "α",   snippet: "\\alpha" },
        { label: "β",   snippet: "\\beta" },
        { label: "≤",   snippet: "\\leq" },
        { label: "≥",   snippet: "\\geq" },
        { label: "≠",   snippet: "\\neq" },
        { label: "→",   snippet: "\\to" },
        { label: "×",   snippet: "\\times" },
        { label: "·",   snippet: "\\cdot" }
    ]

    color: held ? Platform.surfaceAlt : Platform.surface
    radius: Platform.radius
    border.color: (editMode || held) ? Platform.accent : Platform.border
    border.width: 1
    clip: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: layout.implicitHeight + 20

    Behavior on color { ColorAnimation { duration: 120 } }

    // Insert `snippet` at the caret of the editor, positioning the caret at the
    // "$1" placeholder if one is present.
    function insertSnippet(snippet) {
        const marker = snippet.indexOf("$1")
        const clean  = snippet.replace("$1", "")
        const at     = latexField.cursorPosition
        const before = latexField.text.slice(0, at)
        const after  = latexField.text.slice(at)
        latexField.text = before + clean + after
        latexField.cursorPosition = (marker >= 0) ? at + marker : at + clean.length
        latexField.forceActiveFocus()
        root.contentEdited(root.blockId, latexField.text)
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        // Header: kind chip + remove.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                radius: 4
                color: Platform.surfaceAlt
                border.color: Platform.border
                implicitWidth: kindLabel.implicitWidth + 12
                implicitHeight: kindLabel.implicitHeight + 6
                Text {
                    id: kindLabel
                    anchors.centerIn: parent
                    text: "formula"
                    color: Platform.textMuted
                    font.pixelSize: 11
                }
            }

            Item { Layout.fillWidth: true }

            IconBtn {
                visible: root.editMode
                glyph: "\u2715"
                onActivated: root.deleteRequested(root.blockId)
            }
        }

        // ── Edit mode: LaTeX field + palette ──────────────────────────────────
        TextArea {
            id: latexField
            visible: root.editMode
            Layout.fillWidth: true
            text: root.blockContent
            placeholderText: "LaTeX, e.g.  \\frac{a}{b}"
            wrapMode: TextEdit.WrapAnywhere
            font.family: "monospace"
            color: Platform.textPrimary
            selectByMouse: true
            onTextChanged: if (activeFocus) root.contentEdited(root.blockId, text)
            background: Rectangle {
                color: Platform.surfaceAlt
                radius: 4
                border.color: latexField.activeFocus ? Platform.accent : Platform.border
            }
        }

        Flow {
            visible: root.editMode
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.palette
                delegate: Button {
                    required property var modelData
                    text: modelData.label
                    font.pixelSize: 13
                    implicitHeight: 28
                    onClicked: root.insertSnippet(modelData.snippet)
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.snippet.replace("$1", "")
                }
            }
        }

        // ── View mode: rendered formula ───────────────────────────────────────
        // KaTeX renderer when WebEngine is available.
        Loader {
            id: katexLoader
            visible: !root.editMode && root.renderAvailable && root.blockContent.length > 0
            active: visible
            Layout.fillWidth: true
            sourceComponent: FormulaWebView {
                latex: root.blockContent
            }
        }

        // Fallback: raw LaTeX when WebEngine isn't compiled in.
        Text {
            visible: !root.editMode && !root.renderAvailable && root.blockContent.length > 0
            Layout.fillWidth: true
            text: root.blockContent
            font.family: "monospace"
            color: Platform.textPrimary
            wrapMode: Text.WrapAnywhere
        }

        // Empty hint.
        Text {
            visible: !root.editMode && root.blockContent.length === 0
            text: "(empty formula)"
            color: Platform.textMuted
            font.italic: true
        }
    }
}

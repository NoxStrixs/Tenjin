pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// A LaTeX formula block
// Edit mode : a LaTeX text field plus a palette of buttons that insert snippets
//             at the cursor — the user never has to know LaTeX syntax.
// View mode : the formula rendered natively via appVM.renderFormula() (a
//             LaTeX-subset → Qt rich-text converter). No WebView, no external
//             assets, fully offline.
Rectangle {
    id: root

    property int    blockId
    property string blockContent      // the LaTeX source
    property bool   editMode: false
    property bool   held: false
    property int    visualIndex: -1

    signal deleteRequested(int bid)
    signal contentEdited(int bid, string newContent)

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

        // Header: kind chip and remove.
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

        // Edit mode: LaTeX field and palette
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
                // Themed palette button, matching the note/definition toolbar's
                // FmtBtn treatment (Platform colors, hover, touch sizing).
                // Widthgrows with the label since entries vary ("x\u00B2" vs "lim").
                delegate: Rectangle {
                    id: palBtn
                    required property var modelData
                    height: Platform.isMobile ? 34 : 26
                    implicitWidth: Math.max(height, palLabel.implicitWidth + 14)
                    radius: Platform.radius - 2
                    color: palArea.containsMouse ? Platform.accent : Platform.surface
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        id: palLabel
                        anchors.centerIn: parent
                        text: palBtn.modelData.label
                        color: palArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    MouseArea {
                        id: palArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Keep the editor's selection/caret while clicking.
                        onPressed: (m) => m.accepted = true
                        onClicked: root.insertSnippet(palBtn.modelData.snippet)
                        ToolTip.visible: containsMouse
                        ToolTip.text: palBtn.modelData.snippet.replace("$1", "")
                    }
                }
            }
        }

        // FormulaRenderer converts the LaTeX subset to Qt rich text.
        Text {
            visible: !root.editMode && root.blockContent.length > 0
            Layout.fillWidth: true
            textFormat: Text.RichText
            text: appVM.renderFormula(root.blockContent)
            color: Platform.textPrimary
            font.pixelSize: Platform.fontLarge
            wrapMode: Text.WordWrap
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


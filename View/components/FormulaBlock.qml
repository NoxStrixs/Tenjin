pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
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
        { label: qsTr("a/b"), snippet: "\\frac{$1}{}" },
        { label: "√",   snippet: "\\sqrt{$1}" },
        { label: "∫",   snippet: "\\int_{$1}^{} \\, dx" },
        { label: "∑",   snippet: "\\sum_{$1}^{}" },
        { label: "∏",   snippet: "\\prod_{$1}^{}" },
        { label: qsTr("lim"), snippet: "\\lim_{$1 \\to }" },
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

    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

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
        anchors.margins: Platform.spacingLg
        spacing: 8

        // Header: kind chip and remove.
        RowLayout {
            Layout.fillWidth: true
            spacing: Platform.spacingMd

            Rectangle {
                radius: 4
                color: Platform.surfaceAlt
                border.color: Platform.border
                implicitWidth: kindLabel.implicitWidth + 12
                implicitHeight: kindLabel.implicitHeight + 6
                Text {
                    id: kindLabel
                    anchors.centerIn: parent
                    text: qsTr("formula")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontSmall
                }
            }

            Item { Layout.fillWidth: true }

            IconBtn {
                visible: root.editMode
                glyph: TenjinIcons.close
                onActivated: root.deleteRequested(root.blockId)
            }
        }

        // Edit mode: LaTeX field and palette
        TextArea {
            id: latexField
            visible: root.editMode
            Layout.fillWidth: true
            text: root.blockContent
            placeholderText: qsTr("LaTeX, e.g.  \\frac{a}{b}")
            placeholderTextColor: Platform.textMuted
            wrapMode: TextEdit.WrapAnywhere
            font.family: Platform.fontMono
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
            spacing: Platform.spacingSm

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

            // "More symbols" — opens the categorized + searchable picker for the
            // full catalog (Greek, operators, relations, arrows, calculus,
            // structures) beyond the quick-access row above.
            Rectangle {
                id: moreBtn
                height: Platform.isMobile ? 34 : 26
                implicitWidth: moreLabel.implicitWidth + 18
                radius: Platform.radius - 2
                color: moreArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                border.color: Platform.accent
                border.width: 1

                Row {
                    id: moreLabel
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: TenjinIcons.formula
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontBase
                        color: moreArea.containsMouse ? Platform.textOnDark : Platform.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: qsTr("More\u2026")
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                        color: moreArea.containsMouse ? Platform.textOnDark : Platform.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (m) => m.accepted = true
                    onClicked: {
                        if (symbolPicker.opened) symbolPicker.close()
                        else symbolPicker.open()
                    }
                }
            }
        }

        // The picker inserts at the caret (reusing insertSnippet) and stays open
        // so multiple symbols can be added before dismissing. Parented to the
        // block so it overlays the editor; positioned just under the palette.
        MathSymbolPicker {
            id: symbolPicker
            parent: root
            x: Platform.spacingLg
            y: Math.min(moreBtn.mapToItem(root, 0, 0).y + moreBtn.height + 4,
                        root.height - implicitHeight)
            onPicked: (snippet) => root.insertSnippet(snippet)
        }

        // Real math typesetting via MicroTeX (stacked fractions, radicals,
        // matrices — none of which Qt rich text can lay out).
        FormulaView {
            id: formulaView
            visible: !root.editMode && root.blockContent.length > 0
                     && errorString.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            latex: root.blockContent
            color: Platform.textPrimary
            fontSize: Platform.fontLarge
        }

        // If MicroTeX can't parse the input (or its resources are unavailable),
        // show the source plus the reason rather than a blank space.
        ColumnLayout {
            visible: !root.editMode && root.blockContent.length > 0
                     && formulaView.errorString.length > 0
            Layout.fillWidth: true
            spacing: Platform.spacingXs
            Text {
                Layout.fillWidth: true
                text: root.blockContent
                color: Platform.textPrimary
                font.family: Platform.fontMono
                font.pixelSize: Platform.fontBase
                wrapMode: Text.WrapAnywhere
            }
            Text {
                Layout.fillWidth: true
                text: formulaView.errorString
                color: Platform.danger
                font.pixelSize: Platform.fontSmall
                wrapMode: Text.WordWrap
            }
        }

        // Empty hint.
        Text {
            visible: !root.editMode && root.blockContent.length === 0
            text: qsTr("(empty formula)")
            color: Platform.textMuted
            font.italic: true
        }
    }
}



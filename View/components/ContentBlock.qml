pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// A single content block
// - Definition / Note  → editable multi-line text.
// - Media Path         → a file path with a "Browse…" picker; if the path points
//                        to an image it is rendered inline.

// Layout note: the root height is driven by content via implicitHeight and the
// inner column is anchored to top/left/right
Rectangle {
    id: root

    property int     blockId
    property int     blockType     // 0=def, 1=media, 2=note
    property string  blockContent
    property string  blockPos       // part of speech (definitions only)
    property bool    editMode: false
    property bool    held: false   // set by the drag wrapper
    property int     visualIndex: -1

    // Grid span -- set by GridContentView from the model. Drives the +/-
    // controls in the header so the user can grow/shrink a block without
    // having to grab the drag edge. Defaults are 1/1 so blocks placed
    // outside a grid (e.g. the legacy linear renderer) still behave.
    property int     blockColSpan: 1
    property int     blockRowSpan: 1

    signal deleteRequested(int bid)
    signal contentEdited(int bid, string newContent)
    signal posEdited(int bid, string newPos)
    signal spanChanged(int bid, int rowSpan, int colSpan)

    readonly property bool isDefinition: blockType === 0
    readonly property var posOptions: ["", "noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "other"]

    readonly property var typeNames: ["definition", "media", "note", "divider", "formula", "header", "tense"]
    readonly property bool isMedia:    blockType === 1
    readonly property bool isNote:     blockType === 2
    readonly property bool isDivider:  blockType === 3
    readonly property bool isFormula:  blockType === 4
    readonly property bool isHeader:   blockType === 5
    readonly property bool isTense:    blockType === 6
    readonly property bool isCloze:    blockType === 7

    property bool webEngineAvailable: (typeof appVM !== "undefined"
                                       && appVM.webEngineAvailable !== undefined)
                                      ? appVM.webEngineAvailable : false

    // Classify the media path/URL.
    readonly property string mediaKind: {
        if (!isMedia || blockContent.length === 0) return "none"
        const p = blockContent.toLowerCase()
        // Web embed
        if (p.startsWith("http://") || p.startsWith("https://")) return "embed"
        const ext = function (s) { const i = p.lastIndexOf("."); return i < 0 ? "" : p.slice(i) }
        const e = ext(p)
        if ([".png", ".jpg", ".jpeg", ".bmp", ".webp", ".svg"].indexOf(e) >= 0) return "image"
        if (e === ".gif") return "gif"
        if ([".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v"].indexOf(e) >= 0) return "video"
        if ([".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac"].indexOf(e) >= 0) return "audio"
        return "file"
    }
    readonly property bool isImagePath: mediaKind === "image" || mediaKind === "gif"

    // Just the file name for tooltips/labels
    readonly property string mediaFileName: {
        if (blockContent.length === 0) return ""
        const s = blockContent.replace(/[\\/]+$/, "")
        const i = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"))
        return i < 0 ? s : s.slice(i + 1)
    }

    color: held ? Platform.surfaceAlt : Platform.surface
    radius: Platform.radius
    // Newly-added blocks pulse for ~2s: accent-coloured 2px border plus a
    // small scale wobble. The match is driven by EntryViewModel.lastAddedBlockId
    // which addContentBlock sets after creating each block.
    readonly property bool _isNewlyAdded: appVM.entryVM.lastAddedBlockId === root.blockId
                                           && root.blockId > 0
    border.color: _isNewlyAdded ? Platform.accent
                                : (editMode || held) ? Platform.accent
                                                       : Platform.border
    border.width: _isNewlyAdded ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
    Behavior on border.width { NumberAnimation { duration: Platform.effDurationFast } }

    SequentialAnimation on scale {
        running: root._isNewlyAdded
        loops: 3
        NumberAnimation { from: 1.0;  to: 1.02; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
        NumberAnimation { from: 1.02; to: 1.0;  duration: Platform.effDurationMed; easing.type: Easing.InCubic }
    }
    // Clear the pulse after ~2s so a second add of a different block
    // pulses cleanly. Triggered by the binding becoming true.
    Timer {
        interval: 2200
        running: root._isNewlyAdded
        repeat: false
        onTriggered: appVM.entryVM.lastAddedBlockId = -1
    }

    clip: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: layout.implicitHeight + 12

    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        // Header: drag handle, type chip, remove button.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: root.editMode
                text: TenjinIcons.drag
                font.family: TenjinIcons.family
                color: Platform.textMuted
                font.pixelSize: Platform.fontLarge
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                visible: !root.isMedia
                Layout.alignment: Qt.AlignVCenter
                // For non-note blocks: snug chip around the static type label.
                // For notes: wider chip so the TextField has room to breathe.
                implicitWidth: root.isNote && root.editMode
                               ? Math.max(noteLabelEdit.implicitWidth + 24, 110)
                               : typeLabel.implicitWidth + 16
                implicitHeight: Platform.isMobile ? 28 : 22
                radius: height / 2
                color: Platform.surfaceAlt
                border.color: root.isNote && root.editMode && noteLabelEdit.activeFocus
                              ? Platform.accent : Platform.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }

                // Static label -- visible for every type EXCEPT notes
                // (whose label is user-editable below). For notes in read
                // mode we still use this Text, fed from the pos field.
                Text {
                    id: typeLabel
                    anchors.centerIn: parent
                    visible: !(root.isNote && root.editMode)
                    text: {
                        if (root.isNote)
                            return root.blockPos.length > 0 ? root.blockPos : "Note"
                        return root.typeNames[root.blockType] ?? "note"
                    }
                    color: Platform.accentDark
                    font.pixelSize: Platform.fontBase - 2
                    font.bold: true
                }

                // Editable label for notes. Reuses the pos field as a
                // generic "custom label" for note blocks -- the pos
                // column on the content table is otherwise only set by
                // Definition blocks. posEdited() flows through the same
                // service path setBlockPartOfSpeech uses for definitions.
                TextField {
                    id: noteLabelEdit
                    visible: root.isNote && root.editMode
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: root.blockPos
                    placeholderText: qsTr("Label (e.g. Etymology)")
                    placeholderTextColor: Platform.textMuted
                    color: Platform.accentDark
                    font.pixelSize: Platform.fontBase - 2
                    font.bold: true
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Rectangle { color: "transparent" }
                    onEditingFinished: {
                        if (text.trim() !== root.blockPos)
                            root.posEdited(root.blockId, text.trim())
                    }
                }
            }

            // Part-of-speech picker (definitions only, edit mode).
            ComboBox {
                id: posCombo
                visible: root.isDefinition && root.editMode
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Platform.isMobile ? 28 : 22
                implicitWidth: Platform.isMobile ? 160 : 130
                font.pixelSize: Platform.fontBase - 2
                model: root.posOptions
                currentIndex: Math.max(0, root.posOptions.indexOf(root.blockPos))
                onActivated: (i) => root.posEdited(root.blockId, root.posOptions[i])

                contentItem: Text {
                    leftPadding: 8
                    rightPadding: posCombo.indicator.width + 4
                    text: posCombo.currentText.length === 0 ? qsTr("part of speech…") : posCombo.currentText
                    color: posCombo.currentText.length === 0 ? Platform.textMuted : Platform.accentDark
                    font: posCombo.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    radius: height / 2
                    color: Platform.surfaceAlt
                    border.color: posCombo.activeFocus ? Platform.accent : Platform.border
                    border.width: 1
                }

                indicator: Text {
                    x: posCombo.width - width - 8
                    y: (posCombo.height - height) / 2
                    text: TenjinIcons.expandMore
                    font.family: TenjinIcons.family
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase - 3
                }

                popup: Popup {
                    y: posCombo.height + 2
                    width: posCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 240)
                    padding: 1
                    background: Rectangle {
                        color: Platform.surface
                        radius: Platform.radius
                        border.color: Platform.border
                        border.width: 1
                    }
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: posCombo.popup.visible ? posCombo.delegateModel : null
                        currentIndex: posCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                }

                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: posCombo.width
                    height: Platform.isMobile ? Platform.touchTarget : 30
                    contentItem: Text {
                        text: modelData.length === 0 ? "—" : modelData
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase - 2
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: posCombo.highlightedIndex === index
                    background: Rectangle {
                        color: highlighted ? Platform.surfaceAlt : "transparent"
                    }
                }
            }

            // Part-of-speech chip (definitions only, view mode, when set).
            Rectangle {
                visible: root.isDefinition && !root.editMode && root.blockPos.length > 0
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: posChip.implicitWidth + 14
                implicitHeight: Platform.isMobile ? 28 : 22
                radius: height / 2
                color: Platform.bg
                border.color: Platform.accent
                border.width: 1
                Text {
                    id: posChip
                    anchors.centerIn: parent
                    text: root.blockPos
                    color: Platform.accent
                    font.pixelSize: Platform.fontBase - 2
                    font.italic: true
                }
            }

            Item { Layout.fillWidth: true }

            // Span -/+ chips. Shrink/grow the block's colSpan in the grid
            // by 1, clamped to [1, 12]. 12 is a soft cap matching
            // GridContentView's column budget per band (see totalSpan
            // calc there). The drag-the-right-edge gesture still works
            // for fine control; this is the discoverable, mobile-
            // friendly counterpart.
            RowLayout {
                visible: root.editMode && !Platform.isMobile
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth:  Platform.isMobile ? Platform.touchTarget : 26
                    implicitHeight: Platform.isMobile ? Platform.touchTarget : 26
                    radius: Platform.radius
                    color: spanMinusArea.containsMouse ? Platform.accent : "transparent"
                    border.color: Platform.border
                    border.width: 1
                    opacity: root.blockColSpan > 1 ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text {
                        anchors.centerIn: parent
                        text: TenjinIcons.close
                        font.family: TenjinIcons.family
                        color: spanMinusArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.weight: Font.Normal
                    }
                    MouseArea {
                        id: spanMinusArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.blockColSpan > 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const ns = Math.max(1, root.blockColSpan - 1)
                            root.spanChanged(root.blockId, root.blockRowSpan, ns)
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.blockColSpan
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase - 2
                    font.bold: true
                    Layout.minimumWidth: 14
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth:  Platform.isMobile ? Platform.touchTarget : 26
                    implicitHeight: Platform.isMobile ? Platform.touchTarget : 26
                    radius: Platform.radius
                    color: spanPlusArea.containsMouse ? Platform.accent : "transparent"
                    border.color: Platform.border
                    border.width: 1
                    opacity: root.blockColSpan < 12 ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: spanPlusArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    MouseArea {
                        id: spanPlusArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.blockColSpan < 12
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const ns = Math.min(12, root.blockColSpan + 1)
                            root.spanChanged(root.blockId, root.blockRowSpan, ns)
                        }
                    }
                }
            }

            Rectangle {
                visible: root.editMode
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: removeLabel.implicitWidth + 18
                implicitHeight: Platform.isMobile ? Platform.touchTarget : 26
                radius: Platform.radius
                color: removeArea.containsMouse ? Platform.danger : "transparent"
                border.color: Platform.danger
                border.width: 1

                Text {
                    id: removeLabel
                    anchors.centerIn: parent
                    text: qsTr("Remove")
                    color: removeArea.containsMouse ? Platform.textOnDark : Platform.danger
                    font.pixelSize: Platform.fontBase - 2
                    font.bold: true
                }
                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteRequested(root.blockId)
                }
            }
        }

        // Body: text editor / viewer, or media / divider / header / tense
        // / formula component.
        Loader {
            id: contentLoader
            Layout.fillWidth: true
            sourceComponent: {
                if (root.isMedia)    return mediaArea
                if (root.isDivider)  return dividerArea
                if (root.isHeader)   return headerArea
                if (root.isTense)    return tenseArea
                if (root.isFormula)  return formulaArea
                if (root.isCloze)    return root.editMode ? clozeEdit : clozeArea
                return root.editMode ? editArea : viewArea
            }
        }
    }

    // Divider — a thin accent line that breaks the visual flow between
    // sections. No editable payload.
    Component {
        id: dividerArea
        Rectangle {
            implicitHeight: 2
            implicitWidth: contentLoader.width
            color: Platform.accent
            opacity: 0.55
        }
    }

    // Header — large bold text that introduces a section. Edit mode
    // uses a single-line TextField with the same styling so the visual
    // is consistent between read and write modes.
    Component {
        id: headerArea
        Loader {
            sourceComponent: root.editMode ? headerEdit : headerView
        }
    }
    Component {
        id: headerView
        Text {
            width: contentLoader.width
            text: root.blockContent.length > 0 ? root.blockContent
                                               : "Section heading"
            color: root.blockContent.length > 0 ? Platform.textPrimary : Platform.textMuted
            font.pixelSize: Platform.fontTitle + 4
            font.bold: true
            font.italic: root.blockContent.length === 0
            wrapMode: Text.WordWrap
        }
    }
    Component {
        id: headerEdit
        TextField {
            id: headerInput
            width: contentLoader.width
            text: root.blockContent
            placeholderText: qsTr("Section heading")
            placeholderTextColor: Platform.textMuted
            color: Platform.textPrimary
            font.pixelSize: Platform.fontTitle + 4
            font.bold: true
            background: Rectangle { color: "transparent" }
            onEditingFinished: root.contentEdited(root.blockId, text)
        }
    }

    // Tense — verb conjugation table. The block's body is a JSON object
    // mapping tense name → form. We render Present / Past / Future /
    // Conditional by default; if the JSON has additional keys (gerund,
    // imperative, …) they appear after the canonical four.
    Component {
        id: tenseArea
        ColumnLayout {
            id: tenseRoot
            width: contentLoader.width
            spacing: 6

            readonly property var canonicalTenses: ["present", "past", "future", "conditional"]

            function _parse(s) {
                if (!s || s.length === 0) return {}
                try { return JSON.parse(s) || {} } catch (e) { return {} }
            }
            function _orderedKeys(obj) {
                const out = []
                for (let i = 0; i < canonicalTenses.length; i++) out.push(canonicalTenses[i])
                for (const k in obj) if (out.indexOf(k) < 0) out.push(k)
                return out
            }
            function _serialize() {
                const obj = {}
                for (let i = 0; i < tenseRepeater.count; i++) {
                    const item = tenseRepeater.itemAt(i)
                    if (item) obj[item.tenseName] = item.formValue
                }
                return JSON.stringify(obj)
            }

            property var _data: _parse(root.blockContent)
            property var _keys: _orderedKeys(_data)

            Repeater {
                id: tenseRepeater
                model: tenseRoot._keys
                delegate: RowLayout {
                    id: tenseRow
                    required property var modelData
                    readonly property string tenseName: modelData
                    property string formValue: tenseRoot._data[tenseName] || ""
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 32
                        radius: Platform.radius
                        color: Platform.surfaceAlt
                        border.color: Platform.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: tenseRow.tenseName.charAt(0).toUpperCase() + tenseRow.tenseName.slice(1)
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                            font.bold: true
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        sourceComponent: root.editMode ? tenseEdit : tenseView
                    }

                    Component {
                        id: tenseView
                        Text {
                            text: tenseRow.formValue.length > 0 ? tenseRow.formValue : "—"
                            color: tenseRow.formValue.length > 0 ? Platform.textPrimary : Platform.textMuted
                            font.pixelSize: Platform.fontBase
                            font.italic: tenseRow.formValue.length === 0
                        }
                    }
                    Component {
                        id: tenseEdit
                        TextField {
                            text: tenseRow.formValue
                            placeholderText: qsTr("form")
                            placeholderTextColor: Platform.textMuted
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            background: Rectangle {
                                color: Platform.bg
                                radius: Platform.radius
                                border.color: parent.activeFocus ? Platform.accent : Platform.border
                                border.width: parent.activeFocus ? 2 : 1
                            }
                            onTextChanged: tenseRow.formValue = text
                            onEditingFinished: root.contentEdited(root.blockId, tenseRoot._serialize())
                        }
                    }
                }
            }
        }
    }

    // Formula — read-only LaTeX rendered via FormulaRenderer (existing
    // code path; the AppViewModel.renderFormula Q_INVOKABLE returns the
    // rich-text HTML).
    Component {
        id: formulaArea
        Loader {
            sourceComponent: root.editMode ? formulaEdit : formulaView
        }
    }

    // Cloze read view — deletions revealed (answers emphasized). The masked
    // form is only shown during review (ReviewPage), not in the normal entry.
    Component {
        id: clozeArea
        Text {
            width: contentLoader.width
            text: root.blockContent.length > 0
                  ? appVM.renderCloze(root.blockContent, false)
                  : qsTr("(empty cloze — type text with {{c1::answer}})")
            color: root.blockContent.length > 0 ? Platform.textPrimary : Platform.textMuted
            textFormat: Text.RichText
            font.pixelSize: Platform.fontLarge
            wrapMode: Text.WordWrap
        }
    }

    // Cloze editor — PLAIN text (not the rich editArea, which would wrap the
    // {{cN::answer}} markers in HTML and corrupt them). Author types markers
    // directly; a hint shows the syntax.
    Component {
        id: clozeEdit
        ColumnLayout {
            width: contentLoader.width
            spacing: 4
            TextArea {
                Layout.fillWidth: true
                text: root.blockContent
                placeholderText: qsTr("She {{c1::went}} to the {{c2::market::place}}.")
                wrapMode: TextEdit.Wrap
                color: Platform.textPrimary
                font.pixelSize: Platform.fontLarge
                background: Rectangle { radius: Platform.radius; color: Platform.bg; border.color: Platform.border }
                onEditingFinished: root.contentEdited(root.blockId, text)
            }
            AppText {
                text: qsTr("Use {{c1::answer}} or {{c1::answer::hint}} to hide words.")
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
                maxLines: 2
                Layout.fillWidth: true
            }
        }
    }
    Component {
        id: formulaView
        Text {
            width: contentLoader.width
            text: root.blockContent.length > 0
                  ? appVM.renderFormula(root.blockContent)
                  : "(empty formula)"
            color: root.blockContent.length > 0 ? Platform.textPrimary : Platform.textMuted
            textFormat: Text.RichText
            font.pixelSize: Platform.fontLarge
            wrapMode: Text.WordWrap
        }
    }
    Component {
        id: formulaEdit
        ColumnLayout {
            width: contentLoader.width
            spacing: 4
            TextField {
                Layout.fillWidth: true
                text: root.blockContent
                placeholderText: qsTr("\\frac{a}{b}, \\sqrt{x}, \\sum_{i=0}^n …")
                placeholderTextColor: Platform.textMuted
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.family: Platform.fontMono
                background: Rectangle {
                    color: Platform.bg
                    radius: Platform.radius
                    border.color: parent.activeFocus ? Platform.accent : Platform.border
                    border.width: parent.activeFocus ? 2 : 1
                }
                onEditingFinished: root.contentEdited(root.blockId, text)
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Preview:")
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
            }
            Text {
                Layout.fillWidth: true
                text: root.blockContent.length > 0 ? appVM.renderFormula(root.blockContent) : ""
                textFormat: Text.RichText
                color: Platform.textPrimary
                font.pixelSize: Platform.fontLarge
                wrapMode: Text.WordWrap
            }
        }
    }

    // Text: read-only (rich text / HTML)
    Component {
        id: viewArea
        Text {
            width: contentLoader.width
            text: root.blockContent.length > 0 ? root.blockContent
                                               : "(empty \u2014 switch to Edit to add content)"
            color: root.blockContent.length > 0 ? Platform.textPrimary : Platform.textMuted
            textFormat: root.blockContent.length > 0 ? Text.RichText : Text.PlainText
            font.pixelSize: Platform.fontBase
            font.italic: root.blockContent.length === 0
            wrapMode: Text.WordWrap
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }
    }

    // Text: editable (rich text and formatting toolbar)
    Component {
        id: editArea
        ColumnLayout {
            width: contentLoader.width
            spacing: 4

            // Formatting toolbar: operates on the focused selection.
            Flow {
                Layout.fillWidth: true
                spacing: 3

                component FmtBtn: Rectangle {
                    id: fb
                    property string glyph: ""
                    property bool active: false
                    signal triggered()
                    width: Platform.isMobile ? 34 : 26
                    height: Platform.isMobile ? 34 : 26
                    radius: Platform.radius - 2
                    color: fbArea.containsMouse ? Platform.accent
                          : active ? Platform.surfaceAlt : Platform.surface
                    border.color: Platform.border
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: fb.glyph
                        font.family: TenjinIcons.family
                        color: fbArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.weight: Font.Normal
                    }
                    MouseArea {
                        id: fbArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Keep the editor's selection while clicking the button.
                        onPressed: (m) => m.accepted = true
                        onClicked: fb.triggered()
                    }
                }

                FmtBtn { glyph: TenjinIcons.bold; onTriggered: editField.toggleBold() }
                FmtBtn { glyph: TenjinIcons.italic; onTriggered: editField.toggleItalic() }
                FmtBtn { glyph: TenjinIcons.underline; onTriggered: editField.toggleUnderline() }
                FmtBtn { glyph: TenjinIcons.strike; onTriggered: editField.toggleStrike() }
                FmtBtn { glyph: TenjinIcons.bullet; onTriggered: editField.insertBullet() }

                // Foreground colour
                Rectangle {
                    width: Platform.isMobile ? 34 : 26; height: Platform.isMobile ? 34 : 26
                    radius: Platform.radius - 2; color: Platform.surface
                    border.color: Platform.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "A"; color: fgColorDialog.selectedColor; font.bold: true; font.pixelSize: Platform.fontBase }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: (m) => m.accepted = true
                        onClicked: fgColorDialog.open() }
                }
                // Highlight (background) colour
                Rectangle {
                    width: Platform.isMobile ? 34 : 26; height: Platform.isMobile ? 34 : 26
                    radius: Platform.radius - 2; color: bgColorDialog.selectedColor
                    border.color: Platform.border; border.width: 1
                    Text { anchors.centerIn: parent; text: TenjinIcons.edit
                    font.family: TenjinIcons.family; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: (m) => m.accepted = true
                        onClicked: bgColorDialog.open() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(
                    Math.max(editField.implicitHeight + 12, Platform.touchTarget * 2),
                    Platform.isMobile ? 180 : 320)
                color: Platform.bg
                radius: Platform.radius - 2
                border.color: editField.activeFocus ? Platform.accent : Platform.border
                border.width: editField.activeFocus ? 2 : 1

                // Scroll internally when content exceeds the capped height, so a
                // long definition never pushes the block off-screen.
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    TextArea {
                        id: editField
                        textFormat: TextEdit.RichText
                        text: root.blockContent
                        color: Platform.textPrimary
                        placeholderText: qsTr("Type here\u2026")
                        placeholderTextColor: Platform.textMuted
                        font.pixelSize: Platform.fontBase
                        wrapMode: TextEdit.WordWrap
                        background: null
                        selectByMouse: true
                        persistentSelection: true
                        onEditingFinished: root.contentEdited(root.blockId, getFormattedText(0, length))

                        // Strip foreign formatting on paste. TextArea normally
                        // pastes the clipboard's text/html representation,
                        // which carries fonts / colors / sizes from whatever
                        // app the user copied from. Intercept the standard
                        // Paste shortcut and insert the clipboard's plain-text
                        // form instead. Our intentional in-app bold / italic
                        // / underline still works because those are applied
                        // by cursorSelection.font, not by foreign HTML.
                        // Item #6 in the improvement plan.
                        Keys.onPressed: (event) => {
                            if (event.matches(StandardKey.Paste)) {
                                event.accepted = true
                                const plain = appVM.clipboardPlainText()
                                if (plain.length > 0) {
                                    // Delete the current selection (if any)
                                    // so paste replaces, matching the default
                                    // Cmd/Ctrl+V behaviour.
                                    if (selectionStart !== selectionEnd)
                                        remove(selectionStart, selectionEnd)
                                    insert(cursorPosition, plain)
                                }
                            }
                        }

                        // Apply formatting to the current selection.
                        // We use getFormattedText() and pull out the
                    // body fragment Qt marks with Start/EndFragment comments,
                    // wrap it, then re-insert at cursorPosition (the KDAB pattern).
                    function selectionFragment(s, e) {
                        const full = getFormattedText(s, e)
                        const a = full.indexOf("<!--StartFragment-->")
                        const b = full.indexOf("<!--EndFragment-->")
                        if (a >= 0 && b >= 0)
                            return full.substring(a + "<!--StartFragment-->".length, b)
                        // Fallback: plain selected text.
                        return getText(s, e)
                    }

                    function toggleBold() {
                        if (selectionStart === selectionEnd) return
                        cursorSelection.font = Qt.font({ bold: cursorSelection.font.bold !== true })
                    }
                    function toggleItalic() {
                        if (selectionStart === selectionEnd) return
                        cursorSelection.font = Qt.font({ italic: cursorSelection.font.italic !== true })
                    }
                    function toggleUnderline() {
                        if (selectionStart === selectionEnd) return
                        cursorSelection.font = Qt.font({ underline: cursorSelection.font.underline !== true })
                    }
                    function toggleStrike() {
                        if (selectionStart === selectionEnd) return
                        cursorSelection.font = Qt.font({ strikeout: cursorSelection.font.strikeout !== true })
                    }
                    function insertBullet()    { insert(cursorPosition, "<ul><li>&nbsp;</li></ul>") }
                    function applyColor(c) {
                        if (selectionStart === selectionEnd) return
                        cursorSelection.color = c
                    }
                    function applyHighlight(c) {
                        // Background/highlight isn't exposed on cursorSelection in
                        // 6.8; fall back to wrapping just the selection in a span.
                        if (selectionStart === selectionEnd) return
                        const s = selectionStart, e = selectionEnd
                        const frag = selectionFragment(s, e)
                        remove(s, e)
                        insert(cursorPosition, "<span style=\"background-color:" + c + ";\">" + frag + "</span>")
                        select(s, cursorPosition)
                    }

                    Connections {
                        target: root
                        function onBlockContentChanged() {
                            if (!editField.activeFocus && editField.text !== root.blockContent)
                                editField.text = root.blockContent
                        }
                    }
                }
            }
            }

            ColorDialog {
                id: fgColorDialog
                onAccepted: editField.applyColor(selectedColor)
            }
            ColorDialog {
                id: bgColorDialog
                onAccepted: editField.applyHighlight(selectedColor)
            }
        }
    }

    // Media: pick-only, renders per kind; no visible label/path
    Component {
        id: mediaArea
        // Outer Item lets us overlay a DropArea (anchors.fill) on top of
        // the ColumnLayout without QML complaining that the layout's
        // child is anchor-managed. The ColumnLayout fills the Item; the
        // DropArea is a sibling that fills the same space.
        Item {
            id: mediaRoot
            implicitWidth: contentLoader.width
            implicitHeight: mediaCol.implicitHeight + (dropHint.visible ? dropHint.height + 8 : 0)

            // Desktop drag-drop. Drops the first file URL and imports
            // it via the same path as the picker. No `keys:` filter --
            // OS drags carry different MIME types per platform
            // (text/uri-list on Linux/macOS, application/x-qt-windows-
            // mime;... on Windows). We accept any drag that brings URLs
            // and check inside onDropped. Mobile has no OS DnD; the
            // DropArea is inert there -- no harm.
            DropArea {
                id: mediaDropArea
                anchors.fill: parent
                enabled: root.editMode && !Platform.isMobile
                onEntered: (drag) => {
                    // Only accept if the drag has URLs to offer.
                    if (!drag.hasUrls) drag.accepted = false
                }
                onDropped: (drop) => {
                    if (!drop.hasUrls || drop.urls.length === 0) return
                    // drop.urls[0] is already a QUrl -- hand it straight
                    // to importMedia, which knows how to extract the
                    // local file path. Stringifying here would re-encode
                    // and trip the file://C: vs file:///C: Windows quirk.
                    var stored = appVM.entryVM.importMedia(drop.urls[0])
                    if (stored && stored.length > 0) {
                        root.contentEdited(root.blockId, stored)
                        drop.acceptProposedAction()
                    }
                }
            }

            ColumnLayout {
                id: mediaCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 8

                // Visual hint shown only while a drop is hovering.
                Rectangle {
                    id: dropHint
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 36 : 0
                    visible: mediaDropArea.containsDrag
                    radius: Platform.radius - 2
                    color: Platform.accent
                    opacity: 0.18
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Drop to import")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }
                }

            // Control row (edit mode only): Browse + URL field.
            // On mobile these stack vertically so the URL field isn't squeezed.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.editMode
                spacing: 8

                Rectangle {
                    implicitHeight: Platform.touchTarget
                    implicitWidth: browseLabel.implicitWidth + 24
                    radius: Platform.radius
                    color: browseArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1
                    Text {
                        id: browseLabel
                        anchors.centerIn: parent
                        text: root.blockContent.length > 0 ? qsTr("Replace\u2026") : qsTr("Choose file\u2026")
                        color: browseArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    MouseArea {
                        id: browseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Platform.isMobile)
                                mediaChooser.open()
                            else
                                mediaFileDialog.open()
                        }
                    }
                }

                // Paste a URL for web embeds.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Platform.touchTarget
                    color: Platform.bg
                    radius: Platform.radius - 2
                    border.color: urlField.activeFocus ? Platform.accent : Platform.border
                    border.width: urlField.activeFocus ? 2 : 1
                    TextField {
                        id: urlField
                        anchors.fill: parent
                        anchors.margins: 6
                        placeholderText: qsTr("\u2026or paste a video/web URL")
                        placeholderTextColor: Platform.textMuted
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        background: null
                        onAccepted: if (text.trim().length > 0) root.contentEdited(root.blockId, text.trim())
                    }
                }
            }

            // IMAGE / GIF
            Rectangle {
                id: previewBox
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? previewBox._h : 0
                visible: root.mediaKind === "image" || root.mediaKind === "gif"

                readonly property real _maxH: 360
                readonly property real _h: {
                    if (preview.sourceSize.width > 0 && preview.sourceSize.height > 0) {
                        const w = width > 0 ? width - 12 : 0
                        const scaled = w * preview.sourceSize.height / preview.sourceSize.width
                        return Math.min(Math.max(scaled, 80), _maxH) + 12
                    }
                    return 120
                }
                color: Platform.bg
                radius: Platform.radius - 2
                border.color: Platform.border
                border.width: 1

                AnimatedImage {
                    id: preview
                    anchors.fill: parent
                    anchors.margins: 6
                    source: previewBox.visible ? appVM.entryVM.resolveMediaUrl(root.blockContent) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    // Static images don't animate; GIFs do. AnimatedImage handles both.
                    playing: root.mediaKind === "gif"

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: preview.status === Image.Loading
                        visible: running
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: preview.status === Image.Error
                        text: qsTr("Could not load image")
                        color: Platform.danger
                        font.pixelSize: Platform.fontBase
                    }
                    HoverHandler { id: imgHover }
                    ToolTip.visible: imgHover.hovered && root.blockContent.length > 0
                    ToolTip.text: root.blockContent

                    // Tap to view fullscreen.
                    TapHandler {
                        enabled: preview.status === Image.Ready
                        onTapped: mediaViewer.openSource(preview.source, root.mediaKind === "gif")
                    }
                }
            }

            // VIDEO / AUDIO (QtMultimedia, no autoplay)
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "video" || root.mediaKind === "audio"
                visible: active
                sourceComponent: mediaPlayerComponent
            }

            // WEB EMBED (QtWebEngine if available, else link)
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "embed"
                visible: active
                sourceComponent: root.webEngineAvailable ? webEmbedComponent : embedLinkComponent
            }

            // GENERIC FILE (open externally)
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "file"
                visible: active
                sourceComponent: fileLinkComponent
            }

            // EMPTY
            Text {
                Layout.fillWidth: true
                visible: root.mediaKind === "none"
                text: root.editMode ? qsTr("No media yet \u2014 choose a file or paste a URL above.")
                                    : "No media."
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                font.italic: true
                wrapMode: Text.WordWrap
            }

            }
            // end of ColumnLayout (mediaCol)

            MediaPickerDialog {
                id: mediaFileDialog
                // ImportPickerDialog-style picker lists media in
                // appVM.documentsFolder. Replaces the old FileDialog,
                // which emitted "no native option" on iOS. Item #17.
                // `path` is a plain absolute path -- importMedia handles
                // both raw paths and file:// URLs. We deliberately do
                // NOT prepend "file://" here because that produces
                // "file://C:/..." on Windows (missing third slash) and
                // QUrl::toLocalFile() returns empty for malformed URLs.
                onPicked: (path) => {
                    const stored = appVM.entryVM.importMedia(path)
                    if (stored.length > 0)
                        root.contentEdited(root.blockId, stored)
                }
            }

            // Mobile: native Files/Photos/Camera chooser. Falls back to the
            // in-app dialog if no native picker is available on the platform.
            MediaSourceChooser {
                id: mediaChooser
                onNativeUnavailable: mediaFileDialog.open()
            }

            // Native media result (from appVM.pickEntryMedia) → import + store.
            Connections {
                target: appVM
                function onEntryMediaPicked(path) {
                    // Only the media block currently in edit mode consumes the
                    // pick. (Simultaneous edit of two media blocks is not a
                    // supported flow.)
                    if (!root.editMode || !root.isMedia)
                        return
                    const stored = appVM.entryVM.importMedia(path)
                    if (stored.length > 0)
                        root.contentEdited(root.blockId, stored)
                }
            }
        }
        // end of outer Item (mediaRoot)
    }

    Component {
        id: mediaPlayerComponent
        Loader {
            source: Qt.resolvedUrl("MediaPlayerView.qml")
            onLoaded: {
                if (item) {
                    item.source = appVM.entryVM.resolveMediaUrl(root.blockContent)
                    item.isVideo = root.mediaKind === "video"
                    item.tooltipText = root.blockContent
                }
            }
        }
    }

    // Web/video embed via QtWebView (only instantiated when webEngineAvailable).
    Component {
        id: webEmbedComponent
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 320
            color: Platform.bg
            radius: Platform.radius - 2
            border.color: Platform.border
            border.width: 1
            // The WebView is created via a nested Loader so this file still
            // compiles without the QtWebView module present.
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                source: Qt.resolvedUrl("WebEmbed.qml")
                onLoaded: if (item) item.src = appVM.entryVM.resolveMediaUrl(root.blockContent)
            }
        }
    }

    // Fallback when WebEngine isn't built: show the URL as an openable link.
    Component {
        id: embedLinkComponent
        ColumnLayout {
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: root.blockContent
                color: Platform.accentDark
                font.pixelSize: Platform.fontBase
                font.underline: true
                elide: Text.ElideMiddle
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(root.blockContent)
                }
            }
            Text {
                visible: !root.webEngineAvailable
                text: qsTr("(Inline web embeds need the WebView build option.)")
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase - 3
                font.italic: true
            }
        }
    }

    // Generic file: open in the OS default app.
    Component {
        id: fileLinkComponent
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Platform.touchTarget * 1.2
            color: openFileArea.containsMouse ? Platform.surfaceAlt : Platform.bg
            radius: Platform.radius - 2
            border.color: Platform.border
            border.width: 1
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10
                Text { text: TenjinIcons.attach; font.family: TenjinIcons.family; font.pixelSize: Platform.fontLarge }
                Text {
                    Layout.fillWidth: true
                    text: root.mediaFileName
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    elide: Text.ElideMiddle
                }
                Text { text: qsTr("Open"); color: Platform.accentDark; font.pixelSize: Platform.fontBase; font.bold: true }
            }
            HoverHandler { id: fileHover }
            ToolTip.visible: fileHover.hovered
            ToolTip.text: root.blockContent
            MouseArea {
                id: openFileArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(appVM.entryVM.resolveMediaUrl(root.blockContent))
            }
        }
    }

    // Fullscreen media viewer
    Popup {
        id: mediaViewer
        parent: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        padding: 0

        property url currentSource: ""
        property bool isGif: false
        function openSource(src, gif) {
            currentSource = src
            isGif = gif === true
            open()
        }

        background: Rectangle { color: "#000000"; opacity: 0.92 }

        contentItem: Item {
            AnimatedImage {
                id: fullImg
                anchors.fill: parent
                anchors.margins: 12
                source: mediaViewer.currentSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                playing: mediaViewer.isGif
            }
            MouseArea {
                anchors.fill: parent
                onClicked: mediaViewer.close()
            }
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 16 }
                width: 40; height: 40; radius: 20
                color: Platform.surface
                border.color: Platform.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: TenjinIcons.close
                    font.family: TenjinIcons.family
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.weight: Font.Normal
                }
                MouseArea { anchors.fill: parent; onClicked: mediaViewer.close() }
            }
        }
    }
}






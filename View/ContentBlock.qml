pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import TenjinView

// A single content block (definition / media path / note), presentational only.
//
// - Definition / Note  → editable multi-line text.
// - Media Path         → a file path with a "Browse…" picker; if the path points
//                        to an image it is rendered inline.
//
// Reordering is handled by the draggable wrapper in WordPage.qml; this component
// renders its content and emits edit/delete intents.
//
// Layout note: the root height is driven by content via implicitHeight and the
// inner column is anchored to top/left/right (NOT anchors.fill on a Layout,
// which previously created a binding loop and caused clipping/overlap).
Rectangle {
    id: root

    property int     blockId
    property int     blockType     // 0=def, 1=media, 2=note
    property string  blockContent
    property string  blockPos       // part of speech (definitions only)
    property bool    editMode: false
    property bool    held: false   // set by the drag wrapper
    property int     visualIndex: -1

    signal deleteRequested(int bid)
    signal contentEdited(int bid, string newContent)
    signal posEdited(int bid, string newPos)

    readonly property bool isDefinition: blockType === 0
    readonly property var posOptions: ["", "noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "other"]

    readonly property var typeNames: ["definition", "media", "note"]
    readonly property bool isMedia: blockType === 1

    // Set by the app: whether QtWebEngine was compiled in (WEBVIEW_SUPPORT).
    property bool webEngineAvailable: (typeof appVM !== "undefined"
                                       && appVM.webEngineAvailable !== undefined)
                                      ? appVM.webEngineAvailable : false

    // Classify the media path/URL.
    readonly property string mediaKind: {
        if (!isMedia || blockContent.length === 0) return "none"
        const p = blockContent.toLowerCase()
        // Web embed (YouTube, Vimeo, or any http/https URL).
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

    // Just the file name for tooltips/labels (strip any directory).
    readonly property string mediaFileName: {
        if (blockContent.length === 0) return ""
        const s = blockContent.replace(/[\\/]+$/, "")
        const i = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"))
        return i < 0 ? s : s.slice(i + 1)
    }

    color: held ? Platform.surfaceAlt : Platform.surface
    radius: Platform.radius
    border.color: (editMode || held) ? Platform.accent : Platform.border
    border.width: 1
    clip: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: layout.implicitHeight + 20

    Behavior on color { ColorAnimation { duration: 120 } }

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
                text: "\u283F"  // braille dots, used as a drag affordance
                color: Platform.textMuted
                font.pixelSize: Platform.fontLarge
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                visible: !root.isMedia
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: typeLabel.implicitWidth + 16
                implicitHeight: Platform.isMobile ? 28 : 22
                radius: height / 2
                color: Platform.surfaceAlt
                border.color: Platform.border
                border.width: 1

                Text {
                    id: typeLabel
                    anchors.centerIn: parent
                    text: root.typeNames[root.blockType] ?? "note"
                    color: Platform.accentDark
                    font.pixelSize: Platform.fontBase - 2
                    font.bold: true
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
                    text: posCombo.currentText.length === 0 ? "part of speech…" : posCombo.currentText
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
                    text: "\u25BE"
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
                    height: 30
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
                    text: "Remove"
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

        // Body: text editor / viewer, or media picker + preview.
        Loader {
            id: contentLoader
            Layout.fillWidth: true
            sourceComponent: root.isMedia
                             ? mediaArea
                             : (root.editMode ? editArea : viewArea)
        }
    }

    // ── Text: read-only (rich text / HTML) ───────────────────────
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

    // ── Text: editable (rich text + formatting toolbar) ───────────
    Component {
        id: editArea
        ColumnLayout {
            width: contentLoader.width
            spacing: 4

            // Formatting toolbar — operates on the focused selection.
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
                        color: fbArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
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

                FmtBtn { glyph: "B"; onTriggered: editField.toggleBold() }
                FmtBtn { glyph: "I"; onTriggered: editField.toggleItalic() }
                FmtBtn { glyph: "U"; onTriggered: editField.toggleUnderline() }
                FmtBtn { glyph: "S\u0336"; onTriggered: editField.toggleStrike() }
                FmtBtn { glyph: "\u2022"; onTriggered: editField.insertBullet() }

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
                    Text { anchors.centerIn: parent; text: "\u270E"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: (m) => m.accepted = true
                        onClicked: bgColorDialog.open() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(editField.implicitHeight + 12, Platform.touchTarget * 2)
                color: Platform.bg
                radius: Platform.radius - 2
                border.color: editField.activeFocus ? Platform.accent : Platform.border
                border.width: editField.activeFocus ? 2 : 1

                TextArea {
                    id: editField
                    anchors.fill: parent
                    anchors.margins: 6
                    textFormat: TextEdit.RichText
                    text: root.blockContent
                    color: Platform.textPrimary
                    placeholderText: "Type here\u2026"
                    placeholderTextColor: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                    wrapMode: TextEdit.WordWrap
                    background: null
                    selectByMouse: true
                    persistentSelection: true
                    onEditingFinished: root.contentEdited(root.blockId, getFormattedText(0, length))

                    // Apply formatting to the current selection. getText() strips
                    // formatting, so we use getFormattedText() and pull out the
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
                    // Formatting via the Qt 6.7+ cursorSelection API — operates on
                    // the selected range's character format directly, instead of the
                    // old (unreliable) approach of removing the selection and
                    // re-inserting hand-built HTML tags, which corrupted the document
                    // on repeated/overlapping toggles.
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

    // ── Media: pick-only, renders per kind; no visible label/path ──────────
    Component {
        id: mediaArea
        ColumnLayout {
            width: contentLoader.width
            spacing: 8

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
                        text: root.blockContent.length > 0 ? "Replace\u2026" : "Choose file\u2026"
                        color: browseArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    MouseArea {
                        id: browseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaFileDialog.open()
                    }
                }

                // Paste a URL for web embeds (YouTube etc.).
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
                        placeholderText: "\u2026or paste a video/web URL"
                        placeholderTextColor: Platform.textMuted
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        background: null
                        onAccepted: if (text.trim().length > 0) root.contentEdited(root.blockId, text.trim())
                    }
                }
            }

            // ── IMAGE / GIF ────────────────────────────────────────────
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
                    source: previewBox.visible ? appVM.wordVM.resolveMediaUrl(root.blockContent) : ""
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
                        text: "Could not load image"
                        color: Platform.danger
                        font.pixelSize: Platform.fontBase
                    }
                    HoverHandler { id: imgHover }
                    ToolTip.visible: imgHover.hovered && root.blockContent.length > 0
                    ToolTip.text: root.blockContent
                }
            }

            // ── VIDEO / AUDIO (QtMultimedia, no autoplay) ──────────────
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "video" || root.mediaKind === "audio"
                visible: active
                sourceComponent: mediaPlayerComponent
            }

            // ── WEB EMBED (QtWebEngine if available, else link) ────────
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "embed"
                visible: active
                sourceComponent: root.webEngineAvailable ? webEmbedComponent : embedLinkComponent
            }

            // ── GENERIC FILE (open externally) ─────────────────────────
            Loader {
                Layout.fillWidth: true
                active: root.mediaKind === "file"
                visible: active
                sourceComponent: fileLinkComponent
            }

            // ── EMPTY ──────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                visible: root.mediaKind === "none"
                text: root.editMode ? "No media yet \u2014 choose a file or paste a URL above."
                                    : "No media."
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                font.italic: true
                wrapMode: Text.WordWrap
            }

            FileDialog {
                id: mediaFileDialog
                title: "Select media file"
                nameFilters: [
                    "Media (*.png *.jpg *.jpeg *.gif *.bmp *.webp *.svg *.mp4 *.webm *.mkv *.mov *.mp3 *.wav *.ogg *.flac *.m4a)",
                    "All files (*)"
                ]
                onAccepted: {
                    const stored = appVM.wordVM.importMedia(mediaFileDialog.selectedFile)
                    if (stored.length > 0)
                        root.contentEdited(root.blockId, stored)
                }
            }
        }
    }

    // Video/audio player, isolated in MediaPlayerView.qml so this file needs no
    // QtMultimedia import. A build without MEDIA_SUPPORT omits that file and the
    // Loader stays empty.
    Component {
        id: mediaPlayerComponent
        Loader {
            source: Qt.resolvedUrl("MediaPlayerView.qml")
            onLoaded: {
                if (item) {
                    item.source = appVM.wordVM.resolveMediaUrl(root.blockContent)
                    item.isVideo = root.mediaKind === "video"
                    item.tooltipText = root.blockContent
                }
            }
        }
    }

    // Web embed via QtWebEngine (only instantiated when webEngineAvailable).
    Component {
        id: webEmbedComponent
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 320
            color: Platform.bg
            radius: Platform.radius - 2
            border.color: Platform.border
            border.width: 1
            // WebEngineView is created via a nested Loader keyed off a context
            // property so this file still compiles without QtWebEngine.
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                source: Qt.resolvedUrl("WebEmbed.qml")
                onLoaded: if (item) item.url = appVM.wordVM.resolveMediaUrl(root.blockContent)
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
                text: "\uD83D\uDD17  " + root.blockContent
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
                text: "(Inline web embeds need the WebView build option.)"
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
                Text { text: "\uD83D\uDCCE"; font.pixelSize: Platform.fontLarge }
                Text {
                    Layout.fillWidth: true
                    text: root.mediaFileName
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    elide: Text.ElideMiddle
                }
                Text { text: "Open"; color: Platform.accentDark; font.pixelSize: Platform.fontBase; font.bold: true }
            }
            HoverHandler { id: fileHover }
            ToolTip.visible: fileHover.hovered
            ToolTip.text: root.blockContent
            MouseArea {
                id: openFileArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(appVM.wordVM.resolveMediaUrl(root.blockContent))
            }
        }
    }
}


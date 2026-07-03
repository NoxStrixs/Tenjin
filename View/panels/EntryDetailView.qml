pragma ComponentBehavior: Bound

import TenjinView
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQml
import QtQml.Models

// The full editor for a single word: title, action buttons, tags, the row/column
// content grid, and the add-content buttons. Extracted from EntryPage so both the
// desktop detail pane and the mobile list-detail stack render one definition.
//
//   showBack — when true (mobile), shows a "‹" button that emits backRequested()
//              so the host StackView can pop.
Item {
    id: detailRoot

    property bool showBack: false
    signal backRequested()

    clip: true

    // -- Related Words resizable section --
    // _relationsHeight is user-set via the drag handle above the
    // Related Words ColumnLayout. -1 means "not set yet" -- in that
    // case _effectiveRelationsHeight falls back to a sensible default
    // (~38% of the available vertical space). _relationsMinHeight
    // depends on edit mode: enough for the "+ Add relation" button +
    // header in edit mode, just one chip-row in read mode.
    property real _relationsHeight: -1
    readonly property real _relationsMinHeight:
        appVM.entryVM.editMode ? 110 : 70
    readonly property real _effectiveRelationsHeight:
        _relationsHeight >= 0
            ? Math.max(_relationsMinHeight, _relationsHeight)
            : Math.max(_relationsMinHeight, Math.round(detailRoot.height * 0.32))

    // Invisible focus sink. Tapping outside any input transfers focus
    // here, which collapses the on-screen keyboard. Without this, iOS
    // / Android keep the IME open until the user explicitly hits Done
    // and the page feels stuck in edit mode. Item #2 in the plan.
    Item {
        id: focusSink
        width: 0
        height: 0
        focus: false
        // Keep keyboard-related Keys handlers from firing when focused.
        Keys.onPressed: (event) => event.accepted = false
    }

    // Tap-anywhere-to-dismiss. gesturePolicy: WithinBounds lets nested
    // TextField/MouseArea/Flickable still receive their own taps;
    // this handler only fires for "background" taps that bubbled up
    // because no child accepted them.
    TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        onTapped: {
            if (Qt.inputMethod.visible) {
                Qt.inputMethod.hide()
                focusSink.forceActiveFocus()
            }
        }
    }

    // Reserve bottom inset when the OS keyboard is up so the focused
    // field doesn't get covered. iOS's automatic content-inset works
    // poorly with our Flickable-inside-ColumnLayout layout, so we drive
    // it explicitly from Qt.inputMethod.keyboardRectangle. Item #7.
    readonly property real _keyboardInset: Qt.inputMethod.visible
        ? Math.max(0, Qt.inputMethod.keyboardRectangle.height
                   - (Platform.safeAreaBottom || 0))
        : 0

    ColumnLayout {
        anchors {
            fill: parent
            margins: Platform.pagePadding
            // Animate the keyboard inset so the layout slides rather
            // than snapping when the IME shows/hides.
            bottomMargin: Platform.pagePadding + detailRoot._keyboardInset
        }
        spacing: 16
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Header: title and actions
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ActionButton {
                    visible: detailRoot.showBack
                    text: TenjinIcons.chevronLeft
                    font.family: TenjinIcons.family
                    variant: "neutral"
                    onClicked: detailRoot.backRequested()
                }

                // Title — plain Text in read mode, editable TextField in
                // edit mode so the user can rename the entry. The previous
                // version was always a Text bound to selectedWord, which
                // looked broken in edit mode (no visible cue that the title
                // was uneditable, and no way to rename).
                Text {
                    visible: !appVM.entryVM.editMode
                    text: appVM.entryVM.selectedWord
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: appVM.entryVM.editMode
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(Platform.touchTarget + 8,
                                                     titleEdit.implicitHeight + 12)
                    radius: Platform.radius
                    color: Platform.bg
                    border.color: titleEdit.activeFocus ? Platform.accent : Platform.border
                    border.width: titleEdit.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                    TextField {
                        id: titleEdit
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        // The Basic-style default background and padding fight
                        // the wrapping Rectangle: the field reports a small
                        // implicitHeight for the large title font and clips
                        // descenders. Draw no own background, zero the vertical
                        // padding, and centre the text instead.
                        background: null
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        // Binding to selectedWord. The user typing breaks
                        // this binding (QML auto-replaces it with the
                        // assignment from the keystroke). To recover, we
                        // restore the binding with Qt.binding() whenever
                        // the field hides (Cancel/Save) and whenever a
                        // rename commits, so the next time edit mode is
                        // entered the field shows the persisted title --
                        // not stale typed text.
                        text: appVM.entryVM.selectedWord
                        onVisibleChanged: {
                            if (!visible) {
                                text = Qt.binding(function() {
                                    return appVM.entryVM.selectedWord
                                })
                            }
                        }
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                        selectByMouse: true
                        onEditingFinished: {
                            const t = text.trim()
                            // Empty or unchanged: restore the binding and
                            // bail.
                            if (t.length === 0 || t === appVM.entryVM.selectedWord) {
                                text = Qt.binding(function() {
                                    return appVM.entryVM.selectedWord
                                })
                                return
                            }
                            appVM.entryVM.renameEntry(appVM.entryVM.selectedEntryId, t)
                            // Re-bind after rename so the field reflects
                            // the canonical title (which is now == t).
                            text = Qt.binding(function() {
                                return appVM.entryVM.selectedWord
                            })
                        }
                    }
                }

                ActionButton {
                    visible: !appVM.entryVM.editMode
                    text: qsTr("Edit")
                    variant: "neutral"
                    onClicked: appVM.entryVM.beginEdit()
                }

                // Desktop: Save/Cancel/Delete inline with the title. Use a
                // RowLayout so the parent reserves its width and the fillWidth
                // title cannot overlap it on wide displays.
                RowLayout {
                    visible: appVM.entryVM.editMode && !Platform.isMobile
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    ActionButton { text: qsTr("Save");        variant: "success"; onClicked: appVM.entryVM.saveEdit() }
                    ActionButton { text: qsTr("Cancel");      variant: "neutral"; onClicked: appVM.entryVM.cancelEdit() }
                    ActionButton { text: qsTr("Delete Word"); variant: "danger";  onClicked: deleteEntryConfirm.open() }
                }
            }

            // Mobile edit actions: full-width second row.
            RowLayout {
                visible: appVM.entryVM.editMode && Platform.isMobile
                Layout.fillWidth: true
                spacing: 8
                ActionButton { Layout.fillWidth: true; text: qsTr("Save");   variant: "success"; onClicked: appVM.entryVM.saveEdit() }
                ActionButton { Layout.fillWidth: true; text: qsTr("Cancel"); variant: "neutral"; onClicked: appVM.entryVM.cancelEdit() }
                ActionButton { Layout.fillWidth: true; text: qsTr("Delete"); variant: "danger";  onClicked: deleteEntryConfirm.open() }
            }
        }

        // Tags
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: qsTr("Tags:"); color: Platform.textMuted; font.pixelSize: Platform.fontBase }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: appVM.entryVM.wordTags
                    delegate: TagChip {
                        required property var modelData
                        tagName: modelData.name
                        tagId: modelData.id
                        editable: appVM.entryVM.editMode
                        onRemoveClicked: (tid) => appVM.entryVM.detachTag(appVM.entryVM.selectedEntryId, tid)
                    }
                }

                // "+ tag": popup to create-or-attach.
                Rectangle {
                    id: addTagButton
                    visible: appVM.entryVM.editMode
                    width: addTagText.implicitWidth + 24
                    height: Platform.isMobile ? 36 : 24
                    radius: height / 2
                    color: addTagArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        id: addTagText
                        anchors.centerIn: parent
                        text: qsTr("+ tag")
                        font.pixelSize: Platform.fontBase - 2
                        color: Platform.textMuted
                    }
                    MouseArea {
                        id: addTagArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tagPopup.allTags = appVM.entryVM.getAllTags()
                            newTagField.text = ""
                            tagPopup.open()
                            newTagField.forceActiveFocus()
                        }
                    }

                    Popup {
                        id: tagPopup
                        // Keyboard-aware: flip above the button when the
                        // popup + on-screen keyboard would not fit below.
                        readonly property real _kb: Qt.inputMethod.visible
                            ? Qt.inputMethod.keyboardRectangle.height / Platform.devicePixelRatio
                            : 0
                        y: {
                            const below = addTagButton.height + 4
                            const overlayH = Overlay.overlay ? Overlay.overlay.height : 0
                            const globalY = addTagButton.mapToItem(Overlay.overlay, 0, below).y
                            return (overlayH > 0 && globalY + height > overlayH - _kb)
                                   ? -(height + 4)
                                   : below
                        }
                        width: 240
                        // Explicit height: with an assigned contentItem and no
                        // height, the Popup can resolve to zero and the
                        // background renders with no area (transparent).
                        height: tagPopupCol.implicitHeight + padding * 2
                        padding: 8
                        property var allTags: []

                        background: Rectangle {
                            implicitWidth: 240
                            implicitHeight: 48
                            color: Platform.surface
                            radius: Platform.radius
                            border.color: Platform.border
                            border.width: 1
                        }

                        contentItem: ColumnLayout {
                            id: tagPopupCol
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Platform.touchTarget
                                color: Platform.bg
                                radius: Platform.radius - 2
                                border.color: newTagField.activeFocus ? Platform.accent : Platform.border
                                border.width: newTagField.activeFocus ? 2 : 1

                                TextField {
                                    id: newTagField
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    placeholderText: qsTr("New tag name\u2026 (Enter)")
                                    placeholderTextColor: Platform.textMuted
                                    color: Platform.textPrimary
                                    font.pixelSize: Platform.fontBase
                                    background: null
                                    onAccepted: {
                                        if (text.trim().length > 0
                                            && appVM.entryVM.createAndAttachTag(text)) {
                                            text = ""
                                            tagPopup.close()
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border; opacity: 0.5 }

                            Text {
                                visible: tagPopup.allTags.length > 0
                                text: qsTr("Existing tags")
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase - 3
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight, 200)
                                clip: true
                                model: tagPopup.allTags

                                delegate: ItemDelegate {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: Platform.touchTarget * 0.85
                                    background: Rectangle {
                                        color: hovered ? Platform.surfaceAlt : "transparent"
                                        radius: Platform.radius - 2
                                    }
                                    contentItem: Text {
                                        text: modelData.name ?? ""
                                        color: Platform.textPrimary
                                        font.pixelSize: Platform.fontBase
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 6
                                    }
                                    onClicked: {
                                        appVM.entryVM.attachTag(appVM.entryVM.selectedEntryId, modelData.id)
                                        tagPopup.close()
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: qsTr("No tags yet \u2014 type above to create one")
                                    color: Platform.textMuted
                                    font.pixelSize: Platform.fontBase - 2
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        // Per-entry language. Lets the user assign / change the language
        // for THIS entry independently of the global filter. The chip
        // shows the current code (or "—" when unspecified); tap to cycle
        // through availableLanguages + a "+ new" affordance, edit-mode-only.
        // This completes the #13 multi-language work — Settings drives the
        // global filter, this drives per-entry assignment.
        // Per-entry language picker. Edit-mode-only ComboBox showing the
        // builtin language catalogue plus any custom codes already in
        // use. Selecting (none) clears the language. Read-mode shows
        // the current code as a static chip (or hides the row entirely
        // when nothing is set).
        RowLayout {
            id: langRow
            Layout.fillWidth: true
            spacing: 8
            visible: appVM.entryVM.selectedEntryId > 0

            readonly property string currentCode:
                appVM.entryVM.entryLanguage(appVM.entryVM.selectedEntryId)
            readonly property bool   hasLang: langRow.currentCode.length > 0

            function buildOptions() {
                // Unified shape with the interface + filter pickers:
                // { code, name, flags }. name uses the LanguageFlags catalogue
                // (single source of truth); flags drives LanguageFlagRow.
                const opts = [{ code: "", name: qsTr("(none)"), flags: [] }]
                const builtin = appVM.builtinLanguages
                const seen = {}
                for (let i = 0; i < builtin.length; i++) {
                    const b = builtin[i]
                    opts.push({ code: b.code,
                                name: LanguageFlags.name(b.code) || b.name,
                                flags: LanguageFlags.flags(b.code) })
                    seen[b.code] = true
                }
                const custom = appVM.customLanguages.concat(appVM.availableLanguages)
                for (let j = 0; j < custom.length; j++) {
                    if (!seen[custom[j]])
                        opts.push({ code: custom[j],
                                    name: custom[j] + "  " + qsTr("(custom)"),
                                    flags: LanguageFlags.flags(custom[j]) })
                }
                return opts
            }
            property var options: buildOptions()
            Connections {
                target: appVM
                function onAvailableLanguagesChanged() { langRow.options = langRow.buildOptions() }
                function onCustomLanguagesChanged()    { langRow.options = langRow.buildOptions() }
            }

            Text {
                text: qsTr("Language:")
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
            }

            // Read mode: static chip showing the current code (or hidden
            // when nothing is set, so the row collapses to just the
            // "Language:" label and feels less intrusive).
            Rectangle {
                visible: !appVM.entryVM.editMode && langRow.hasLang
                Layout.preferredHeight: Platform.chipHeight
                Layout.preferredWidth: langRoChip.implicitWidth + 28
                radius: Platform.chipRadius
                color: Platform.accent
                Text {
                    id: langRoChip
                    anchors.centerIn: parent
                    text: langRow.currentCode
                    color: Platform.textOnDark
                    font.pixelSize: Platform.fontSmall
                    font.bold: true
                    font.family: Platform.fontMono
                }
            }
            Text {
                visible: !appVM.entryVM.editMode && !langRow.hasLang
                text: qsTr("(none)")
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
                font.italic: true
            }

            // Edit mode: ComboBox + Add-custom button.
            ComboBox {
                id: entryLangCombo
                visible: appVM.entryVM.editMode
                Layout.preferredWidth: 220
                Layout.preferredHeight: Platform.touchTarget
                leftPadding: 12
                rightPadding: 8
                font.pixelSize: Platform.fontBase
                model: langRow.options
                textRole: "name"
                valueRole: "code"

                function _syncToEntry() {
                    const code = langRow.currentCode
                    for (let i = 0; i < langRow.options.length; i++) {
                        if (langRow.options[i].code === code) {
                            currentIndex = i
                            return
                        }
                    }
                    currentIndex = 0
                }
                Component.onCompleted: _syncToEntry()
                onModelChanged: _syncToEntry()
                onVisibleChanged: if (visible) _syncToEntry()
                Connections {
                    target: appVM.entryVM
                    function onSelectedEntryChanged() { entryLangCombo._syncToEntry() }
                }

                onActivated: (idx) => {
                    const sel = langRow.options[idx]
                    if (sel && appVM.entryVM.selectedEntryId > 0)
                        appVM.entryVM.setEntryLanguage(appVM.entryVM.selectedEntryId, sel.code)
                }

                // App-consistent skin (matches ContentBlock pos picker
                // and SettingsPage language combo).
                background: Rectangle {
                    radius: Platform.radius
                    color: Platform.surface
                    border.color: entryLangCombo.activeFocus ? Platform.accent : Platform.border
                    border.width: entryLangCombo.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                }
                contentItem: RowLayout {
                    id: entryLangContent
                    spacing: Platform.spacingMd
                    property var _cur: langRow.options[entryLangCombo.currentIndex] || ({ flags: [], name: "" })
                    LanguageFlagRow {
                        visible: entryLangContent._cur.flags.length > 0
                        codes: entryLangContent._cur.flags
                    }
                    Text {
                        Layout.fillWidth: true
                        rightPadding: entryLangCombo.indicator.width + 6
                        text: entryLangContent._cur.name
                        color: Platform.textPrimary
                        font: entryLangCombo.font
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                indicator: Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 12
                    }
                    text: TenjinIcons.expandMore
        font.family: TenjinIcons.family
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontBase
                }
                popup: Popup {
                    y: entryLangCombo.height + 2
                    width: entryLangCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 320)
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
                        model: entryLangCombo.popup.visible ? entryLangCombo.delegateModel : null
                        currentIndex: entryLangCombo.highlightedIndex
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
                delegate: ItemDelegate {
                    id: entryLangDelegate
                    required property var modelData
                    required property int index
                    width: entryLangCombo.width
                    height: 32
                    highlighted: entryLangCombo.highlightedIndex === index
                    contentItem: RowLayout {
                        spacing: Platform.spacingMd
                        LanguageFlagRow { codes: entryLangDelegate.modelData.flags }
                        Text {
                            Layout.fillWidth: true
                            leftPadding: 2
                            text: entryLangDelegate.modelData.name
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    background: Rectangle {
                        color: entryLangDelegate.highlighted ? Platform.surfaceAlt : "transparent"
                    }
                }
            }

            Rectangle {
                visible: appVM.entryVM.editMode
                Layout.preferredWidth: entryAddLangLbl.implicitWidth + 22
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: entryAddLangArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                border.color: Platform.border
                border.width: 1
                Text {
                    id: entryAddLangLbl
                    anchors.centerIn: parent
                    text: qsTr("+ Custom")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontSmall
                    font.bold: true
                }
                MouseArea {
                    id: entryAddLangArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entryCustomLangDialog.open()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Custom-code dialog for languages outside the builtin catalogue.
        ThemedDialog {
            id: entryCustomLangDialog
            title: qsTr("Add custom language code")
            width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 400, 420) : 420
            padding: 20
            x: parent ? Math.round((parent.width  - width)  / 2) : 0
            y: parent ? Math.round((parent.height - height) / 2) : 0
            onAboutToShow: entryCustomLangInput.text = ""
            standardButtons: entryCustomLangInput.text.trim().length > 0
                             ? (Dialog.Ok | Dialog.Cancel)
                             : Dialog.Cancel
            onAccepted: {
                const c = entryCustomLangInput.text.trim().toLowerCase()
                if (c.length > 0 && appVM.entryVM.selectedEntryId > 0)
                    appVM.addCustomLanguage(c)   // persist globally for all pickers
                    appVM.entryVM.setEntryLanguage(appVM.entryVM.selectedEntryId, c)
            }
            ColumnLayout {
                spacing: 10
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Assign a language code not in the built-in list (rare ISO codes, conlangs, etc.).")
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontSmall
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: Platform.bg
                    border.color: entryCustomLangInput.activeFocus ? Platform.accent : Platform.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                    TextField {
                        id: entryCustomLangInput
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: qsTr("e.g. yue, tlh, nv")
                        placeholderTextColor: Platform.textMuted
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.family: Platform.fontMono
                        background: Rectangle { color: "transparent" }
                        Keys.onReturnPressed: entryCustomLangDialog.accept()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Platform.border }

        // Content blocks
        GridContentView {
            id: blockGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            editMode: appVM.entryVM.editMode
        }

        // Add content buttons (wrap on narrow screens)
        Flow {
            Layout.fillWidth: true
            visible: appVM.entryVM.editMode
            spacing: 8

            Repeater {
                model: [
                    { type: 0, label: qsTr("Definition") },
                    { type: 1, label: qsTr("Media Path") },
                    { type: 2, label: qsTr("Note") },
                    { type: 5, label: qsTr("Header")  },
                    { type: 6, label: qsTr("Tense")   },
                    { type: 4, label: qsTr("Formula") },
                    { type: 3, label: qsTr("Divider") }
                ]
                delegate: Rectangle {
                    required property var modelData
                    implicitHeight: Platform.touchTarget
                    implicitWidth: addLabel.implicitWidth + 24
                    radius: Platform.radius
                    color: addArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1

                    Text {
                        id: addLabel
                        anchors.centerIn: parent
                        text: "+ " + parent.modelData.label
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                        color: addArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appVM.entryVM.addContentBlock(parent.modelData.type)
                            // Scroll the block grid to the bottom so the new
                            // block is in view. callLater defers the read of
                            // contentHeight until after the model has been
                            // refreshed and GridContentView has relaid out
                            // — item #10 in the improvement plan.
                            Qt.callLater(function() {
                                if (blockGrid.contentHeight > blockGrid.height)
                                    blockGrid.contentY = blockGrid.contentHeight - blockGrid.height
                                else
                                    blockGrid.contentY = 0
                            })
                        }
                    }
                }
            }
        }

        // Related words section. Groups by kind so the page surfaces
        // Synonyms / Antonyms / Translations etc. separately. Always
        // visible (even when empty) so users discover the affordance; the
        // + Add Relation button is gated to edit mode like the other
        // structural editors above.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Platform.border
            visible: appVM.entryVM.selectedEntryId > 0
        }

        // Drag handle for the Related Words section below. Uses a
        // DragHandler (Qt 6 pointer-handler) rather than a MouseArea
        // because translation is reported in scene coords, unaffected
        // by the handle itself moving as the section resizes. Hit area
        // is 18px tall (comfortable on touch); the visual pill is
        // centred so it doesn't dominate the page.
        Rectangle {
            id: relationsDragHandle
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            visible: appVM.entryVM.selectedEntryId > 0
            color: relationsDragger.active || relHandleHover.hovered
                   ? Platform.surfaceAlt : "transparent"
            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

            // Pill visual -- conventional drag-handle look. Slightly wider
            // and always faintly visible so the affordance is discoverable.
            Rectangle {
                anchors.centerIn: parent
                width: 96
                height: 6
                radius: 3
                color: relationsDragger.active
                       ? Platform.accent
                       : relHandleHover.hovered
                           ? Platform.accentDark
                           : Platform.textMuted
                opacity: relationsDragger.active || relHandleHover.hovered ? 1.0 : 0.55
                Behavior on color   { ColorAnimation { duration: Platform.effDurationFast } }
                Behavior on opacity { NumberAnimation { duration: Platform.effDurationFast } }
            }

            HoverHandler {
                id: relHandleHover
                cursorShape: Qt.SplitVCursor
            }

            DragHandler {
                id: relationsDragger
                target: null               // we don't move the handle itself
                cursorShape: Qt.SplitVCursor
                property real heightAtPress: 0
                onActiveChanged: {
                    if (active) heightAtPress = detailRoot._effectiveRelationsHeight
                }
                onTranslationChanged: {
                    if (!active) return
                    // translation.y is the cumulative drag delta since
                    // press in scene coords. Dragging up -> negative y
                    // -> section grows. Dragging down -> positive y ->
                    // shrinks.
                    const minH = detailRoot._relationsMinHeight
                    // Cap at the content's natural height: once every relation
                    // is visible there is nothing more to reveal, so the handle
                    // stops there instead of dragging into empty space.
                    const contentH = relationsRoot.implicitHeight + 8
                    const maxH = Math.max(minH, Math.min(
                        blockGrid.height + heightAtPress - 140, contentH))
                    detailRoot._relationsHeight =
                        Math.max(minH, Math.min(maxH, heightAtPress - translation.y))
                }
            }
        }

        ColumnLayout {
            id: relationsRoot
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.minimumHeight: detailRoot._relationsMinHeight
            Layout.preferredHeight: detailRoot._effectiveRelationsHeight
            Layout.maximumHeight: detailRoot._effectiveRelationsHeight
            visible: appVM.entryVM.selectedEntryId > 0
            spacing: 10
            clip: true

            // _grouped is rebuilt whenever selectedEntryRelations changes,
            // yielding { synonym: [...], antonym: [...], ... }. The
            // canonical order matches AddRelationDialog._kinds so the
            // page is stable across sessions.
            readonly property var relations: appVM.entryVM.selectedEntryRelations
            readonly property var kindOrder: [
                { id: "synonym",     label: qsTr("Synonyms")     },
                { id: "antonym",     label: qsTr("Antonyms")     },
                { id: "related",     label: qsTr("Related")      },
                { id: "translation", label: qsTr("Translations") },
                { id: "inflection",  label: qsTr("Inflections")  }
            ]
            // Group _relations by kind. Recomputed by callers; we don't
            // cache it as a property to avoid re-evaluating on every
            // delegate creation (the Repeater handles that).
            function groupedRelations() {
                const groups = { synonym: [], antonym: [], related: [], translation: [], inflection: [] }
                for (let i = 0; i < relationsRoot.relations.length; i++) {
                    const r = relationsRoot.relations[i]
                    if (groups[r.kind] !== undefined) groups[r.kind].push(r)
                    else groups.related.push(r)  // unknown kind -> "Related"
                }
                return groups
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Related words")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontLarge
                    font.bold: true
                }
                Rectangle {
                    visible: appVM.entryVM.editMode
                    implicitHeight: Platform.touchTarget * 0.85
                    implicitWidth: addRelLbl.implicitWidth + 22
                    radius: Platform.radius
                    color: addRelArea.containsMouse ? Platform.accent : Platform.surfaceAlt
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    Text {
                        id: addRelLbl
                        anchors.centerIn: parent
                        text: qsTr("+ Add relation")
                        color: addRelArea.containsMouse ? Platform.textOnDark : Platform.textPrimary
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    }
                    MouseArea {
                        id: addRelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            addRelationDialog.sourceEntryId = appVM.entryVM.selectedEntryId
                            addRelationDialog.open()
                        }
                    }
                }
            }

            // Empty state.
            Text {
                visible: relationsRoot.relations.length === 0
                Layout.fillWidth: true
                text: appVM.entryVM.editMode
                      ? qsTr("No related words yet. Tap + Add relation to link a synonym, antonym, translation, or inflection.")
                      : qsTr("No related words yet.")
                color: Platform.textMuted
                font.pixelSize: Platform.fontBase
                wrapMode: Text.WordWrap
            }

            // One ColumnLayout per kind group. Repeater materialises only
            // the groups that have entries -- empty groups are hidden.
            Repeater {
                model: relationsRoot.kindOrder
                delegate: ColumnLayout {
                    id: kindGroup
                    required property var modelData
                    Layout.fillWidth: true
                    readonly property var entries: {
                        const g = relationsRoot.groupedRelations()
                        return g[kindGroup.modelData.id] || []
                    }
                    visible: kindGroup.entries.length > 0
                    spacing: 4

                    Text {
                        text: kindGroup.modelData.label + " \u00B7 " + kindGroup.entries.length
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        font.bold: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: kindGroup.entries
                            delegate: Rectangle {
                                id: relChip
                                required property var modelData
                                implicitHeight: Platform.chipHeight
                                implicitWidth: relChipRow.implicitWidth + 18
                                radius: Platform.chipRadius
                                color: relChipArea.containsMouse ? Platform.surfaceAlt : Platform.surface
                                border.color: Platform.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                                // Outer click target -- declared FIRST so it
                                // sits BENEATH the Row in stacking order. QML
                                // stacks later siblings on top; without this
                                // ordering the outer area swallows clicks
                                // meant for the inner x removeArea, causing
                                // "click x to delete" to navigate to the
                                // related word instead.
                                MouseArea {
                                    id: relChipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: relChip.modelData.relatedId > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (relChip.modelData.relatedId > 0)
                                                   appVM.entryVM.selectEntry(relChip.modelData.relatedId)
                                }

                                Row {
                                    id: relChipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: relChip.modelData.word.length > 0
                                              ? relChip.modelData.word
                                              : "(deleted)"
                                        color: relChip.modelData.word.length > 0
                                               ? Platform.textPrimary
                                               : Platform.textMuted
                                        font.pixelSize: Platform.fontSmall
                                        font.italic: relChip.modelData.word.length === 0
                                    }
                                    Text {
                                        visible: appVM.entryVM.editMode
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: TenjinIcons.close
                                        font.family: TenjinIcons.family
                                        color: removeArea.containsMouse ? Platform.danger : Platform.textMuted
                                        font.pixelSize: Platform.fontSmall
                                        font.weight: Font.Normal
                                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                                        MouseArea {
                                            id: removeArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            // Stop the click from bubbling --
                                            // belt-and-braces with the
                                            // sibling-order fix above, in case
                                            // the chip is ever wrapped in
                                            // something that propagates.
                                            onClicked: (mouse) => {
                                                appVM.entryVM.removeRelation(relChip.modelData.id)
                                                mouse.accepted = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Pack children to the top. Without a fillHeight filler,
            // ColumnLayout spreads surplus space between rows, which floated
            // the "Related words" header and placeholder away from the drag
            // handle instead of sitting directly under it.
            Item { Layout.fillHeight: true }
        }
    }

    // AddRelationDialog is hosted here so it can read selectedEntryId at
    // open time. Kept inside the EntryDetailView scope rather than at
    // Main.qml because nothing outside this view opens it.
    AddRelationDialog { id: addRelationDialog }

    ConfirmDialog {
        id: deleteEntryConfirm
        message: "Delete \"" + appVM.entryVM.selectedWord + "\"? This cannot be undone."
        onConfirmed: {
            appVM.entryVM.deleteEntry(appVM.entryVM.selectedEntryId)
            if (detailRoot.showBack) detailRoot.backRequested()
        }
    }
}





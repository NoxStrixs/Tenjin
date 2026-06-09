import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top-level Settings destination. Replaces the previous inline settingsPopup
// in Main.qml. Driven by appVM.currentPage === PageSettings (=5).
//
// applicationRoot is an ApplicationWindow (not a QQuickItem), so the
// property type must be `var` — the Windows QML compiler is stricter than
// the Linux/macOS one and refuses to assign Window to Item even at runtime.
Item {
    id: settingsRoot

    // ApplicationWindow injected by Main.qml so this page can call back to
    // window-scoped helpers (file dialogs, welcome popup) without ids.
    property var applicationRoot: null

    function _openWelcome()  { if (applicationRoot && applicationRoot.openWelcomePopup) applicationRoot.openWelcomePopup() }
    function _openImport()   { if (applicationRoot && applicationRoot.openImportDialog) applicationRoot.openImportDialog() }
    function _openExport()   { if (applicationRoot && applicationRoot.openExportDialog) applicationRoot.openExportDialog() }

    // Asks Main.qml to return to Words. Wired in Main.qml's StackLayout host.
    signal backRequested()

    component SectionHeader: Text {
        Layout.fillWidth: true
        Layout.leftMargin: Platform.spacingLg
        Layout.topMargin: Platform.spacingLg
        Layout.bottomMargin: Platform.spacingSm
        color: Platform.textMuted
        font.pixelSize: Platform.fontSmall
        font.bold: true
    }
    component SectionDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Platform.border
        opacity: 0.5
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: settingsRoot.width
            spacing: 0

            // Desktop title row with back arrow — mobile shows the title
            // in the window header so it can hide the title here.
            RowLayout {
                visible: !Platform.isMobile
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.topMargin: Platform.pagePadding
                Layout.rightMargin: Platform.pagePadding
                Layout.bottomMargin: Platform.spacingMd
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: Platform.touchTarget
                    Layout.preferredHeight: Platform.touchTarget
                    radius: Platform.radius
                    color: settingsBackArea.containsMouse ? Platform.surfaceAlt : "transparent"
                    border.color: Platform.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2039"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontTitle
                        font.bold: true
                    }
                    MouseArea {
                        id: settingsBackArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsRoot.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Settings"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
            }

            // ── Appearance ──────────────────────────────────────────────────
            SectionHeader { text: "Appearance" }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: themeRowArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: Platform.isDark ? "\u2600" : "\u263E"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Theme"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: Platform.isDark ? "Dark" : "Light"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 28
                        radius: 14
                        color: Platform.isDark ? Platform.accent : Platform.border
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            y: 3
                            x: Platform.isDark ? parent.width - width - 3 : 3
                            color: Platform.bg
                            Behavior on x { NumberAnimation { duration: Platform.durationFast; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                MouseArea {
                    id: themeRowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.setTheme(Platform.isDark ? 0 : 1)
                }
            }
            SectionDivider {}

            // ── Language ────────────────────────────────────────────────────
            SectionHeader { text: "Language" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: "transparent"
                opacity: 0.55
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: "\uD83C\uDF10"; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Interface language"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: "English (more languages coming soon)"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                }
            }
            SectionDivider {}

            // ── Onboarding ──────────────────────────────────────────────────
            SectionHeader { text: "Onboarding" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: showWelcomeArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: "\u21BB"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Show welcome again"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: "Re-open the first-launch carousel now"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: "\u203A"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: showWelcomeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { appVM.setWelcomeAcknowledged(false); settingsRoot._openWelcome() }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: resetNewsArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: "\u2709"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Reset news popups"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: "Show every news item again on next launch"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: "\u203A"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: resetNewsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { appVM.resetNewsDismissals(); appVM.statusMessage = "News popups will reappear on next launch." }
                }
            }
            SectionDivider {}

            // ── Data ────────────────────────────────────────────────────────
            SectionHeader { text: "Data" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: importArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: "\u2934"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Import collection"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: "Restore from a Tenjin export (.json)"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: "\u203A"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea { id: importArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsRoot._openImport() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: exportArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: "\u2935"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Export collection"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: "Save all words, decks and tags to a .json file"; color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: "\u203A"; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea { id: exportArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsRoot._openExport() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dataPathRow.implicitHeight + Platform.spacingMd * 2
                color: "transparent"
                ColumnLayout {
                    id: dataPathRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Platform.spacingLg + Platform.fontLarge + Platform.spacingMd; rightMargin: Platform.spacingLg }
                    spacing: 1
                    Text { text: "App data location"; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: appVM.appDataLocation
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            // ── Language ─────────────────────────────────────────────
            // Multi-language filter. Single ComboBox driven by the
            // builtin language catalogue (en, es, ja, ...) merged with
            // any custom codes already attached to existing entries.
            // Setting the filter narrows the words list and search; new
            // entries created while a filter is active inherit that
            // language so they don't immediately disappear.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Platform.spacingXl
                Layout.preferredHeight: langHeader.implicitHeight + Platform.spacingMd * 2
                color: "transparent"
                Text {
                    id: langHeader
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Platform.spacingLg }
                    text: "Language"
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontLarge
                    font.bold: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: langPickerCol.implicitHeight + Platform.spacingMd * 2
                color: "transparent"
                ColumnLayout {
                    id: langPickerCol
                    anchors {
                        left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                        leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg
                    }
                    spacing: 6

                    Text {
                        text: "Current language filter"
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Show only entries in one language. New entries you add while a filter is active will inherit that language. Entries with no language assigned always show, no matter the filter."
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                    }

                    // Combined options = "All languages" + builtin + any
                    // custom codes already in use that aren't in the
                    // builtin list. Recomputed on availableLanguages
                    // change so a custom code added on EntryDetailView
                    // shows here too.
                    RowLayout {
                        id: langComboRow
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 8

                        function buildOptions() {
                            const opts = [{ code: "", label: "(All languages)" }]
                            const builtin = appVM.builtinLanguages
                            const seen = {}
                            for (let i = 0; i < builtin.length; i++) {
                                const b = builtin[i]
                                opts.push({ code: b.code, label: b.code + "  --  " + b.name })
                                seen[b.code] = true
                            }
                            const custom = appVM.availableLanguages
                            for (let j = 0; j < custom.length; j++) {
                                if (!seen[custom[j]])
                                    opts.push({ code: custom[j], label: custom[j] + "  (custom)" })
                            }
                            return opts
                        }

                        property var options: buildOptions()
                        Connections {
                            target: appVM
                            function onAvailableLanguagesChanged() {
                                langComboRow.options = langComboRow.buildOptions()
                            }
                        }

                        ComboBox {
                            id: langCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: Platform.touchTarget
                            font.pixelSize: Platform.fontBase
                            model: langComboRow.options
                            textRole: "label"
                            valueRole: "code"

                            // Keep the displayed selection synced with the
                            // VM property. currentIndex stays in lockstep
                            // even if the filter is set elsewhere (e.g.
                            // EntryDetailView picker).
                            function _syncToVM() {
                                const code = appVM.entryVM.currentLanguageFilter
                                for (let i = 0; i < langComboRow.options.length; i++) {
                                    if (langComboRow.options[i].code === code) {
                                        currentIndex = i
                                        return
                                    }
                                }
                                currentIndex = 0
                            }
                            Component.onCompleted: _syncToVM()
                            onModelChanged: _syncToVM()
                            Connections {
                                target: appVM.entryVM
                                function onCurrentLanguageFilterChanged() { langCombo._syncToVM() }
                            }

                            onActivated: (idx) => {
                                const sel = langComboRow.options[idx]
                                if (sel) appVM.entryVM.currentLanguageFilter = sel.code
                            }

                            // App-consistent skin -- mirrors the ContentBlock
                            // pos ComboBox styling so the page doesn't look
                            // like it's got a stock Qt widget pasted in.
                            background: Rectangle {
                                radius: Platform.radius
                                color: Platform.surface
                                border.color: langCombo.activeFocus ? Platform.accent : Platform.border
                                border.width: langCombo.activeFocus ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                            }
                            contentItem: Text {
                                leftPadding: 12
                                rightPadding: langCombo.indicator.width + 6
                                text: langCombo.displayText
                                color: Platform.textPrimary
                                font: langCombo.font
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: Text {
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: 12
                                }
                                text: "\u25BE"
                                color: Platform.textMuted
                                font.pixelSize: Platform.fontBase
                            }
                            popup: Popup {
                                y: langCombo.height + 2
                                width: langCombo.width
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
                                    model: langCombo.popup.visible ? langCombo.delegateModel : null
                                    currentIndex: langCombo.highlightedIndex
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                }
                            }
                            delegate: ItemDelegate {
                                id: langDelegate
                                required property var modelData
                                required property int index
                                width: langCombo.width
                                height: 32
                                highlighted: langCombo.highlightedIndex === index
                                contentItem: Text {
                                    leftPadding: 10
                                    text: langDelegate.modelData.label
                                    color: Platform.textPrimary
                                    font.pixelSize: Platform.fontBase
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: langDelegate.highlighted ? Platform.surfaceAlt : "transparent"
                                }
                            }
                        }

                        // "+ Add" opens a small dialog where the user can
                        // type a custom code not in the builtin list. The
                        // typed code becomes the active filter; any
                        // future entry assigned that language will surface
                        // it here via availableLanguages.
                        Rectangle {
                            Layout.preferredWidth: addLangLbl.implicitWidth + 22
                            Layout.preferredHeight: Platform.touchTarget
                            radius: Platform.radius
                            color: addLangArea.containsMouse ? Platform.accentDark : Platform.accent
                            Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                            Text {
                                id: addLangLbl
                                anchors.centerIn: parent
                                text: "+ Add"
                                color: Platform.bg
                                font.pixelSize: Platform.fontBase
                                font.bold: true
                            }
                            MouseArea {
                                id: addLangArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: customLangDialog.open()
                            }
                        }
                    }
                }
            }

            // Custom-code dialog. Lets the user type any code (ISO 639-1
            // or otherwise) not in the builtin catalogue. Activates the
            // filter on accept so the user sees the effect immediately.
            ThemedDialog {
                id: customLangDialog
                title: "Add custom language code"
                width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 400, 420) : 420
                padding: 20
                x: parent ? Math.round((parent.width  - width)  / 2) : 0
                y: parent ? Math.round((parent.height - height) / 2) : 0
                onAboutToShow: customLangInput.text = ""
                standardButtons: customLangInput.text.trim().length > 0
                                 ? (Dialog.Ok | Dialog.Cancel)
                                 : Dialog.Cancel
                onAccepted: {
                    const c = customLangInput.text.trim().toLowerCase()
                    if (c.length > 0) appVM.entryVM.currentLanguageFilter = c
                }
                ColumnLayout {
                    spacing: 10
                    width: parent.width
                    Text {
                        Layout.fillWidth: true
                        text: "Use this for languages that aren't in the built-in list (rare ISO codes, conlangs, or your own internal categories)."
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Platform.touchTarget
                        radius: Platform.radius
                        color: Platform.bg
                        border.color: customLangInput.activeFocus ? Platform.accent : Platform.border
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                        TextField {
                            id: customLangInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            placeholderText: "e.g. yue, tlh, nv"
                            placeholderTextColor: Platform.textMuted
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.family: "monospace"
                            background: Rectangle { color: "transparent" }
                            Keys.onReturnPressed: customLangDialog.accept()
                        }
                    }
                }
            }

            // ── Danger zone ───────────────────────────────────────────
            // Bulk wipes. Each goes through a typed-confirmation dialog
            // (user types "DELETE" exactly) so an accidental tap can't
            // nuke the database. The C++ side wraps each action in a
            // single SQL DELETE; FK cascades clean up dependent rows.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Platform.spacingXl
                Layout.preferredHeight: dangerHeader.implicitHeight + Platform.spacingMd * 2
                color: "transparent"
                Text {
                    id: dangerHeader
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Platform.spacingLg }
                    text: "Danger zone"
                    color: Platform.danger
                    font.pixelSize: Platform.fontLarge
                    font.bold: true
                }
            }

            Repeater {
                model: [
                    { key: "words",   label: "Delete all words",  hint: "Removes every entry, its content blocks, tags, and relations." },
                    { key: "tags",    label: "Delete all tags",   hint: "Removes every tag; words and decks stay, but lose tag associations." },
                    { key: "decks",   label: "Delete all decks",  hint: "Removes every deck (manual and smart). Words and tags stay." },
                    { key: "all",     label: "Delete everything", hint: "Wipes every word, tag, and deck. Cannot be undone." }
                ]
                delegate: Rectangle {
                    id: dz
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: dzRow.implicitHeight + Platform.spacingMd * 2
                    color: dzArea.containsMouse ? Qt.rgba(Platform.danger.r, Platform.danger.g, Platform.danger.b, 0.10)
                                                : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: dzArea.containsMouse ? Platform.danger : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.durationFast } }
                    }

                    ColumnLayout {
                        id: dzRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Platform.spacingLg + 4; rightMargin: Platform.spacingLg }
                        spacing: 1
                        Text {
                            text: dz.modelData.label
                            color: Platform.danger
                            font.pixelSize: Platform.fontBase
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dz.modelData.hint
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                    MouseArea {
                        id: dzArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dangerConfirm.openFor(dz.modelData.key, dz.modelData.label)
                    }
                }
            }

            Item { Layout.preferredHeight: Platform.spacingXl + Platform.safeAreaBottom }
        }
    }

    // Typed-confirmation dialog. The user must type "DELETE" exactly
    // before the destructive button enables; an Esc / Cancel aborts.
    ThemedDialog {
        id: dangerConfirm
        title: "Confirm destructive action"
        width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 420, 440) : 440
        padding: 20
        x: parent ? Math.round((parent.width  - width)  / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0

        property string actionKey:   ""
        property string actionLabel: ""

        function openFor(key, label) {
            actionKey    = key
            actionLabel  = label
            confirmInput.text = ""
            open()
            confirmInput.forceActiveFocus()
        }

        onAccepted: {
            if (confirmInput.text !== "DELETE") return
            if (actionKey === "words")      appVM.deleteAllWords()
            else if (actionKey === "tags")  appVM.deleteAllTags()
            else if (actionKey === "decks") appVM.deleteAllDecks()
            else if (actionKey === "all")   appVM.deleteEverything()
        }

        standardButtons: confirmInput.text === "DELETE"
                         ? (Dialog.Ok | Dialog.Cancel)
                         : Dialog.Cancel

        ColumnLayout {
            spacing: 14
            width: parent.width

            Text {
                Layout.fillWidth: true
                text: "You're about to: " + dangerConfirm.actionLabel
                color: Platform.danger
                font.pixelSize: Platform.fontBase
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: "This cannot be undone. Type DELETE (in capitals) to confirm."
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                color: Platform.bg
                border.color: confirmInput.text === "DELETE" ? Platform.danger
                          : confirmInput.activeFocus         ? Platform.accent
                                                              : Platform.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }
                TextField {
                    id: confirmInput
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    placeholderText: "Type DELETE to confirm"
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    font.family: "monospace"
                    background: Rectangle { color: "transparent" }
                }
            }
        }
    }
}


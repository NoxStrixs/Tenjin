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
    function _openWhatsNew() { if (applicationRoot && applicationRoot.openWhatsNew) applicationRoot.openWhatsNew() }
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
    // A tappable navigation row: leading icon, title + subtitle, trailing
    // chevron, full-row hover + click. Consolidates ~8 duplicated blocks.
    component NavRow: Rectangle {
        id: navRow
        property string icon
        property string title
        property string subtitle
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: Platform.touchTarget + 16
        color: navRowArea.containsMouse ? Platform.surfaceAlt : "transparent"
        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

        RowLayout {
            anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
            spacing: Platform.spacingMd
            Text {
                text: navRow.icon
                font.family: TenjinIcons.family
                color: Platform.textMuted
                font.pixelSize: Platform.fontLarge
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: navRow.title; color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                Text {
                    visible: navRow.subtitle.length > 0
                    text: navRow.subtitle; color: Platform.textMuted; font.pixelSize: Platform.fontSmall
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
            }
            Text {
                text: TenjinIcons.chevronRight
                font.family: TenjinIcons.family
                color: Platform.textMuted
                font.pixelSize: Platform.fontLarge
            }
        }
        MouseArea {
            id: navRowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navRow.clicked()
        }
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
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
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
                    text: qsTr("Settings")
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontTitle
                    font.bold: true
                }
            }

            // ── Appearance ──────────────────────────────────────────────────
            SectionHeader { text: qsTr("Appearance") }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: themeRowArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: Platform.isDark ? TenjinIcons.lightMode : TenjinIcons.darkMode; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: qsTr("Theme"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: Platform.isDark ? qsTr("Dark") : qsTr("Light"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    ToggleSwitch {
                        checked: Platform.isDark
                        onToggled: appVM.setTheme(Platform.isDark ? 0 : 1)
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

            // Reduced motion toggle. Mirrors the theme row. Disables page
            // transitions and micro-interactions for accessibility / battery.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: motionRowArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.autoAwesome; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: qsTr("Reduce motion"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text {
                            text: Platform.reducedMotionSystem
                                  ? qsTr("On (following system setting)")
                                  : (appVM.reducedMotion ? qsTr("On") : qsTr("Off"))
                            color: Platform.textMuted; font.pixelSize: Platform.fontSmall
                        }
                    }
                    ToggleSwitch {
                        checked: appVM.reducedMotion
                        onToggled: appVM.setReducedMotion(!appVM.reducedMotion)
                    }
                }
                MouseArea {
                    id: motionRowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.setReducedMotion(!appVM.reducedMotion)
                }
            }
            SectionDivider {}

            SectionHeader { text: qsTr("Language") }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: uiLangCol.implicitHeight + Platform.spacingMd * 2
                color: "transparent"
                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Platform.spacingLg
                        rightMargin: Platform.spacingLg
                        topMargin: Platform.spacingMd
                        bottomMargin: Platform.spacingMd
                    }
                    spacing: Platform.spacingMd
                    Text {
                        text: TenjinIcons.globe
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontLarge
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        id: uiLangCol
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: qsTr("Interface language")
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Language of buttons, menus, and labels. Changes apply instantly.")
                            color: Platform.textMuted
                            font.pixelSize: Platform.fontSmall
                            wrapMode: Text.WordWrap
                        }
                        StyledComboBox {
                            id: uiLangCombo
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: Platform.touchTarget
                            // {code, name, flags} per supported UI language. Name
                            // and flag codes come from the generated LanguageFlags
                            // singleton (single source of truth).
                            function buildOptions() {
                                const codes = appVM.supportedUiLanguages
                                const opts = []
                                for (let i = 0; i < codes.length; i++) {
                                    const c = codes[i]
                                    opts.push({ code: c,
                                                name: LanguageFlags.name(c),
                                                flags: LanguageFlags.flags(c) })
                                }
                                return opts
                            }
                            property var options: buildOptions()
                            model: options
                            textRole: "name"
                            valueRole: "code"
                            function _sync() {
                                const code = appVM.uiLanguage
                                for (let i = 0; i < options.length; i++)
                                    if (options[i].code === code) { currentIndex = i; return }
                                currentIndex = 0
                            }
                            Component.onCompleted: _sync()
                            onModelChanged: _sync()
                            Connections {
                                target: appVM
                                function onUiLanguageChanged() { uiLangCombo._sync() }
                            }
                            onActivated: (idx) => {
                                const sel = uiLangCombo.options[idx]
                                if (sel) appVM.uiLanguage = sel.code
                            }
                            // Flag(s) + native name, no code suffix.
                            delegate: ItemDelegate {
                                id: uiDel
                                required property var modelData
                                required property int index
                                width: uiLangCombo.width
                                height: 32
                                highlighted: uiLangCombo.highlightedIndex === index
                                contentItem: RowLayout {
                                    spacing: Platform.spacingMd
                                    LanguageFlagRow { codes: uiDel.modelData.flags }
                                    Text {
                                        Layout.fillWidth: true
                                        text: uiDel.modelData.name
                                        color: Platform.textPrimary
                                        font.pixelSize: Platform.fontBase
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }
                                background: Rectangle {
                                    color: uiDel.highlighted ? Platform.surfaceAlt : "transparent"
                                }
                            }
                        }
                    }
                }
            }
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
                    text: qsTr("Language")
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
                        text: qsTr("Current language filter")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Show only entries in one language. New entries you add while a filter is active will inherit that language. Entries with no language assigned always show, no matter the filter.")
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
                            const opts = [{ code: "", label: qsTr("(All languages)") }]
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

                        // Vocab language filter — same StyledComboBox skin as the
                        // interface picker. Content stays text-only ("code -- name")
                        // because it allows arbitrary custom codes with no flag.
                        StyledComboBox {
                            id: langCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: Platform.touchTarget
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
                            Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                            Text {
                                id: addLangLbl
                                anchors.centerIn: parent
                                text: qsTr("+ Add")
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
                title: qsTr("Add custom language code")
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
                        text: qsTr("Use this for languages that aren't in the built-in list (rare ISO codes, conlangs, or your own internal categories).")
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
                        Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                        TextField {
                            id: customLangInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            placeholderText: qsTr("e.g. yue, tlh, nv")
                            placeholderTextColor: Platform.textMuted
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.family: Platform.fontMono
                            background: Rectangle { color: "transparent" }
                            Keys.onReturnPressed: customLangDialog.accept()
                        }
                    }
                }
            }

            SectionDivider {}

            // ── Study ─────────────────────────────────────────────────
            SectionHeader { text: qsTr("Study") }

            // Daily review reminder toggle.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.news; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: qsTr("Daily review reminder"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: qsTr("A daily nudge when cards are due"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    ToggleSwitch {
                        checked: notifService.reminderEnabled
                        onToggled: notifService.reminderEnabled = !notifService.reminderEnabled
                    }
                }
            }

            // Time picker — only visible when reminders are on.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Platform.touchTarget + 16 : 0
                visible: notifService.reminderEnabled
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.refresh; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Remind me at")
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                    }
                    // Hour spinner
                    SpinBox {
                        from: 0; to: 23
                        value: notifService.reminderHour
                        onValueModified: notifService.reminderHour = value
                        textFromValue: function(v) { return (v < 10 ? "0" : "") + v }
                        implicitWidth: 72
                    }
                    Text { text: ":"; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge }
                    SpinBox {
                        from: 0; to: 59
                        value: notifService.reminderMinute
                        onValueModified: notifService.reminderMinute = value
                        textFromValue: function(v) { return (v < 10 ? "0" : "") + v }
                        implicitWidth: 72
                    }
                }
            }

            SectionDivider {}

            SectionHeader { text: qsTr("Data") }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: importArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.upload; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: qsTr("Import collection"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: qsTr("Restore from a Tenjin export (.json)"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea { id: importArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsRoot._openImport() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: exportArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.download; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: qsTr("Export collection"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: qsTr("Save all words, decks and tags to a .json file"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
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
                    Text { text: qsTr("App data location"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: appVM.appDataLocation
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: syncRow.containsMouse ? Platform.surfaceAlt : "transparent"
                opacity: cloudService.available ? 1.0 : 0.55
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.sync; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: qsTr("Sync decks"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text {
                            text: cloudService.available
                                  ? qsTr("Back up and sync your decks.")
                                  : qsTr("Coming soon \u2014 requires a subscription.")
                            color: Platform.textMuted; font.pixelSize: Platform.fontSmall
                        }
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: syncRow; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cloudService.available) cloudService.syncDecks()
                        else notifService.toast(qsTr("Deck sync is coming soon!"))
                    }
                }
            }
            Connections {
                target: cloudService
                function onSyncResult(status, message) { notifService.toast(message) }
            }

            // ── Bug report ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: bugRow.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.bugReport; font.family: TenjinIcons.family; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: qsTr("Send feedback"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text { text: qsTr("Report a bug or suggest an improvement"); color: Platform.textMuted; font.pixelSize: Platform.fontSmall }
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: bugRow; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: bugReportDialog.open()
                }
            }

            SectionDivider {}

            // ── Privacy ─────────────────────────────────────────────────────
            SectionHeader { text: qsTr("Privacy") }

            // Consent status — shows the current age band / parental-consent
            // state established by the age screen. Read-only summary.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.info; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: qsTr("Data & consent"); color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true }
                        Text {
                            text: {
                                if (appVM.ageBand === 2) return qsTr("Standard account — cloud features available.")
                                if (appVM.ageBand === 1)
                                    return appVM.dataCollectionAllowed
                                           ? qsTr("Child account — parental consent on file.")
                                           : qsTr("Child account — local only until a parent consents.")
                                return qsTr("Age not yet set.")
                            }
                            color: Platform.textMuted; font.pixelSize: Platform.fontSmall
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Privacy policy
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: privacyArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Privacy policy")
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.info; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Privacy policy")
                        color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: privacyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://tenjin.app/privacy")
                }
            }

            // Terms of service
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: tosArea.containsMouse ? Platform.surfaceAlt : "transparent"
                Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Terms of service")
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.document; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Terms of service")
                        color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true
                    }
                    Text { text: TenjinIcons.chevronRight; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                }
                MouseArea {
                    id: tosArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://tenjin.app/terms")
                }
            }

            // Version
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 16
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingLg; rightMargin: Platform.spacingLg }
                    spacing: Platform.spacingMd
                    Text { text: TenjinIcons.autoAwesome; font.family: TenjinIcons.family; color: Platform.textMuted; font.pixelSize: Platform.fontLarge }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Version")
                        color: Platform.textPrimary; font.pixelSize: Platform.fontBase; font.bold: true
                    }
                    Text {
                        text: Qt.application.version
                        color: Platform.textMuted; font.pixelSize: Platform.fontBase
                    }
                }
            }

            SectionDivider {}
            // Onboarding-related actions, grouped under About.
            NavRow {
                icon: TenjinIcons.refresh
                title: qsTr("Show welcome again")
                subtitle: qsTr("Re-open the first-launch carousel now")
                onClicked: { appVM.setWelcomeAcknowledged(false); settingsRoot._openWelcome() }
            }

            // What's new
            NavRow {
                icon: TenjinIcons.autoAwesome
                title: qsTr("What's new")
                subtitle: qsTr("See the highlights from the latest update")
                onClicked: settingsRoot._openWhatsNew()
            }
            NavRow {
                icon: TenjinIcons.mail
                title: qsTr("Reset news popups")
                subtitle: qsTr("Show every news item again on next launch")
                onClicked: { appVM.resetNewsDismissals(); appVM.statusMessage = "News popups will reappear on next launch." }
            }
            SectionDivider {}

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
                    text: qsTr("Danger zone")
                    color: Platform.danger
                    font.pixelSize: Platform.fontLarge
                    font.bold: true
                }
            }

            Repeater {
                model: [
                    { key: "words",   label: qsTr("Delete all words"),  hint: qsTr("Removes every entry, its content blocks, tags, and relations.") },
                    { key: "tags",    label: qsTr("Delete all tags"),   hint: qsTr("Removes every tag; words and decks stay, but lose tag associations.") },
                    { key: "decks",   label: qsTr("Delete all decks"),  hint: qsTr("Removes every deck (manual and smart). Words and tags stay.") },
                    { key: "all",     label: qsTr("Delete everything"), hint: qsTr("Wipes every word, tag, and deck. Cannot be undone.") }
                ]
                delegate: Rectangle {
                    id: dz
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: dzRow.implicitHeight + Platform.spacingMd * 2
                    color: dzArea.containsMouse ? Qt.rgba(Platform.danger.r, Platform.danger.g, Platform.danger.b, 0.10)
                                                : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: dzArea.containsMouse ? Platform.danger : "transparent"
                        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
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

    BugReportDialog { id: bugReportDialog }
    ThemedDialog {
        id: dangerConfirm
        title: qsTr("Confirm destructive action")
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
            haptics.heavy()
        }

        standardButtons: confirmInput.text === "DELETE"
                         ? (Dialog.Ok | Dialog.Cancel)
                         : Dialog.Cancel

        ColumnLayout {
            spacing: 14
            width: parent.width

            Text {
                Layout.fillWidth: true
                text: qsTr("You're about to: ") + dangerConfirm.actionLabel
                color: Platform.danger
                font.pixelSize: Platform.fontBase
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("This cannot be undone. Type DELETE (in capitals) to confirm.")
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
                Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }
                TextField {
                    id: confirmInput
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    placeholderText: qsTr("Type DELETE to confirm")
                    placeholderTextColor: Platform.textMuted
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    font.family: Platform.fontMono
                    background: Rectangle { color: "transparent" }
                }
            }
        }
    }
}



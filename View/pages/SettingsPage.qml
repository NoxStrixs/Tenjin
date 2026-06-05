import TenjinView
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Top-level Settings destination. Replaces the previous inline settingsPopup
// in Main.qml. Driven by appVM.currentPage === PageSettings (=5).
//
// The page is a single scrollable column of "sections". Each section has a
// muted-uppercase heading and one or more clickable rows; row layout is
// inlined per-row rather than extracted to a helper component, so this file
// stays self-contained (no new QML_FILES entries beyond SettingsPage.qml,
// HelpPage.qml, NewsPage.qml in the View module).
Item {
    id: settingsRoot

    // applicationRoot is bound by Main.qml so this page can call back into
    // ApplicationWindow-scoped helpers (file dialogs, welcome popup) without
    // needing direct ids.
    property Item applicationRoot: null

    function _openWelcome()  { if (applicationRoot && applicationRoot.openWelcomePopup) applicationRoot.openWelcomePopup() }
    function _openImport()   { if (applicationRoot && applicationRoot.openImportDialog) applicationRoot.openImportDialog() }
    function _openExport()   { if (applicationRoot && applicationRoot.openExportDialog) applicationRoot.openExportDialog() }

    // Compact helper: a section header.
    component SectionHeader: Text {
        Layout.fillWidth: true
        Layout.leftMargin: Platform.spacingLg
        Layout.topMargin: Platform.spacingLg
        Layout.bottomMargin: Platform.spacingSm
        color: Platform.textMuted
        font.pixelSize: Platform.fontSmall
        font.bold: true
    }

    // Divider line between rows / sections.
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

            // Desktop title — mobile shows it in the window header.
            Text {
                visible: !Platform.isMobile
                Layout.fillWidth: true
                Layout.leftMargin: Platform.pagePadding
                Layout.topMargin: Platform.pagePadding
                Layout.bottomMargin: Platform.spacingMd
                text: "Settings"
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
            }

            // ── Appearance ──────────────────────────────────────────────────
            SectionHeader { text: "Appearance" }

            // Theme row
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
                    // Toggle pill
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

            // Locked language row (single option for now)
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

            // Show welcome again
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

            // Reset news popups
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
                    onClicked: {
                        appVM.resetNewsDismissals()
                        appVM.statusMessage = "News popups will reappear on next launch."
                    }
                }
            }

            SectionDivider {}

            // ── Data ────────────────────────────────────────────────────────
            SectionHeader { text: "Data" }

            // Import
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
                MouseArea {
                    id: importArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsRoot._openImport()
                }
            }

            // Export
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
                MouseArea {
                    id: exportArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsRoot._openExport()
                }
            }

            // App data location (read-only)
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

            Item { Layout.preferredHeight: Platform.spacingXl + Platform.safeAreaBottom }
        }
    }
}


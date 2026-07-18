import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import TenjinView

// Neutral age screen (COPPA / GDPR-K). Shown once on first launch, before any
// other onboarding, and blocks interaction until answered. Design notes:
//   * NEUTRAL by FTC guidance: it must not nudge the user toward a particular
//     answer. We ask for a birth year via a plain stepper with no hint that one
//     range unlocks more features, and no default that pre-selects "adult".
//   * The result is recorded once via appVM.setAgeBand; under-13 routes into the
//     parental-consent flow, 13+ proceeds normally.
//
// The host opens this when appVM.ageScreenRequired is true.
Popup {
    id: root
    parent: Overlay.overlay
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    padding: 0
    width:  Platform.isMobile ? Math.min(parent ? parent.width - 16 : 360, 480) : 480
    height: contentCol.implicitHeight + Platform.spacingXl * 2
    x: parent ? Math.max(8, (parent.width  - width)  / 2) : 8
    y: parent ? Math.max(Platform.safeAreaTop + 8, (parent.height - height) / 2) : 8

    signal answered(int band)

    // Current year, for the birth-year bounds. Computed once on open.
    property int thisYear: 2026
    // Start with no implied value: place the stepper mid-range, not at an adult
    // default, so the control itself doesn't suggest an answer.
    property int birthYear: thisYear - 20

    background: Rectangle {
        color: Platform.surface
        radius: Platform.radiusLarge
        border.color: Platform.border
        border.width: 1
    }

    ColumnLayout {
        id: contentCol
        width: parent.width
        anchors.centerIn: parent
        spacing: Platform.spacingLg

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Platform.spacingXl
            Layout.rightMargin: Platform.spacingXl
            Layout.topMargin: Platform.spacingXl
            text: qsTr("Before you start")
            color: Platform.textPrimary
            font.pixelSize: Platform.fontTitle
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Platform.spacingXl
            Layout.rightMargin: Platform.spacingXl
            text: qsTr("Please enter the year you were born. This helps us set up the right privacy protections for your account.")
            color: Platform.textMuted
            font.pixelSize: Platform.fontBase
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // Birth-year stepper — neutral control, no pre-filled adult value.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Platform.spacingMd

            Button {
                text: "\u2212"
                implicitWidth: Platform.touchTarget
                implicitHeight: Platform.touchTarget
                onClicked: if (root.birthYear > 1900) root.birthYear--
                background: Rectangle { radius: Platform.radius; color: Platform.surfaceAlt; border.color: Platform.border; border.width: 1 }
                contentItem: Text { text: parent.text; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Text {
                text: root.birthYear
                color: Platform.textPrimary
                font.pixelSize: Platform.fontTitle
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 96
            }
            Button {
                text: TenjinIcons.add
                font.family: TenjinIcons.family
                implicitWidth: Platform.touchTarget
                implicitHeight: Platform.touchTarget
                onClicked: if (root.birthYear < root.thisYear) root.birthYear++
                background: Rectangle { radius: Platform.radius; color: Platform.surfaceAlt; border.color: Platform.border; border.width: 1 }
                contentItem: Text { text: parent.text; color: Platform.textPrimary; font.pixelSize: Platform.fontLarge; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        Button {
            id: continueBtn
            Layout.fillWidth: true
            Layout.leftMargin: Platform.spacingXl
            Layout.rightMargin: Platform.spacingXl
            Layout.bottomMargin: Platform.spacingXl
            implicitHeight: Platform.touchTarget + 8
            text: qsTr("Continue")
            onClicked: {
                // COPPA uses under-13. Compute age conservatively from birth year
                // (assume birthday hasn't occurred yet this year).
                // Band values match AppViewModel::AgeBand_t (1 = under-13, 2 = 13+).
                var age = root.thisYear - root.birthYear - 1
                var band = age < 13 ? 1 : 2
                appVM.setAgeBand(band)
                root.answered(band)
                root.close()
            }
            background: Rectangle { radius: Platform.radius; color: Platform.accent }
            contentItem: Text { text: continueBtn.text; color: Platform.textOnDark; font.pixelSize: Platform.fontBase; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
}

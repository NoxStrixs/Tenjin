import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import TenjinView

// Theme picker: choose Light / Dark / Custom, and when Custom is active, edit
// four anchor colors (accent, background, surface, text) plus a light/dark hint
// that controls how the rest of the palette derives. Colors persist through
// AppViewModel; Platform recomputes the derived tokens live.
ColumnLayout {
    id: root
    spacing: Platform.spacingMd

    // Currently-editing anchor key, or "" when the editor is closed.
    property string editingKey: ""

    function _hexFor(key) {
        if (key === "accent")  return appVM.customAccent
        if (key === "bg")      return appVM.customBg
        if (key === "surface") return appVM.customSurface
        if (key === "text")    return appVM.customText
        if (key === "danger")  return appVM.customDanger
        if (key === "success") return appVM.customSuccess
        if (key === "border")  return appVM.customBorder
        return "#000000"
    }

    // ── Mode selector: Light / Dark / Custom ─────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Platform.spacingSm
        Repeater {
            model: [
                { label: qsTr("Light"),  mode: 0 },
                { label: qsTr("Dark"),   mode: 1 },
                { label: qsTr("Custom"), mode: 2 }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget
                radius: Platform.radius
                readonly property bool sel: appVM.theme === modelData.mode
                color: sel ? Platform.accent : Platform.surfaceAlt
                border.color: sel ? Platform.accent : Platform.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.sel ? Platform.textOnDark : Platform.textPrimary
                    font.pixelSize: Platform.fontBase
                    font.bold: parent.sel
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appVM.setTheme(modelData.mode)
                }
            }
        }
    }

    // ── Custom anchors (only when Custom is active) ──────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        visible: appVM.theme === 2
        spacing: Platform.spacingSm

        // Light/dark hint for derived tints.
        RowLayout {
            Layout.fillWidth: true
            spacing: Platform.spacingMd
            Text {
                Layout.fillWidth: true
                text: qsTr("Derive shades as dark theme")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
            }
            ToggleSwitch {
                checked: appVM.customIsDark
                onToggled: appVM.setCustomIsDark(!appVM.customIsDark)
            }
        }

        Repeater {
            model: [
                { key: "accent",  label: qsTr("Accent") },
                { key: "bg",      label: qsTr("Background") },
                { key: "surface", label: qsTr("Surface") },
                { key: "text",    label: qsTr("Text") },
                { key: "danger",  label: qsTr("Danger") },
                { key: "success", label: qsTr("Success") },
                { key: "border",  label: qsTr("Border") }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget + 8
                radius: Platform.radius
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: Platform.spacingSm; rightMargin: Platform.spacingSm }
                    spacing: Platform.spacingMd
                    // Swatch — tap to open the visual HSV picker.
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 6
                        color: root._hexFor(modelData.key)
                        border.color: Platform.border
                        border.width: 1
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                colorPicker.title = qsTr("Pick %1 colour").arg(modelData.label)
                                colorPicker._editKey = modelData.key
                                colorPicker.initial = root._hexFor(modelData.key)
                                colorPicker.open()
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontBase
                    }
                    // Hex entry
                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: Platform.touchTarget - 6
                        radius: Platform.radius
                        color: Platform.surface
                        border.color: hexInput.activeFocus ? Platform.accent : Platform.border
                        border.width: 1
                        TextInput {
                            id: hexInput
                            anchors { fill: parent; leftMargin: Platform.spacingMd; rightMargin: Platform.spacingMd }
                            verticalAlignment: TextInput.AlignVCenter
                            text: root._hexFor(modelData.key)
                            color: Platform.textPrimary
                            font.pixelSize: Platform.fontBase
                            font.family: Platform.fontMono
                            selectByMouse: true
                            maximumLength: 7
                            onEditingFinished: appVM.setCustomColor(modelData.key, text)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Enter colors as #rrggbb. Other shades are derived automatically.")
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }
    }

    // Shared visual picker. `_editKey` records which colour slot is being
    // edited; on Apply we hand the hex to AppViewModel (which validates and
    // persists it). Converting the picked color to #rrggbb here keeps the
    // C++ side receiving a canonical string.
    ColorPickerPopup {
        id: colorPicker
        property string _editKey: "accent"
        onPicked: function(chosen) {
            function h2(x) { var s = Math.round(x * 255).toString(16); return s.length < 2 ? "0" + s : s }
            var hex = "#" + h2(chosen.r) + h2(chosen.g) + h2(chosen.b)
            appVM.setCustomColor(_editKey, hex)
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import TenjinView

// Mobile media-source chooser: Files / Photos / Camera. Presents the three
// native sources (via SheetPopup, custom-styled per the visual-consistency
// mandate — not a native action sheet), then delegates to
// appVM.pickEntryMedia(source). The result arrives via appVM.entryMediaPicked,
// wired by the caller. Desktop callers should open MediaPickerDialog directly
// instead of this chooser (no photo library / camera).
//
// source ints match DocumentPickerService::MediaSource: 0=Files,1=Photos,2=Camera.
SheetPopup {
    id: chooser
    title: qsTr("Add media")

    // Emitted if the platform has no native picker (pickEntryMedia returned
    // false), so the caller can fall back to the in-app MediaPickerDialog.
    signal nativeUnavailable()

    function _choose(source) {
        chooser.close()
        if (!appVM.pickEntryMedia(source))
            chooser.nativeUnavailable()
    }

    ColumnLayout {
        width: parent.width
        spacing: Platform.spacingMd

        Repeater {
            model: [
                { label: qsTr("Choose a file"),     glyph: TenjinIcons.document,  source: 0 },
                { label: qsTr("Photo library"),     glyph: TenjinIcons.image,     source: 1 },
                { label: qsTr("Take a photo"),      glyph: TenjinIcons.camera,    source: 2 }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Platform.touchTarget + 8
                radius: Platform.radius
                color: rowArea.containsMouse ? Platform.surfaceAlt : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14
                    Text {
                        text: parent.parent.modelData.glyph
                        font.family: TenjinIcons.family
                        font.pixelSize: Platform.fontLarge
                        color: Platform.accent
                    }
                    AppText {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.label
                        font.pixelSize: Platform.fontBase
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chooser._choose(parent.modelData.source)
                }
            }
        }
    }
}

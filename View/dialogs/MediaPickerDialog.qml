import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as LabsPlatform
import TenjinView

// Cross-platform media picker. ContentBlock's previous mediaFileDialog
// (QtQuick.Dialogs.FileDialog) failed on iOS with "no native option"
// because iOS has no platform picker and no Quick fallback. This dialog
// lists media files (image / video / audio) currently in the app's
// Documents folder so the user can pick one via QML.
//
// On iOS, users drop media into Documents via:
//   - Files app: long-press → Copy → paste into Tenjin/Documents.
//   - From another app via the Share Sheet → Save to Files → Tenjin.
//   - AirDrop → "Save to Files" → Tenjin.
// On desktop, they just put files in ~/Documents.
//
// On accept, the dialog calls back with the picked absolute path via
// the `picked(path)` signal so the caller can decide what to do
// (typically appVM.entryVM.importMedia(path) → store the relative
// path in the content block).
ThemedDialog {
    id: root
    title: qsTr("Pick media")
    width: Platform.isMobile ? Math.min(parent ? parent.width - 32 : 480, 480) : 480
    padding: 20

    x: parent ? Math.round((parent.width  - width)  / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    signal picked(string path)

    property var _files: []
    property string _selectedPath: ""

    function _iconForSuffix(s) {
        if (["png","jpg","jpeg","gif","bmp","webp","svg","heic"].indexOf(s) >= 0) return "\uD83D\uDDBC\uFE0F"   // 🖼
        if (["mp4","webm","mkv","mov","m4v"].indexOf(s) >= 0)                     return "\uD83C\uDFAC"          // 🎬
        if (["mp3","wav","ogg","flac","m4a"].indexOf(s) >= 0)                     return "\uD83C\uDFB5"          // 🎵
        return "\uD83D\uDCC4"
    }

    onAboutToShow: {
        _files = appVM.availableMediaFiles()
        _selectedPath = ""
    }

    onAccepted: {
        if (_selectedPath.length > 0) picked(_selectedPath)
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Text {
            Layout.fillWidth: true
            text: qsTr("Pick a media file from your Documents folder.")
            color: Platform.textMuted
            font.pixelSize: Platform.fontSmall
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: appVM.documentsFolder
            color: Platform.textMuted
            font.pixelSize: Platform.fontTiny
            font.family: "monospace"
            elide: Text.ElideMiddle
            wrapMode: Text.NoWrap
        }

        // Desktop only: native file picker. iOS has no usable native
        // QML FileDialog (the old QtQuick.Dialogs.FileDialog logged
        // "no native option"), so we keep the Documents-folder list
        // as the iOS path. On macOS/Windows/Linux this is the way
        // users actually expect to pick a file -- not "drop into
        // Documents then come back here".
        Button {
            Layout.fillWidth: true
            visible: !Platform.isMobile
            text: qsTr("Browse filesystem\u2026")
            onClicked: nativePicker.open()
        }

        LabsPlatform.FileDialog {
            id: nativePicker
            title: qsTr("Choose a media file")
            fileMode: LabsPlatform.FileDialog.OpenFile
            // No nameFilters -- accept any file. The block renderer
            // falls back to the generic "open externally" link for
            // unknown extensions.
            onAccepted: {
                // The existing list rows hand out plain absolute paths
                // (see availableMediaFiles "path" field). Normalise to
                // that so callers don't need a branch.
                var u = nativePicker.file
                var s = (u && u.toString) ? u.toString() : String(u)
                if (s.indexOf("file://") === 0) s = s.substring(7)
                // Windows file URLs are "file:///C:/..." -- strip the
                // leading slash before the drive letter.
                if (s.length > 2 && s.charAt(0) === '/' && s.charAt(2) === ':')
                    s = s.substring(1)
                root._selectedPath = s
                root.picked(s)
                root.accept()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            // When files exist, hug their content height (capped). When
            // empty, reserve enough room for the "No media" message --
            // otherwise the rectangle collapses to ~8px and the dialog
            // shows only the path strip (which is what the screenshot
            // was showing).
            Layout.preferredHeight: filesList.count > 0
                ? Math.min(filesList.contentHeight + 8, 320)
                : 160
            radius: Platform.radius
            color: Platform.bg
            border.color: Platform.border
            border.width: 1

            ListView {
                id: filesList
                anchors { fill: parent; margins: 4 }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: root._files

                delegate: Rectangle {
                    id: fileRow
                    required property var modelData
                    readonly property bool _selected: root._selectedPath === fileRow.modelData.path
                    width: filesList.width
                    height: Platform.touchTarget + 8
                    radius: Platform.radius - 2
                    color: fileRow._selected ? Platform.accent
                         : fileHover.containsMouse ? Platform.surfaceAlt
                                                     : "transparent"
                    Behavior on color { ColorAnimation { duration: Platform.durationFast } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8

                        Text {
                            text: root._iconForSuffix(fileRow.modelData.suffix)
                            font.pixelSize: Platform.fontLarge
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: fileRow.modelData.name
                                color: fileRow._selected ? Platform.textOnDark : Platform.textPrimary
                                font.pixelSize: Platform.fontBase
                                font.bold: fileRow._selected
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                text: fileRow.modelData.modified + "  --  " + fileRow.modelData.sizeStr
                                color: fileRow._selected ? Platform.textOnDark : Platform.textMuted
                                font.pixelSize: Platform.fontSmall
                            }
                        }
                    }
                    MouseArea {
                        id: fileHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._selectedPath = fileRow.modelData.path
                        onDoubleClicked: { root._selectedPath = fileRow.modelData.path; root.accept() }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: filesList.count === 0
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\uD83C\uDFAC"
                        font.pixelSize: 40
                        color: Platform.textMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No media files found.\nDrop one into your Documents folder, then reopen this picker.")
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    standardButtons: root._selectedPath.length > 0 ? (Dialog.Ok | Dialog.Cancel) : Dialog.Cancel
}



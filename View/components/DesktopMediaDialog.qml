import QtQuick
import QtCore
import QtQuick.Dialogs

// Desktop-only native media browser. Lives OUTSIDE the always-bundled module
// set (see _TENJIN_DESKTOP_ONLY_QML in View/CMakeLists.txt) because it imports
// QtQuick.Dialogs, which does not exist on iOS/Android — bundling it there
// makes the static import scanner fail the whole TenjinView module. Hosts load
// it lazily via a Loader guarded with active: !Platform.isMobile.
//
// Emits picked(path) with a plain absolute filesystem path, normalised the
// same way MediaPickerDialog's list rows report paths.
Item {
    id: root

    signal picked(string path)

    function open() { mediaDlg.open() }

    FileDialog {
        id: mediaDlg
        title: qsTr("Choose a media file")
        fileMode: FileDialog.OpenFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        // No nameFilters — accept any file. The block renderer falls back to
        // the generic "open externally" link for unknown extensions.
        onAccepted: {
            var s = selectedFile.toString()
            if (s.indexOf("file://") === 0) s = s.substring(7)
            // Windows file URLs are "file:///C:/..." — strip the leading
            // slash before the drive letter.
            if (s.length > 2 && s.charAt(0) === '/' && s.charAt(2) === ':')
                s = s.substring(1)
            root.picked(s)
        }
    }
}

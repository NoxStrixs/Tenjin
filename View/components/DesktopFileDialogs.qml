import QtQuick
import QtCore
import QtQuick.Dialogs

// Isolates the QtQuick.Dialogs dependency so it is imported ONLY on desktop,
// via a Loader in Main.qml. On iOS the QtQuick.Dialogs module has no native
// backend and importing it at the top of Main.qml made the whole component fail
// to load ("module QtQuick.Dialogs is not installed"). Keeping the import here,
// behind a desktop-only Loader, means mobile never references it.
//
// Exposes openImport()/openExport(); the parent wires the appVM calls.
Item {
    id: root

    // Injected from the parent so this file has no direct appVM dependency.
    signal importAccepted(url file)
    signal exportAccepted(url file)

    function openImport() { importDlg.open() }
    function openExport() { exportDlg.open() }

    FileDialog {
        id: importDlg
        title: qsTr("Import collection")
        fileMode: FileDialog.OpenFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        nameFilters: [qsTr("Tenjin or Anki (*.json *.apkg)"),
                      qsTr("Tenjin export (*.json)"),
                      qsTr("Anki package (*.apkg)"),
                      qsTr("All files (*)")]
        onAccepted: root.importAccepted(selectedFile)
    }

    FileDialog {
        id: exportDlg
        title: qsTr("Export collection")
        fileMode: FileDialog.SaveFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        nameFilters: [qsTr("Tenjin export (*.json)")]
        defaultSuffix: "json"
        onAccepted: root.exportAccepted(selectedFile)
    }
}

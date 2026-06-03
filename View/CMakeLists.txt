# View/CMakeLists.txt
#
# QML module for the application's UI. Files are organised into subdirectories
# by role (Batch 6.3):
#   View/
#   ├── Main.qml                  (root app window)
#   ├── Platform.qml              (singleton — design tokens, theme)
#   ├── components/               (reusable visual primitives)
#   ├── dialogs/                  (modal popups)
#   ├── pages/                    (top-level routable views)
#   ├── panels/                   (page subregions, sidebars, drawers)
#   └── media/                    (conditionally compiled — needs QtMultimedia / QtWebView)
#
# qt_add_qml_module registers each .qml as a QML type under the TenjinView
# URI. Type lookup within the module is by basename, not path — so a file in
# panels/ can still write `TagChip {}` and Qt finds components/TagChip.qml.
#
# ViewModels is no longer a subdirectory of View — it became a top-level
# sibling in Batch 6.2 since the view depends on view models, not the other
# way around.

set_source_files_properties(Platform.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

set(_TENJIN_MEDIA_QML "")
if(MEDIA_SUPPORT)
    list(APPEND _TENJIN_MEDIA_QML media/MediaPlayerView.qml)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND _TENJIN_MEDIA_QML media/WebEmbed.qml)
endif()

# Declaring every module our .qml files import is REQUIRED for static builds

set(_TENJIN_QML_IMPORTS
    QtQuick
    QtQuick.Controls
    QtQuick.Controls.Basic
    QtQuick.Layouts
    QtQuick.Dialogs
    QtQuick.Window
    QtQml
    QtQml.Models
)
if(MEDIA_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtMultimedia)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtWebView)
endif()

qt_add_qml_module(TenjinView
    URI            TenjinView
    VERSION        1.0
    STATIC
    OUTPUT_DIRECTORY  ${CMAKE_BINARY_DIR}/qml/TenjinView
    IMPORT_PATH       ${CMAKE_BINARY_DIR}/qml

    IMPORTS
        ${_TENJIN_QML_IMPORTS}

    QML_FILES
        # ── root ──
        Main.qml
        Platform.qml

        # ── components ──
        components/ActionButton.qml
        components/ChartCard.qml
        components/ContentBlock.qml
        components/FormulaBlock.qml
        components/GridContentView.qml
        components/IconBtn.qml
        components/SearchBox.qml
        components/TagChip.qml
        components/TagFilterPopup.qml

        # ── dialogs ──
        dialogs/AddDeckDialog.qml
        dialogs/AddEntryDialog.qml
        dialogs/AddTagDialog.qml
        dialogs/ConfirmDialog.qml
        dialogs/RenameTagDialog.qml
        dialogs/ThemedDialog.qml

        # ── pages ──
        pages/DeckListPage.qml
        pages/EntryPage.qml
        pages/ReviewPage.qml
        pages/TagsPage.qml

        # ── panels ──
        panels/AnalyticsPanel.qml
        panels/DeckDetailPanel.qml
        panels/DeckListPanel.qml
        panels/EntryDetailView.qml
        panels/EntryListPanel.qml
        panels/MobileDrawer.qml
        panels/Sidebar.qml

        # ── media (conditionally compiled — see top of this file) ──
        ${_TENJIN_MEDIA_QML}
)

target_link_libraries(TenjinView
    PRIVATE  TenjinViewModels
             Qt6::Quick
             Qt6::QuickControls2
             ${TENJIN_MEDIA_COMPONENTS}
             tenjin_warnings
             tenjin_sanitizers
)

# Feature macros:
# PUBLIC so the App target inherits them transitively.
target_compile_definitions(TenjinView
    PUBLIC   ${TENJIN_FEATURE_DEFINITIONS}
)

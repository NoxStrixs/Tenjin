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

# Declaring modules imported inside our .qml files
set(_TENJIN_QML_IMPORTS
    QtQuick
    QtQuick.Controls
    QtQuick.Controls.Basic
    QtQuick.Layouts
    QtQuick.Dialogs
    QtQml
    QtQml.Models
    Qt.labs.platform
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
        dialogs/AddRelationDialog.qml
        dialogs/AddTagDialog.qml
        dialogs/ConfirmDialog.qml
        dialogs/ImportPickerDialog.qml
        dialogs/MediaPickerDialog.qml
        dialogs/RenameTagDialog.qml
        dialogs/ThemedDialog.qml
        # ── pages ──
        pages/DeckListPage.qml
        pages/EntryPage.qml
        pages/ReviewPage.qml
        pages/TagsPage.qml
        pages/HelpPage.qml
        pages/NewsPage.qml
        pages/SettingsPage.qml
        # ── panels ──
        panels/AnalyticsPanel.qml
        panels/DeckDetailPanel.qml
        panels/DeckListPanel.qml
        panels/EntryDetailView.qml
        panels/EntryListPanel.qml
        panels/MobileDrawer.qml
        panels/Sidebar.qml
        # ── media (conditionally compiled) ──
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

target_compile_definitions(TenjinView
    PUBLIC   ${TENJIN_FEATURE_DEFINITIONS}
)

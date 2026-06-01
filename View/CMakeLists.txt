add_subdirectory(ViewModels)

# Files that must be tagged as QML singletons before being passed to
# qt_add_qml_module — set_source_files_properties() must execute in the same
# directory scope as the module declaration.
set_source_files_properties(Platform.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

# Media QML files are added only when their backing Qt module is enabled, so a
# lean build (MEDIA_SUPPORT=OFF / WEBVIEW_SUPPORT=OFF) doesn't try to compile
# QML that imports a module it wasn't linked against.
set(_TENJIN_MEDIA_QML "")
if(MEDIA_SUPPORT)
    list(APPEND _TENJIN_MEDIA_QML MediaPlayerView.qml)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND _TENJIN_MEDIA_QML WebEmbed.qml)
endif()

# Declaring every module our .qml files import is REQUIRED for static builds
# (iOS): it tells qmlimportscanner which backing plugins to link into the
# binary. Without it, modules like QtQuick.Layouts / QtQuick.Controls.Basic are
# dead-stripped and the app fails at runtime with "module ... is not installed"
# → no root objects → silent exit.
#
# NOTE: the IMPORTS keyword takes PLAIN module names evaluated at configure
# time. Generator expressions ($<...>) are NOT evaluated here and would be
# recorded verbatim as bogus module names — so build the list with ordinary
# if() appends instead.
set(_TENJIN_QML_IMPORTS
    QtQuick
    QtQuick.Controls
    QtQuick.Controls.Basic
    QtQuick.Layouts
    QtQuick.Dialogs
    QtQml
    QtQml.Models
)
if(MEDIA_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtMultimedia)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtWebEngine)
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
        Main.qml
        ActionButton.qml
        Sidebar.qml
        Platform.qml
        EntryPage.qml
        EntryDetailView.qml
        EntryListPanel.qml
        TagsPage.qml
        RenameTagDialog.qml
        MobileDrawer.qml
        AnalyticsPanel.qml
        ChartCard.qml
        DeckListPage.qml
        DeckListPanel.qml
        DeckDetailPanel.qml
        ReviewPage.qml
        ContentBlock.qml
        FormulaBlock.qml
        GridContentView.qml
        TagChip.qml
        SearchBox.qml
        ConfirmDialog.qml
        ThemedDialog.qml
        AddTagDialog.qml
        AddEntryDialog.qml
        AddDeckDialog.qml
        IconBtn.qml
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

# Feature macros (TENJIN_MEDIA / TENJIN_WEBVIEW). PUBLIC so the App target, which
# includes AppViewModel.h (it reads TENJIN_WEBVIEW), inherits them transitively.
target_compile_definitions(TenjinView
    PUBLIC   ${TENJIN_FEATURE_DEFINITIONS}
)

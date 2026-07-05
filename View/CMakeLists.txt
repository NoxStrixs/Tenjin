set_source_files_properties(Platform.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(TenjinIcons.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)
set_source_files_properties(LanguageFlags.qml PROPERTIES
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
    QtQuick.Window
    QtQuick.Controls.Basic
    QtQuick.Templates
    QtQuick.Layouts
    QtQuick.Dialogs
    QtQml
    QtQml.Models
)
if(MEDIA_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtMultimedia)
endif()
if(WEBVIEW_SUPPORT)
    list(APPEND _TENJIN_QML_IMPORTS QtWebView)
endif()

# ── Bundled binary resources (icon font, mono font, flag SVGs) ───────────────
# All assets are embedded THROUGH the QML module so their resource initializers
# are force-linked with the STATIC backing target. A detached qt_add_resources()
# has its initializer stripped at static-link time, so the bytes never reach the
# binary even when configure reports the file as found.
#
# Resource paths (RESOURCE_PREFIX defaults to /qt/qml via QTP0001 from
# qt_standard_project_setup(REQUIRES 6.9)):
#   qrc:/qt/qml/TenjinView/fonts/MaterialSymbolsOutlined.ttf
#   qrc:/qt/qml/TenjinView/fonts/JetBrainsMono-Regular.ttf
#   qrc:/qt/qml/TenjinView/fonts/JetBrainsMono-Bold.ttf
#   qrc:/qt/qml/TenjinView/flags/<iso2>.svg
set(_TENJIN_BUNDLED_RESOURCES "")

# Icon font lives at an ABSOLUTE path (fetched by cmake/IconFont.cmake into the
# source tree). Qt 6.8 rejects absolute RESOURCES entries unless the in-resource
# location is given via QT_RESOURCE_ALIAS — set BEFORE qt_add_qml_module().
if(EXISTS "${TENJIN_ICON_FONT_FILE}")
    set_source_files_properties("${TENJIN_ICON_FONT_FILE}" PROPERTIES
        QT_RESOURCE_ALIAS "fonts/MaterialSymbolsOutlined.ttf")
    list(APPEND _TENJIN_BUNDLED_RESOURCES "${TENJIN_ICON_FONT_FILE}")
else()
    message(WARNING
        "Icon font missing at ${TENJIN_ICON_FONT_FILE}. Icons will fall back "
        "to system glyphs. Run cmake configure with network access to fetch it.")
endif()

# Monospace UI font (vendored / fetched into View/fonts/, repo-relative so the
# implicit alias fonts/<name>.ttf is correct without QT_RESOURCE_ALIAS).
foreach(_mono JetBrainsMono-Regular.ttf JetBrainsMono-Bold.ttf)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/fonts/${_mono}")
        list(APPEND _TENJIN_BUNDLED_RESOURCES "fonts/${_mono}")
    else()
        message(WARNING "Mono font missing: View/fonts/${_mono} "
                        "(see View/fonts/README.md).")
    endif()
endforeach()

# Primary UI font: subsetted Noto Sans (Latin+Arabic) + Noto Sans CJK, generated
# at configure time from committed masters (single source of truth; consistent
# glyphs across all platforms/locales). Emitted to the build dir, so each needs
# an explicit in-resource alias fonts/<name>.
include(${CMAKE_SOURCE_DIR}/cmake/GenerateFonts.cmake)
tenjin_generate_ui_fonts(
    "${CMAKE_CURRENT_SOURCE_DIR}/fonts"
    "${CMAKE_BINARY_DIR}/generated/fonts"
    _TENJIN_UI_FONT_FILES)
foreach(_uf ${_TENJIN_UI_FONT_FILES})
    get_filename_component(_uf_name "${_uf}" NAME)
    set_source_files_properties("${_uf}" PROPERTIES
        QT_RESOURCE_ALIAS "fonts/${_uf_name}")
    list(APPEND _TENJIN_BUNDLED_RESOURCES "${_uf}")
endforeach()

# Flag SVGs (lipis/flag-icons, MIT) — only the mapped subset placed in
# View/flags/. Repo-relative; aliased as flags/<iso2>.svg implicitly.
file(GLOB _TENJIN_FLAG_SVGS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
     "${CMAKE_CURRENT_SOURCE_DIR}/flags/*.svg")
list(APPEND _TENJIN_BUNDLED_RESOURCES ${_TENJIN_FLAG_SVGS})

# DesktopFileDialogs.qml imports QtQuick.Dialogs, which does not exist on
# iOS/Android. If it is part of the module there, the static import scanner
# demands the QtQuick.Dialogs plugin, the TenjinView module fails to resolve,
# and EVERY Main.qml import reports "not installed". Bundle it on desktop only;
# Main.qml already guards its Loader with active: !Platform.isMobile.
set(_TENJIN_DESKTOP_ONLY_QML "")
if(NOT ANDROID AND NOT IOS AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    list(APPEND _TENJIN_DESKTOP_ONLY_QML
        components/DesktopFileDialogs.qml
        components/DesktopMediaDialog.qml)
endif()

qt_add_qml_module(TenjinView
    URI            TenjinView
    VERSION        1.0
    STATIC
    OUTPUT_DIRECTORY  ${CMAKE_BINARY_DIR}/qml/TenjinView
    IMPORT_PATH       ${CMAKE_BINARY_DIR}/qml
    IMPORTS
        ${_TENJIN_QML_IMPORTS}
    RESOURCES
        ${_TENJIN_BUNDLED_RESOURCES}
    QML_FILES
        # ── root ──
        Main.qml
        Platform.qml
        TenjinIcons.qml
        LanguageFlags.qml
        # ── components ──
        components/ActionButton.qml
        components/AppText.qml
        components/StyledComboBox.qml
        components/LanguageFlagRow.qml
        components/LoadingState.qml
        components/ErrorState.qml
        components/PressScale.qml
        components/ToggleSwitch.qml
        components/ThemePicker.qml
        components/MediaSourceChooser.qml
        components/SheetPopup.qml
        components/AgeGateDialog.qml
        components/ColorPickerPopup.qml
        components/Stepper.qml
        components/TimePicker.qml
        ${_TENJIN_DESKTOP_ONLY_QML}
        components/ChartCard.qml
        components/ContentBlock.qml
        components/EmptyState.qml
        components/FormulaBlock.qml
        components/GridContentView.qml
        components/IconBtn.qml
        components/SearchBox.qml
        components/SkeletonItem.qml
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
        dialogs/BugReportDialog.qml
        dialogs/WhatsNewSheet.qml
        # ── pages ──
        pages/DeckListPage.qml
        pages/EntryPage.qml
        pages/ReviewPage.qml
        pages/TagsPage.qml
        pages/HelpPage.qml
        pages/NewsPage.qml
        pages/SettingsPage.qml
        pages/StatsPage.qml
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
             Qt6::Svg
             ${TENJIN_MEDIA_COMPONENTS}
             tenjin_warnings
             tenjin_sanitizers
)

target_compile_definitions(TenjinView
    PUBLIC   ${TENJIN_FEATURE_DEFINITIONS}
)

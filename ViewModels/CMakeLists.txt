qt_add_library(TenjinViewModels STATIC
    src/AppViewModel.cpp
    src/ContentBlockModel.cpp
    src/EntryViewModel_Lifecycle.cpp
    src/EntryViewModel_Entry.cpp
    src/EntryViewModel_Content.cpp
    src/EntryViewModel_Media.cpp
    src/EntryViewModel_Search.cpp
    src/EntryViewModel_Tag.cpp
    src/DeckListModel.cpp
    src/DeckViewModel.cpp
    src/SidebarModel.cpp
    src/SidebarViewModel.cpp
    src/ReviewViewModel.cpp
    src/FormulaRenderer.cpp
    src/NotificationService.cpp
    src/CloudService.cpp
    src/HapticsService.cpp

    include/ViewModels/AppViewModel.h
    include/ViewModels/EntryViewModel.h
    include/ViewModels/DeckViewModel.h
    include/ViewModels/ReviewViewModel.h
    include/ViewModels/SidebarViewModel.h
    include/ViewModels/LogViewModel.h
    include/ViewModels/FormulaRenderer.h
    include/ViewModels/NotificationService.h
    include/ViewModels/CloudService.h
    include/ViewModels/HapticsService.h
)

target_include_directories(TenjinViewModels PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_definitions(TenjinViewModels
    PUBLIC ${TENJIN_FEATURE_DEFINITIONS}
)

target_link_libraries(TenjinViewModels
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Network
        EntryService
        DeckService
    PRIVATE
        tenjin_warnings
        tenjin_sanitizers
)

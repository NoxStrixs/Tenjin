qt_add_library(TenjinViewModels STATIC
    # App-level orchestration
    src/AppViewModel.cpp

    # Entry: split by responsibility (was a single 825-line TU prior to Batch 6).
    # Each TU contributes a subset of EntryViewModel's methods; together they
    # form the complete class. The header defines the class once; the .cpp
    # files together define every method.
    src/ContentBlockModel.cpp
    src/EntryViewModel_Lifecycle.cpp
    src/EntryViewModel_Entry.cpp
    src/EntryViewModel_Content.cpp
    src/EntryViewModel_Media.cpp
    src/EntryViewModel_Search.cpp
    src/EntryViewModel_Tag.cpp

    # Deck: model and view model live in separate TUs.
    src/DeckListModel.cpp
    src/DeckViewModel.cpp

    # Sidebar: ditto.
    src/SidebarModel.cpp
    src/SidebarViewModel.cpp

    # Standalone view models (one class per TU already).
    src/ReviewViewModel.cpp
    src/FormulaRenderer.cpp

    # Public headers — listed so IDEs surface them in the project tree.
    include/ViewModels/AppViewModel.h
    include/ViewModels/EntryViewModel.h
    include/ViewModels/DeckViewModel.h
    include/ViewModels/ReviewViewModel.h
    include/ViewModels/SidebarViewModel.h
    include/ViewModels/LogViewModel.h
    include/ViewModels/FormulaRenderer.h
)

target_include_directories(TenjinViewModels PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(TenjinViewModels
    PUBLIC   Qt6::Core
             Qt6::Qml
             Qt6::Network
             EntryService
             DeckService
    PRIVATE  tenjin_warnings
             tenjin_sanitizers
)


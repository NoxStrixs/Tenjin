qt_add_library(TenjinViewModels STATIC
    src/AppViewModel.cpp
    src/WordViewModel.cpp
    src/DeckViewModel.cpp
    src/ReviewViewModel.cpp
    src/SidebarViewModel.cpp

    include/ViewModels/AppViewModel.h
    include/ViewModels/WordViewModel.h
    include/ViewModels/DeckViewModel.h
    include/ViewModels/ReviewViewModel.h
    include/ViewModels/SidebarViewModel.h
    include/ViewModels/LogViewModel.h
)

target_include_directories(TenjinViewModels PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(TenjinViewModels
    PUBLIC   Qt6::Core
             Qt6::Qml
             WordService
             DeckService
    PRIVATE  tenjin_warnings
             tenjin_sanitizers
)

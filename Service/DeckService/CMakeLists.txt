add_library(DeckService STATIC
    src/DeckService.cpp
    include/DeckService/DeckService.h
)

target_include_directories(DeckService PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(DeckService
    PUBLIC  DatabaseManager
    PRIVATE tenjin_warnings
            tenjin_sanitizers
)

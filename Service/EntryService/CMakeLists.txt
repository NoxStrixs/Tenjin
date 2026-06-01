add_library(EntryService STATIC
    src/EntryService.cpp
    include/EntryService/EntryService.h
)

target_include_directories(EntryService PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(EntryService
    PUBLIC  DatabaseManager
    PRIVATE tenjin_warnings
            tenjin_sanitizers
)

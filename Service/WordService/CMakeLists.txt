add_library(WordService STATIC
    src/WordService.cpp
    include/WordService/WordService.h
)

target_include_directories(WordService PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(WordService
    PUBLIC  DatabaseManager
    PRIVATE tenjin_warnings
            tenjin_sanitizers
)

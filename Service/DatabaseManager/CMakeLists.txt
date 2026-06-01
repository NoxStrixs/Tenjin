add_library(DatabaseManager STATIC
    src/DatabaseManager_Database.cpp
    src/DatabaseManager_Entry.cpp
    src/DatabaseManager_Tag.cpp
    src/DatabaseManager_Content.cpp
    src/DatabaseManager_Search.cpp
    src/DatabaseManager_Relation.cpp
    src/DatabaseManager_Deck.cpp
    src/DatabaseManager_Review.cpp
    src/DatabaseManager_ImportExport.cpp
    src/Schema.cpp
    include/DatabaseManager/DatabaseManager.h
    include/DatabaseManager/Types.h
    include/DatabaseManager/Schema.h
)

target_include_directories(DatabaseManager PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(DatabaseManager
    PUBLIC  Qt6::Core
            Qt6::Sql
    PRIVATE tenjin_warnings
            tenjin_sanitizers
)

if(BUILD_TESTS)
    add_subdirectory(tests)
endif()

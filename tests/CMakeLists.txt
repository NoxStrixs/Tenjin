# Test target. Built only when TENJIN_BUILD_TESTS=ON (off by default so the
# app build stays lean). Run with: ctest --test-dir build --output-on-failure
find_package(Qt6 6.8 REQUIRED COMPONENTS Test Core Sql)

qt_add_executable(tenjin_tests
    test_main.cpp
    test_anki_importer.cpp
    test_database_roundtrip.cpp
    test_scheduling.cpp
)

target_link_libraries(tenjin_tests PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::Sql
    DatabaseManager
    EntryService
    miniz
    tenjin_sanitizers
)

target_include_directories(tenjin_tests PRIVATE
    "${CMAKE_SOURCE_DIR}/Service/DatabaseManager/include"
    "${CMAKE_SOURCE_DIR}/Service/EntryService/include"
)

add_test(NAME tenjin_tests COMMAND tenjin_tests)

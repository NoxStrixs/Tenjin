# DatabaseManager unit tests (GoogleTest).
#
# Built only when BUILD_TESTS=ON. Add to the build with:
#   cmake -S . -B build -DBUILD_TESTS=ON && cmake --build build
#   ctest --test-dir build --output-on-failure
#
# Wiring: the parent Service/DatabaseManager/CMakeLists.txt should end with
#   if(BUILD_TESTS)
#       add_subdirectory(tests)
#   endif()

find_package(Qt6 REQUIRED COMPONENTS Sql Core)

# Prefer a system/managed GoogleTest; fall back to fetching a pinned release if
# absent, so the suite builds on a clean machine without manual setup.
find_package(GTest QUIET)
if(NOT GTest_FOUND)
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG        v1.15.2
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)
endif()

add_executable(DatabaseManagerTests
    src/SchemaTest.cpp
    src/Sm2Test.cpp
)

target_link_libraries(DatabaseManagerTests
    PRIVATE
        TenjinDatabaseManager   # the library under test (adjust if the target name differs)
        Qt6::Sql
        Qt6::Core
        GTest::gtest
        GTest::gtest_main
)

# Tests reach the public headers through <DatabaseManager/...>, which the
# linked library target already exposes via its PUBLIC include dirs.

include(GoogleTest)
gtest_discover_tests(DatabaseManagerTests
    PROPERTIES
        # Each test uses its own QTemporaryDir, so they're independent and may
        # run in parallel.
        LABELS "DatabaseManager"
)

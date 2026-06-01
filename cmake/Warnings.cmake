# ─── Warnings ─────────────────────────────────────────────────────────────────
# Interface target carrying our preferred warning set. Apply with
# target_link_libraries(my_target PRIVATE tenjin_warnings).

add_library(tenjin_warnings INTERFACE)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(tenjin_warnings INTERFACE
        -Wall
        -Wextra
        -Wpedantic
        -Wshadow
        -Wnon-virtual-dtor
        -Wold-style-cast
        -Wcast-align
        -Woverloaded-virtual
        -Wnull-dereference
        -Wdouble-promotion
        -Wformat=2
        -Wno-unused-parameter   # noisy on Qt slot stubs and view methods
    )
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    target_compile_options(tenjin_warnings INTERFACE
        /W4
        /permissive-
        /Zc:__cplusplus
    )
endif()

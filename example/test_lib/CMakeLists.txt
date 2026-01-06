# Test Windows static library (.lib)
add_win_lib(test_lib
    SOURCES mathlib.cpp stringlib.cpp
)

# Add header directory so other projects can use it
target_include_directories(test_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Add common settings
target_win_common(test_lib UNICODE RUNTIME MT)

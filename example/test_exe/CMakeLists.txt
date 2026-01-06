# Test Windows console executable
add_win_executable(test_exe CONSOLE
    SOURCES main.cpp
    LIBS kernel32.lib user32.lib
)

# Add common settings: Enable UNICODE, use MT runtime
target_win_common(test_exe UNICODE RUNTIME MT)

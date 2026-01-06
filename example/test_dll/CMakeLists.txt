# Test Windows Dynamic Link Library (DLL)
add_win_dll(test_dll
    SOURCES dllmain.cpp exports.cpp
    DEF_FILE ${CMAKE_CURRENT_SOURCE_DIR}/exports.def
    LIBS kernel32.lib
)

# Add common settings
target_win_common(test_dll UNICODE RUNTIME MT)

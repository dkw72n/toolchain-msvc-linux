# Check if LTO is available
if(LTO_TOOLS_AVAILABLE)
    # Print current global optimization pass config
    message(STATUS "[LTO-Test] Global LTO_OPT_PASSES: ${LTO_OPT_PASSES}")

    # Define OPT_PASSES based on host system
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(OPT_PASSES "-load-pass-plugin ${CMAKE_BINARY_DIR}/plugin/rshit/rshit.dll -passes=rshit")
    else()
        set(OPT_PASSES "-load-pass-plugin $ENV{LLVM_LTO_PATH} -passes=$ENV{LLVM_LTO_PASS}")
    endif()

    add_win_executable_lto(test_exe_lto CONSOLE
        OPT_PASSES "${OPT_PASSES}"
        SOURCES 
            main.cpp 
            helper.cpp
        LIBS 
            kernel32.lib 
            user32.lib
    )

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        add_dependencies(test_exe_lto_lto_objs rshit)
    endif()
else()
    message(STATUS "[LTO-Test] Skipping test_exe_lto - LTO tools not available")
endif()

# Test Windows console executable
add_win_executable(test_exe CONSOLE
    SOURCES main.cpp helper.cpp
    LIBS kernel32.lib user32.lib
)

# Add common settings: Enable UNICODE, use MT runtime
target_win_common(test_exe UNICODE RUNTIME MT)
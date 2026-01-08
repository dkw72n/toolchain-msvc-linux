# Test Windows kernel driver (.sys)
if(LTO_TOOLS_AVAILABLE)
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(OPT_PASSES "-load-pass-plugin ${CMAKE_BINARY_DIR}/plugin/rshit/rshit.dll -passes=rshit")
    else()
        set(OPT_PASSES "-load-pass-plugin $ENV{LLVM_LTO_PATH} -passes=$ENV{LLVM_LTO_PASS}")
    endif()

    add_win_driver_lto(test_driver KMDF
        OPT_PASSES "${OPT_PASSES}"
        SOURCES 
            driver.cpp
            file1.c
        LIBS 
            aux_klib.lib
            ntstrsafe.lib
            wdmsec.lib
            BufferOverflowK.lib
    )
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        # Ensure rshit plugin is built before test_driver
        add_dependencies(test_driver rshit)
    endif()
endif()
# Now $<TARGET_FILE:...> works with LTO targets
add_custom_command(TARGET test_driver
    POST_BUILD
    COMMAND echo Congrats: $<TARGET_FILE:test_driver>
)
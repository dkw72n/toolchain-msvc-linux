# Test Windows kernel driver (.sys)

# OPT_PASSES "-load-pass-plugin ${CMAKE_BINARY_DIR}/plugin/rshit/rshit.dll -passes=rshit"
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    add_win_driver_lto(test_driver KMDF
        OPT_PASSES "-load-pass-plugin ${CMAKE_BINARY_DIR}/plugin/rshit/rshit.dll -passes=rshit"
        SOURCES 
            driver.cpp
            file1.c
        LIBS 
            aux_klib.lib
            ntstrsafe.lib
            wdmsec.lib
            BufferOverflowK.lib
    )
    # Ensure rshit plugin is built before test_driver
    add_dependencies(test_driver rshit)
else()
    add_win_driver_lto(test_driver KMDF
        OPT_PASSES "-load-pass-plugin $ENV{LLVM_LTO_PATH} -passes=$ENV{LLVM_LTO_PASS}"
        SOURCES 
            driver.cpp
            file1.c
        LIBS 
            aux_klib.lib
            ntstrsafe.lib
            wdmsec.lib
            BufferOverflowK.lib
    )
endif()

# Now $<TARGET_FILE:...> works with LTO targets
add_custom_command(TARGET test_driver
    POST_BUILD
    COMMAND echo Congrats: $<TARGET_FILE:test_driver>
)
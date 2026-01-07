# Test Windows kernel driver (.sys)
add_win_driver_lto(test_driver KMDF
    SOURCES 
        driver.cpp
        file1.c
    LIBS 
        aux_klib.lib
        ntstrsafe.lib
        wdmsec.lib
        BufferOverflowK.lib
)

# Now $<TARGET_FILE:...> works with LTO targets
add_custom_command(TARGET test_driver
    POST_BUILD
    COMMAND echo Congrats: $<TARGET_FILE:test_driver>
)
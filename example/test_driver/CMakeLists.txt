# Test Windows kernel driver (.sys)
add_win_driver(test_driver KMDF
    SOURCES 
        driver.cpp
        file1.c
    LIBS 
        aux_klib.lib
        ntstrsafe.lib
        wdmsec.lib
        BufferOverflowK.lib
)

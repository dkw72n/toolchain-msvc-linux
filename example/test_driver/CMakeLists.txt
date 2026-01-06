# Test Windows kernel driver (.sys)
add_win_driver(test_driver WDM
    SOURCES driver.cpp
)

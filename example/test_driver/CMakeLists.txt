# 测试 Windows 内核驱动 (.sys)
add_win_driver(test_driver WDM
    SOURCES driver.cpp
)

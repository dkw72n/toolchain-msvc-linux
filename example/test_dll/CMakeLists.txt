# 测试 Windows 动态链接库 (DLL)
add_win_dll(test_dll
    SOURCES dllmain.cpp exports.cpp
    DEF_FILE ${CMAKE_CURRENT_SOURCE_DIR}/exports.def
    LIBS kernel32.lib
)

# 添加通用设置
target_win_common(test_dll UNICODE RUNTIME MT)

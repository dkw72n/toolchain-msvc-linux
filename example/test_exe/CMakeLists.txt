# 测试 Windows 控制台可执行文件
add_win_executable(test_exe CONSOLE
    SOURCES main.cpp
    LIBS kernel32.lib user32.lib
)

# 添加通用设置: 启用 UNICODE，使用 MT 运行时库
target_win_common(test_exe UNICODE RUNTIME MT)

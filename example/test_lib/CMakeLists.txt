# 测试 Windows 静态库 (.lib)
add_win_lib(test_lib
    SOURCES mathlib.cpp stringlib.cpp
)

# 添加头文件目录，以便其他项目可以使用
target_include_directories(test_lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# 添加通用设置
target_win_common(test_lib UNICODE RUNTIME MT)

cmake_minimum_required(VERSION 3.20)
project(example_project)

# 生成 compile_commands.json 供 VSCode IntelliSense 使用
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 添加子目录
add_subdirectory(example/test_exe)
add_subdirectory(example/test_dll)
add_subdirectory(example/test_lib)
add_subdirectory(example/test_driver)

# LTO 测试 (仅当 LTO 工具可用时)
add_subdirectory(example/test_exe_lto)
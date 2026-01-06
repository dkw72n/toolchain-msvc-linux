cmake_minimum_required(VERSION 3.20)
project(example_project)

# Generate compile_commands.json for VSCode IntelliSense
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Add subdirectories
add_subdirectory(example/test_exe)
add_subdirectory(example/test_dll)
add_subdirectory(example/test_lib)
add_subdirectory(example/test_driver)

# LTO test (only when LTO tools are available)
add_subdirectory(example/test_exe_lto)
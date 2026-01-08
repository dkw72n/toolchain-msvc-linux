cmake_minimum_required(VERSION 3.20)
project(example_project)

# Generate compile_commands.json for VSCode IntelliSense
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 20)

# Add subdirectories
add_subdirectory(example/test_exe)
add_subdirectory(example/test_dll)
add_subdirectory(example/test_lib)
add_subdirectory(example/test_driver)

add_subdirectory(plugin)
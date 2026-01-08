# Only build rshit plugin when the HOST system is Windows
# (not cross-compiling from Linux)
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    add_subdirectory(rshit)
endif()
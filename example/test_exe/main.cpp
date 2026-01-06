/**
 * @file main.cpp
 * @brief Test Windows console executable
 */

#include <Windows.h>
#include <stdio.h>

int main(int argc, char* argv[])
{
    printf("Hello from test_exe!\n");
    printf("This is a Windows console application built with cmake_msvc toolchain.\n");
    
    // Get system information
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);
    
    printf("Processor Architecture: %u\n", sysInfo.wProcessorArchitecture);
    printf("Number of Processors: %u\n", sysInfo.dwNumberOfProcessors);
    printf("Page Size: %u\n", sysInfo.dwPageSize);
    
    return 0;
}

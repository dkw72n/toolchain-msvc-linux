/**
 * @file main.cpp
 * @brief Test Windows console executable built with LTO
 * This file is used to test the add_win_executable_lto function
 * C/C++ source files will be compiled to LLVM bitcode, then merged, optimized and linked */

#include <Windows.h>

// Functions imported from helper.cpp
extern "C" int add_numbers(int a, int b);
extern "C" int multiply_numbers(int a, int b);
extern "C" void print_number(int value);

// Use WriteConsoleA to output text, avoiding the variadic implementation of printf
static void print_string(const char* str)
{
    HANDLE hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hStdOut != INVALID_HANDLE_VALUE)
    {
        DWORD written;
        DWORD len = 0;
        while (str[len] != '\0') len++;
        WriteConsoleA(hStdOut, str, len, &written, NULL);
    }
}

int main(int argc, char* argv[])
{
    print_string("=== LTO Test Executable ===\n");
    print_string("This executable was built using LLVM LTO (Link Time Optimization)\n\n");
    
    // Test cross-translation unit function calls (LTO can inline these functions)
    print_string("Testing cross-translation unit function calls (LTO can inline these):\n");
    
    int a = 10, b = 5;
    
    print_string("  add_numbers(10, 5) = ");
    print_number(add_numbers(a, b));
    print_string("\n");
    
    print_string("  multiply_numbers(10, 5) = ");
    print_number(multiply_numbers(a, b));
    print_string("\n");
    
    // Get system information
    print_string("\nSystem Information:\n");
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);
    
    print_string("  Number of Processors: ");
    print_number((int)sysInfo.dwNumberOfProcessors);
    print_string("\n");
    
    print_string("  Page Size: ");
    print_number((int)sysInfo.dwPageSize);
    print_string("\n");
    
    print_string("\n=== LTO Test Complete ===\n");
    return 0;
}
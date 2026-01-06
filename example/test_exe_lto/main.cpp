/**
 * @file main.cpp
 * @brief 测试 LTO 构建的 Windows 控制台可执行文件
 * 
 * 此文件用于测试 add_win_executable_lto 函数
 * C/C++ 源文件会被编译为 LLVM bitcode，然后合并、优化后链接
 */

#include <Windows.h>

// 从 helper.cpp 导入的函数
extern "C" int add_numbers(int a, int b);
extern "C" int multiply_numbers(int a, int b);
extern "C" void print_number(int value);

// 使用 WriteConsoleA 来输出文本，避免使用 printf 的 variadic 实现
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
    
    // 测试跨编译单元的函数调用（LTO 可以内联这些函数）
    print_string("Testing cross-TU function calls (LTO can inline these):\n");
    
    int a = 10, b = 5;
    
    print_string("  add_numbers(10, 5) = ");
    print_number(add_numbers(a, b));
    print_string("\n");
    
    print_string("  multiply_numbers(10, 5) = ");
    print_number(multiply_numbers(a, b));
    print_string("\n");
    
    // 获取系统信息
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
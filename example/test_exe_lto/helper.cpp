/**
 * @file helper.cpp
 * @brief 辅助函数文件
 * 
 * 此文件包含一些简单的辅助函数，用于测试 LTO 跨编译单元优化
 * 这些函数在 LTO 优化时可能会被内联到调用点
 */

#include <Windows.h>

// 简单的加法函数 - LTO 应该能够内联这个函数
extern "C" int add_numbers(int a, int b)
{
    return a + b;
}

// 简单的乘法函数 - LTO 应该能够内联这个函数
extern "C" int multiply_numbers(int a, int b)
{
    return a * b;
}

// 打印数字函数 - 使用 WriteConsoleA 避免 variadic 函数
extern "C" void print_number(int value)
{
    HANDLE hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hStdOut == INVALID_HANDLE_VALUE) return;
    
    char buffer[16];
    int pos = 0;
    
    // 处理负数
    if (value < 0)
    {
        buffer[pos++] = '-';
        value = -value;
    }
    
    // 处理零
    if (value == 0)
    {
        buffer[pos++] = '0';
    }
    else
    {
        // 转换数字为字符串（反向）
        char temp[16];
        int tempPos = 0;
        while (value > 0)
        {
            temp[tempPos++] = '0' + (value % 10);
            value /= 10;
        }
        // 反转
        while (tempPos > 0)
        {
            buffer[pos++] = temp[--tempPos];
        }
    }
    
    DWORD written;
    WriteConsoleA(hStdOut, buffer, pos, &written, NULL);
}
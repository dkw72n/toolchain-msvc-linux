/**
 * @file helper.cpp
 * @brief Helper functions file
 * This file contains some simple helper functions for testing LTO cross-translation unit optimization
 * These functions may be inlined at the call site during LTO optimization
 */

#include <Windows.h>

// Simple addition function - LTO should be able to inline this function
extern "C" int add_numbers(int a, int b)
{
    return a + b;
}

// Simple multiplication function - LTO should be able to inline this function
extern "C" int multiply_numbers(int a, int b)
{
    return a * b;
}

// Print number function - Use WriteConsoleA to avoid variadic functions
extern "C" void print_number(int value)
{
    HANDLE hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hStdOut == INVALID_HANDLE_VALUE) return;
    
    char buffer[16];
    int pos = 0;
    
    // Handle negative numbers
    if (value < 0)
    {
        buffer[pos++] = '-';
        value = -value;
    }
    
    // Handle zero
    if (value == 0)
    {
        buffer[pos++] = '0';
    }
    else
    {
        // Convert number to string (reversed)
        char temp[16];
        int tempPos = 0;
        while (value > 0)
        {
            temp[tempPos++] = '0' + (value % 10);
            value /= 10;
        }
        // Reverse
        while (tempPos > 0)
        {
            buffer[pos++] = temp[--tempPos];
        }
    }
    
    DWORD written;
    WriteConsoleA(hStdOut, buffer, pos, &written, NULL);
}
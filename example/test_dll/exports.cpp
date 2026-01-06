/**
 * @file exports.cpp
 * @brief DLL export functions implementation
 */

#include <Windows.h>

extern "C" {

/**
 * @brief Sample export function - Add
 */
__declspec(dllexport) int Add(int a, int b)
{
    return a + b;
}

/**
 * @brief Sample export function - Multiply
 */
__declspec(dllexport) int Multiply(int a, int b)
{
    return a * b;
}

/**
 * @brief Sample export function - Get greeting
 */
__declspec(dllexport) const char* GetGreeting()
{
    return "Hello from test_dll!";
}

} // extern "C"

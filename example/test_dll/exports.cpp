/**
 * @file exports.cpp
 * @brief DLL 导出函数实现
 */

#include <Windows.h>

extern "C" {

/**
 * @brief 示例导出函数 - 加法
 */
__declspec(dllexport) int Add(int a, int b)
{
    return a + b;
}

/**
 * @brief 示例导出函数 - 乘法
 */
__declspec(dllexport) int Multiply(int a, int b)
{
    return a * b;
}

/**
 * @brief 示例导出函数 - 获取问候语
 */
__declspec(dllexport) const char* GetGreeting()
{
    return "Hello from test_dll!";
}

} // extern "C"

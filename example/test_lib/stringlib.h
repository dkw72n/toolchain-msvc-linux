/**
 * @file stringlib.h
 * @brief 字符串处理库头文件
 */

#pragma once

namespace stringlib {

/**
 * @brief 获取字符串长度
 */
int strlen(const char* str);

/**
 * @brief 字符串拷贝
 */
char* strcpy(char* dest, const char* src);

/**
 * @brief 字符串比较
 */
int strcmp(const char* str1, const char* str2);

/**
 * @brief 字符串翻转
 */
void strrev(char* str);

} // namespace stringlib

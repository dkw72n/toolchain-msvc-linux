/**
 * @file stringlib.h
 * @brief String processing library header file
 */

#pragma once

namespace stringlib {

/**
 * @brief Get string length
 */
int strlen(const char* str);

/**
 * @brief String copy
 */
char* strcpy(char* dest, const char* src);

/**
 * @brief String compare
 */
int strcmp(const char* str1, const char* str2);

/**
 * @brief String reverse
 */
void strrev(char* str);

} // namespace stringlib

/**
 * @file stringlib.cpp
 * @brief 字符串处理库实现
 */

#include "stringlib.h"

namespace stringlib {

int strlen(const char* str)
{
    if (str == nullptr) return 0;
    
    int len = 0;
    while (*str++)
    {
        len++;
    }
    return len;
}

char* strcpy(char* dest, const char* src)
{
    if (dest == nullptr) return nullptr;
    if (src == nullptr) return dest;
    
    char* ptr = dest;
    while ((*dest++ = *src++))
    {
        // 拷贝直到遇到 null 终止符
    }
    return ptr;
}

int strcmp(const char* str1, const char* str2)
{
    if (str1 == nullptr && str2 == nullptr) return 0;
    if (str1 == nullptr) return -1;
    if (str2 == nullptr) return 1;
    
    while (*str1 && (*str1 == *str2))
    {
        str1++;
        str2++;
    }
    return *(unsigned char*)str1 - *(unsigned char*)str2;
}

void strrev(char* str)
{
    if (str == nullptr) return;
    
    int len = strlen(str);
    if (len <= 1) return;
    
    char* start = str;
    char* end = str + len - 1;
    
    while (start < end)
    {
        char temp = *start;
        *start = *end;
        *end = temp;
        start++;
        end--;
    }
}

} // namespace stringlib

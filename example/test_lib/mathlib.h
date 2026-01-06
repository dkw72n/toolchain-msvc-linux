/**
 * @file mathlib.h
 * @brief 数学库头文件
 */

#pragma once

namespace mathlib {

/**
 * @brief 计算两个整数的最大公约数
 */
int gcd(int a, int b);

/**
 * @brief 计算两个整数的最小公倍数
 */
int lcm(int a, int b);

/**
 * @brief 计算幂运算
 */
long long power(int base, int exp);

/**
 * @brief 判断是否为质数
 */
bool isPrime(int n);

} // namespace mathlib

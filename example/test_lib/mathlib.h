/**
 * @file mathlib.h
 * @brief Math library header file
 */

#pragma once

namespace mathlib {

/**
 * @brief Calculate Greatest Common Divisor (GCD) of two integers
 */
int gcd(int a, int b);

/**
 * @brief Calculate Least Common Multiple (LCM) of two integers
 */
int lcm(int a, int b);

/**
 * @brief Calculate power
 */
long long power(int base, int exp);

/**
 * @brief Check if prime
 */
bool isPrime(int n);

} // namespace mathlib

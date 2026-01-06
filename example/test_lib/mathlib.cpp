/**
 * @file mathlib.cpp
 * @brief Math library implementation
 */

#include "mathlib.h"

namespace mathlib {

int gcd(int a, int b)
{
    if (a < 0) a = -a;
    if (b < 0) b = -b;
    
    while (b != 0)
    {
        int temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

int lcm(int a, int b)
{
    if (a == 0 || b == 0) return 0;
    return (a / gcd(a, b)) * b;
}

long long power(int base, int exp)
{
    if (exp < 0) return 0;
    
    long long result = 1;
    long long b = base;
    
    while (exp > 0)
    {
        if (exp & 1)
        {
            result *= b;
        }
        b *= b;
        exp >>= 1;
    }
    
    return result;
}

bool isPrime(int n)
{
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    
    for (int i = 5; i * i <= n; i += 6)
    {
        if (n % i == 0 || n % (i + 2) == 0)
        {
            return false;
        }
    }
    
    return true;
}

} // namespace mathlib

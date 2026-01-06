/**
 * @file dllmain.cpp
 * @brief DLL 入口点
 */

#include <Windows.h>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        // DLL 被加载到进程
        break;
    case DLL_THREAD_ATTACH:
        // 新线程被创建
        break;
    case DLL_THREAD_DETACH:
        // 线程退出
        break;
    case DLL_PROCESS_DETACH:
        // DLL 被卸载
        break;
    }
    return TRUE;
}

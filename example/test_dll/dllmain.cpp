/**
 * @file dllmain.cpp
 * @brief DLL Entry Point
 */

#include <Windows.h>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        // DLL loaded into process
        break;
    case DLL_THREAD_ATTACH:
        // New thread created
        break;
    case DLL_THREAD_DETACH:
        // Thread exited
        break;
    case DLL_PROCESS_DETACH:
        // DLL unloaded
        break;
    }
    return TRUE;
}

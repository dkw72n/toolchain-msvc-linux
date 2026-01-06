/**
 * @file driver.cpp
 * @brief Windows 内核驱动示例
 */

#include <ntddk.h>

// 驱动卸载例程
extern "C" VOID DriverUnload(PDRIVER_OBJECT DriverObject)
{
    UNREFERENCED_PARAMETER(DriverObject);
    DbgPrint("test_driver: Driver unloaded\n");
}

// 驱动入口点
extern "C" NTSTATUS DriverEntry(
    PDRIVER_OBJECT DriverObject,
    PUNICODE_STRING RegistryPath
)
{
    UNREFERENCED_PARAMETER(RegistryPath);
    
    DbgPrint("test_driver: Driver loaded\n");
    DbgPrint("test_driver: This is a sample WDM kernel driver built with cmake_msvc toolchain\n");
    
    // 设置卸载例程
    DriverObject->DriverUnload = DriverUnload;
    
    return STATUS_SUCCESS;
}

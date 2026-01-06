/**
 * @file driver.cpp
 * @brief Windows Kernel Driver Example
 */

#include <ntddk.h>

// Driver unload routine
extern "C" VOID DriverUnload(PDRIVER_OBJECT DriverObject)
{
    UNREFERENCED_PARAMETER(DriverObject);
    DbgPrint("test_driver: Driver unloaded\n");
}

// Driver entry point
extern "C" NTSTATUS DriverEntry(
    PDRIVER_OBJECT DriverObject,
    PUNICODE_STRING RegistryPath
)
{
    UNREFERENCED_PARAMETER(RegistryPath);
    
    DbgPrint("test_driver: Driver loaded\n");
    DbgPrint("test_driver: This is a sample WDM kernel driver built with cmake_msvc toolchain\n");
    
    // Set unload routine
    DriverObject->DriverUnload = DriverUnload;
    
    return STATUS_SUCCESS;
}

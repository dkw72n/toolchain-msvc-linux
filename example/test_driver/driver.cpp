/**
 * @file driver.cpp
 * @brief Windows Kernel Driver Example
 */

#include <ntddk.h>
#include <aux_klib.h>
#include <ntstrsafe.h>

extern "C" {
    void Greet();
}
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
    char Msg[256];
    RtlStringCbPrintfA(Msg, sizeof(Msg), "[-] BUILD AT %s %s\n", __DATE__, __TIME__);
    DbgPrint(Msg);
    DbgPrint("test_driver: Driver loaded\n");
    DbgPrint("test_driver: This is a sample WDM kernel driver built with cmake_msvc toolchain\n");
    Greet();
    
    // Set unload routine
    DriverObject->DriverUnload = DriverUnload;
    
    return AuxKlibInitialize();;
}

// Force rebuild
/**
 * @file file1.c
 * @brief Example C source file for kernel driver
 */

#include <ntddk.h>
#include <ntstrsafe.h>
#include <wdmsec.h>
#include <wdf.h>
void Greet()
{
    char Msg[256];
    RtlStringCbPrintfA(Msg, sizeof(Msg), "[-] Greet From %s \n", __FILE__);
    DbgPrint(Msg);
    DbgPrint("[-] IoCreateDeviceSecure: %p\n", &IoCreateDeviceSecure);
    DbgPrint("[-] WDF_REL_TIMEOUT_IN_MS(1): %I64d\n", WDF_REL_TIMEOUT_IN_MS(1));
}
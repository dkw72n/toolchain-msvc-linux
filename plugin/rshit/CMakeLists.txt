# =============================================================================
# @file CMakeLists.txt
# @brief LLVM Opt Pass Plugin - rshit
# =============================================================================

# =============================================================================
# Derive LLVM Root from Toolchain's clang-cl Path
# =============================================================================
# The CLANG_CL_PATH variable is set by MSVC_Tools.cmake
# Example: C:/Program Files/LLVM/bin/clang-cl.exe
# We need: C:/Program Files/LLVM

if(NOT CLANG_CL_PATH)
    message(FATAL_ERROR "CLANG_CL_PATH not defined. Ensure the toolchain is configured correctly.")
endif()

# Get the bin directory (parent of clang-cl.exe)
get_filename_component(_LLVM_BIN_DIR "${CLANG_CL_PATH}" DIRECTORY)
# Get the LLVM root directory (parent of bin)
get_filename_component(LLVM_ROOT "${_LLVM_BIN_DIR}" DIRECTORY)

message(STATUS "[rshit] Using LLVM from: ${LLVM_ROOT}")

# =============================================================================
# LLVM Configuration
# =============================================================================
set(LLVM_INCLUDE_DIR "${LLVM_ROOT}/include")
set(LLVM_LIB_DIR "${LLVM_ROOT}/lib")

# Verify LLVM include directory exists
if(NOT EXISTS "${LLVM_INCLUDE_DIR}/llvm/Pass.h")
    message(FATAL_ERROR "LLVM headers not found at ${LLVM_INCLUDE_DIR}. "
                        "Please ensure LLVM development files are installed.")
endif()

# =============================================================================
# Build LLVM Pass Plugin DLL
# =============================================================================
add_win_dll(rshit
    SOURCES 
        rshit.cpp dllmain.c
    DEF_FILE 
        ${CMAKE_CURRENT_SOURCE_DIR}/exports.def
    LIBS 
        ntdll.lib kernel32.lib advapi32.lib
)

# Add LLVM include directories
target_include_directories(rshit PRIVATE "${LLVM_INCLUDE_DIR}")

# Add LLVM library path
target_link_directories(rshit PRIVATE "${LLVM_LIB_DIR}")

# LLVM libraries required for pass plugins (static linking on Windows)
# Note: On Windows with LLVM static libraries, pass plugins must link against
# the same libraries. Library dependencies are ordered to resolve symbols:
# - LLVMCore, LLVMSupport: core LLVM infrastructure
# - LLVMPasses, LLVMTransformUtils, LLVMAnalysis: pass infrastructure
# - LLVMMC, LLVMTarget: target/machine code support
# - LLVMBinaryFormat: provides dwarf::* functions
# - LLVMTargetParser: provides Triple class
# - LLVMRemarks: provides remarks::RemarkStreamer
# - LLVMBitstreamReader: provides BitstreamCursor (required by LLVMRemarks)
# - LLVMDemangle: provides llvm::demangle function
target_link_libraries(rshit PRIVATE
    LLVMCore
    LLVMSupport
    LLVMPasses
    LLVMTransformUtils
    LLVMAnalysis
    LLVMMC
    LLVMTarget
    LLVMBinaryFormat
    LLVMTargetParser
    LLVMRemarks
    LLVMBitstreamReader
    LLVMDemangle
)

# To make this work without building your own llvm:
#   1. download the prebuild LLVM binaries from https://github.com/llvm/llvm-project
#        clang+llvm-21.1.8-x86_64-pc-windows-msvc.tar.xz
#      this alone won't work, coz they built it static linked
#   2. download another prebuild LLVM binaries from https://github.com/c3lang/win-llvm/releases
#      this one is dynamic linked
#   3. replce the offical lib dir with the one from step 2, also replace the opt.exe
#   4. that's it, you can now build rshit
target_win_common(rshit UNICODE RUNTIME MD)

# LLVM requires C++17 for std::optional and other modern C++ features
# target_compile_options(rshit PRIVATE /std:c++17)

# Additional compile definitions for LLVM
target_compile_definitions(rshit PRIVATE
    # Prevent LLVM from using DLL imports (we're building a plugin)
    LLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1
    # Disable MSVC STL version check (allows older Clang with newer MSVC headers)
    _ALLOW_COMPILER_AND_STL_VERSION_MISMATCH
)

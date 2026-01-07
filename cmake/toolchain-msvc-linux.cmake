# =============================================================================
# CMake Toolchain File for MSVC Cross-Compilation on Linux
# =============================================================================
# This (refactored) toolchain file delegates logic to modular files in cmake/modules/
# 
# Usage:
#   cmake -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-msvc-linux.cmake \
#         -DWDKBASE=/path/to/wdk -DMSVCBASE=/path/to/msvc ...
# =============================================================================

# Ensure CMAKE_MODULE_PATH includes our modules directory
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/modules")

# 1. Utilities (Logging, Helper functions)
#    Provides: toolchain_log, check_directory_valid
include(MSVC_Utils)

# 2. Configuration (System Name, Paths, Version Detection)
#    Sets: CMAKE_SYSTEM_NAME, WDKBASE, MSVCBASE, WDKVERSION, Include/Lib Paths
include(MSVC_Config)

# 3. Tools (Compilers, Linkers, LTO Tools)
#    Sets: CMAKE_C_COMPILER, CMAKE_CXX_COMPILER, CMAKE_LINKER, etc.
include(MSVC_Tools)

# 4. VFS Overlay (Case-insensitivity support)
#    Generates: basic vfsoverlay.yaml for case-insensitive header mapping
include(MSVC_VFS)

# 5. Flags (Compiler/Linker definitions)
#    Sets: CMAKE_C_FLAGS_INIT, CMAKE_CXX_FLAGS_INIT, and global compile definitions
include(MSVC_Flags)

# 6. Targets (add_win_executable, add_win_driver, etc.)
#    Provides: add_win_executable, add_win_library, add_win_driver (and LTO variants)
include(MSVC_Targets)

# =============================================================================
# Toolchain Initialization Complete
# =============================================================================
toolchain_log("INFO" "MSVC Toolchain Configured Successfully")

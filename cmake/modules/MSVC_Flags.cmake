# =============================================================================
# Compiler Flags
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Setup Include Flags
# -----------------------------------------------------------------------------

# A) LTO / Custom Command Version (Clean List, No SHELL prefix)
# Used when manually constructing command lines for custom commands
set(MSVC_USER_MODE_INCLUDES_LTO
    "-imsvc" "${MSVC_INCLUDE}"
    "-imsvc" "${WDK_INCLUDE_UCRT}"
    "-imsvc" "${WDK_INCLUDE_SHARED}"
    "-imsvc" "${WDK_INCLUDE_UM}"
)

set(MSVC_KERNEL_MODE_INCLUDES_LTO
    "-imsvc" "${WDK_INCLUDE_KM}"
    "-imsvc" "${WDK_INCLUDE_KMDF}"
    "-imsvc" "${WDK_INCLUDE_SHARED}"
    "-imsvc" "${MSVC_INCLUDE}"
)

# B) Standard Target Version (SHELL prefix)
# Used with target_compile_options to prevent argument de-duplication
set(MSVC_USER_MODE_INCLUDES
    "SHELL:-imsvc \"${MSVC_INCLUDE}\""
    "SHELL:-imsvc \"${WDK_INCLUDE_UCRT}\""
    "SHELL:-imsvc \"${WDK_INCLUDE_SHARED}\""
    "SHELL:-imsvc \"${WDK_INCLUDE_UM}\""
)

set(MSVC_KERNEL_MODE_INCLUDES
    "SHELL:-imsvc \"${WDK_INCLUDE_KM}\""
    "SHELL:-imsvc \"${WDK_INCLUDE_KMDF}\""
    "SHELL:-imsvc \"${WDK_INCLUDE_SHARED}\""
    "SHELL:-imsvc \"${MSVC_INCLUDE}\""
)

# -----------------------------------------------------------------------------
# 2. Setup Include Strings (Quoted for CMAKE_XXX_FLAGS_INIT)
# -----------------------------------------------------------------------------

set(_msvc_inc_q "/imsvc\"${MSVC_INCLUDE}\"")
set(_ucrt_inc_q "/imsvc\"${WDK_INCLUDE_UCRT}\"")
set(_shared_inc_q "/imsvc\"${WDK_INCLUDE_SHARED}\"")
set(_um_inc_q "/imsvc\"${WDK_INCLUDE_UM}\"")

set(_user_mode_inc_list
    "${_msvc_inc_q}"
    "${_ucrt_inc_q}"
    "${_shared_inc_q}"
    "${_um_inc_q}"
)
string(JOIN " " _user_mode_include_str ${_user_mode_inc_list})

# -----------------------------------------------------------------------------
# 3. Common Compile Flags
# -----------------------------------------------------------------------------
# -Wno-msvc-not-found: Suppress warnings about missing MSVC paths
# -ivfsoverlay: Use VFS overlay. With clang-cl, use -Xclang

# LTO Version (Clean list)
set(MSVC_COMMON_COMPILE_FLAGS_LTO
    -Wno-msvc-not-found
    "-Xclang" "-ivfsoverlay" "-Xclang" "${VFSOVERLAY_FILE}"
)

# Standard Version (SHELL prefix)
set(MSVC_COMMON_COMPILE_FLAGS
    -Wno-msvc-not-found
    "SHELL:-Xclang -ivfsoverlay -Xclang \"${VFSOVERLAY_FILE}\""
)

# Initialize standard CMake flags
set(CMAKE_C_FLAGS_INIT "${_user_mode_include_str} -Wno-msvc-not-found")
set(CMAKE_CXX_FLAGS_INIT "${_user_mode_include_str} -Wno-msvc-not-found")

# -----------------------------------------------------------------------------
# 4. Linker Flags
# -----------------------------------------------------------------------------
# Similarly for Lib Paths
set(MSVC_USER_MODE_LINK_PATHS
    "/LIBPATH:${MSVC_LIB}"
    "/LIBPATH:${WDK_LIB_UCRT}"
    "/LIBPATH:${WDK_LIB_UM}"
)

set(MSVC_KERNEL_MODE_LINK_PATHS
    "/LIBPATH:${WDK_LIB_KM}"
)

# Helper for INIT strings (quoted)
set(_msvc_lib_q "\"/LIBPATH:${MSVC_LIB}\"")
set(_ucrt_lib_q "\"/LIBPATH:${WDK_LIB_UCRT}\"")
set(_um_lib_q "\"/LIBPATH:${WDK_LIB_UM}\"")

set(_user_mode_link_list "${_msvc_lib_q}" "${_ucrt_lib_q}" "${_um_lib_q}")
string(JOIN " " _user_mode_link_str ${_user_mode_link_list})

# Initialize standard CMake linker flags
set(CMAKE_EXE_LINKER_FLAGS_INIT "${_user_mode_link_str}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_user_mode_link_str}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_user_mode_link_str}")

# -----------------------------------------------------------------------------
# 5. Kernel Constants
# -----------------------------------------------------------------------------
set(MSVC_KERNEL_MODE_DEFINES
    _AMD64_
    _WIN64
    AMD64
    DEPRECATE_DDK_FUNCTIONS=1
    _KERNEL_MODE
    NTSTRSAFE_LIB
    _NO_CRT_STDIO_INLINE
)

set(MSVC_KERNEL_MODE_COMPILE_OPTIONS
    /X
    /kernel
    /GS-
    /Gy
)

set(MSVC_KERNEL_MODE_LINK_OPTIONS
    "/DRIVER"
    "/SUBSYSTEM:NATIVE"
    "/ENTRY:DriverEntry"
    "/NODEFAULTLIB"
)
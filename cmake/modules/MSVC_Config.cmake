# =============================================================================
# System Configuration
# =============================================================================
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)
set(CMAKE_CROSSCOMPILING TRUE)

# Prevent CMake from adding standard libraries (kernel32.lib, etc.) by default.
# We will handle dependencies explicitly in our add_win_* functions.
set(CMAKE_C_STANDARD_LIBRARIES "" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_LIBRARIES "" CACHE STRING "" FORCE)

# =============================================================================
# Pass Required Variables to try_compile
# =============================================================================
# These variables need to be passed to try_compile() calls during ABI detection
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    WDKBASE
    MSVCBASE
    WDKVERSION
)

# =============================================================================
# Force CMake to use our specified compilers
# =============================================================================
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# =============================================================================
# Validate Required Variables
# =============================================================================

# Check WDKBASE
check_directory_valid(WDKBASE "Windows Driver Kit base path" _wdk_valid)
if(NOT _wdk_valid)
    toolchain_log("ERROR" "WDKBASE must be defined and point to a valid WDK installation directory")
endif()

# Validate WDK structure
if(NOT IS_DIRECTORY "${WDKBASE}/Include" OR NOT IS_DIRECTORY "${WDKBASE}/Lib")
    toolchain_log("ERROR" "WDKBASE appears invalid: missing Include or Lib directories in ${WDKBASE}")
endif()

# Check MSVCBASE
check_directory_valid(MSVCBASE "MSVC base path" _msvc_valid)
if(NOT _msvc_valid)
    toolchain_log("ERROR" "MSVCBASE must be defined and point to a valid MSVC installation directory")
endif()

# Validate MSVC structure
if(NOT IS_DIRECTORY "${MSVCBASE}/include" OR NOT IS_DIRECTORY "${MSVCBASE}/lib")
    toolchain_log("ERROR" "MSVCBASE appears invalid: missing include or lib directories in ${MSVCBASE}")
endif()

toolchain_log("INFO" "WDKBASE: ${WDKBASE}")
toolchain_log("INFO" "MSVCBASE: ${MSVCBASE}")

# =============================================================================
# Detect WDK Version
# =============================================================================

if(DEFINED WDKVERSION AND NOT "${WDKVERSION}" STREQUAL "")
    # User specified version
    set(_wdk_version "${WDKVERSION}")
    set(_wdk_version_source "user-specified")
    
    # Validate the specified version exists
    if(NOT IS_DIRECTORY "${WDKBASE}/Include/${_wdk_version}")
        toolchain_log("ERROR" "Specified WDKVERSION ${_wdk_version} not found in ${WDKBASE}/Include/")
    endif()
else()
    # Auto-detect highest version
    file(GLOB _wdk_version_dirs "${WDKBASE}/Include/10.*")
    
    if(NOT _wdk_version_dirs)
        toolchain_log("ERROR" "No WDK versions found in ${WDKBASE}/Include/")
    endif()
    
    # Sort and get highest version
    list(SORT _wdk_version_dirs COMPARE NATURAL ORDER DESCENDING)
    list(GET _wdk_version_dirs 0 _highest_version_path)
    get_filename_component(_wdk_version "${_highest_version_path}" NAME)
    set(_wdk_version_source "auto-detected from ${WDKBASE}/Include/")
endif()

set(WDKVERSION "${_wdk_version}" CACHE STRING "WDK Version")
toolchain_log("INFO" "WDK Version: ${WDKVERSION} (${_wdk_version_source})")

# =============================================================================
# Include and Library Paths
# =============================================================================

# MSVC paths
set(MSVC_INCLUDE "${MSVCBASE}/include")
set(MSVC_LIB "${MSVCBASE}/lib/x64")

# WDK paths
set(WDK_INCLUDE_UM "${WDKBASE}/Include/${WDKVERSION}/um")
set(WDK_INCLUDE_UCRT "${WDKBASE}/Include/${WDKVERSION}/ucrt")
set(WDK_INCLUDE_SHARED "${WDKBASE}/Include/${WDKVERSION}/shared")
set(WDK_INCLUDE_KM "${WDKBASE}/Include/${WDKVERSION}/km")
set(WDK_INCLUDE_WDF "${WDKBASE}/Include/wdf/umdf/2.0")

set(WDK_LIB_UM "${WDKBASE}/Lib/${WDKVERSION}/um/x64")
set(WDK_LIB_UCRT "${WDKBASE}/Lib/${WDKVERSION}/ucrt/x64")
set(WDK_LIB_KM "${WDKBASE}/Lib/${WDKVERSION}/km/x64")
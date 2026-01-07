# =============================================================================
# CMake Toolchain for Cross-Compiling Windows Programs on Linux
# Using MSVC libraries and clang-cl compiler
# =============================================================================

cmake_minimum_required(VERSION 3.20)

# Prevent multiple inclusions
if(DEFINED _MSVC_LINUX_TOOLCHAIN_LOADED)
    return()
endif()
set(_MSVC_LINUX_TOOLCHAIN_LOADED TRUE)

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
# Without this, CMake's internal try_compile will fail because it won't have
# access to WDKBASE, MSVCBASE, and WDKVERSION
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    WDKBASE
    MSVCBASE
    WDKVERSION
)

# =============================================================================
# Force CMake to use our specified compilers
# =============================================================================
# This prevents CMake from auto-detecting and using MSVC's cl.exe
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# =============================================================================
# Helper Functions
# =============================================================================

# Log message with prefix
function(toolchain_log level message)
    if(level STREQUAL "ERROR")
        message(FATAL_ERROR "[MSVC-Toolchain] ${message}")
    elseif(level STREQUAL "WARNING")
        message(WARNING "[MSVC-Toolchain] ${message}")
    else()
        message(STATUS "[MSVC-Toolchain] ${message}")
    endif()
endfunction()

# Check if directory exists and is valid
function(check_directory_valid path description result_var)
    if(NOT DEFINED ${path} OR "${${path}}" STREQUAL "")
        set(${result_var} FALSE PARENT_SCOPE)
        toolchain_log("ERROR" "${description} (${path}) is not defined")
        return()
    endif()
    
    if(NOT IS_DIRECTORY "${${path}}")
        set(${result_var} FALSE PARENT_SCOPE)
        toolchain_log("ERROR" "${description} path does not exist: ${${path}}")
        return()
    endif()
    
    set(${result_var} TRUE PARENT_SCOPE)
endfunction()

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
# Find clang-cl Compiler
# =============================================================================

function(find_clang_cl result_var)
    # First try: plain clang-cl
    find_program(_clang_cl_path clang-cl)
    if(_clang_cl_path)
        set(${result_var} "${_clang_cl_path}" PARENT_SCOPE)
        toolchain_log("INFO" "Found clang-cl: ${_clang_cl_path}")
        return()
    endif()
    
    # Second try: versioned clang-cl (e.g., clang-cl-19, clang-cl-18, etc.)
    foreach(_version RANGE 20 10 -1)
        find_program(_clang_cl_versioned "clang-cl-${_version}")
        if(_clang_cl_versioned)
            set(${result_var} "${_clang_cl_versioned}" PARENT_SCOPE)
            toolchain_log("INFO" "Found versioned clang-cl: ${_clang_cl_versioned}")
            return()
        endif()
    endforeach()
    
    # Not found
    set(${result_var} "" PARENT_SCOPE)
endfunction()

find_clang_cl(CLANG_CL_PATH)
if(NOT CLANG_CL_PATH)
    toolchain_log("ERROR" "Could not find clang-cl or any versioned variant (clang-cl-XX) in PATH")
endif()

# Find lld-link
find_program(LLD_LINK_PATH lld-link)
if(NOT LLD_LINK_PATH)
    # Try versioned
    foreach(_version RANGE 20 10 -1)
        find_program(LLD_LINK_PATH "lld-link-${_version}")
        if(LLD_LINK_PATH)
            break()
        endif()
    endforeach()
endif()

if(NOT LLD_LINK_PATH)
    toolchain_log("ERROR" "Could not find lld-link in PATH")
endif()
toolchain_log("INFO" "Found lld-link: ${LLD_LINK_PATH}")

# Find llvm-lib
find_program(LLVM_LIB_PATH llvm-lib)
if(NOT LLVM_LIB_PATH)
    foreach(_version RANGE 20 10 -1)
        find_program(LLVM_LIB_PATH "llvm-lib-${_version}")
        if(LLVM_LIB_PATH)
            break()
        endif()
    endforeach()
endif()

if(NOT LLVM_LIB_PATH)
    toolchain_log("ERROR" "Could not find llvm-lib in PATH")
endif()
toolchain_log("INFO" "Found llvm-lib: ${LLVM_LIB_PATH}")

# =============================================================================
# Find LTO Tools (Optional)
# =============================================================================
# These tools are optional. If not found, LTO functions will not be available.

set(LTO_TOOLS_AVAILABLE TRUE)

# Find llvm-link (for merging bitcode files)
find_program(LLVM_LINK_PATH llvm-link)
if(NOT LLVM_LINK_PATH)
    foreach(_version RANGE 20 10 -1)
        find_program(LLVM_LINK_PATH "llvm-link-${_version}")
        if(LLVM_LINK_PATH)
            break()
        endif()
    endforeach()
endif()

if(LLVM_LINK_PATH)
    toolchain_log("INFO" "Found llvm-link: ${LLVM_LINK_PATH}")
else()
    toolchain_log("WARNING" "llvm-link not found, LTO features will be disabled")
    set(LTO_TOOLS_AVAILABLE FALSE)
endif()

# Find opt (for LLVM IR optimization)
find_program(LLVM_OPT_PATH opt)
if(NOT LLVM_OPT_PATH)
    foreach(_version RANGE 20 10 -1)
        find_program(LLVM_OPT_PATH "opt-${_version}")
        if(LLVM_OPT_PATH)
            break()
        endif()
    endforeach()
endif()

if(LLVM_OPT_PATH)
    toolchain_log("INFO" "Found opt: ${LLVM_OPT_PATH}")
else()
    toolchain_log("WARNING" "opt not found, LTO features will be disabled")
    set(LTO_TOOLS_AVAILABLE FALSE)
endif()

# Find llc (for compiling optimized bitcode to object)
find_program(LLVM_LLC_PATH llc)
if(NOT LLVM_LLC_PATH)
    foreach(_version RANGE 20 10 -1)
        find_program(LLVM_LLC_PATH "llc-${_version}")
        if(LLVM_LLC_PATH)
            break()
        endif()
    endforeach()
endif()

if(LLVM_LLC_PATH)
    toolchain_log("INFO" "Found llc: ${LLVM_LLC_PATH}")
else()
    toolchain_log("WARNING" "llc not found, LTO features will be disabled")
    set(LTO_TOOLS_AVAILABLE FALSE)
endif()

# Cache LTO availability
set(LTO_TOOLS_AVAILABLE ${LTO_TOOLS_AVAILABLE} CACHE BOOL "Whether LTO tools are available" FORCE)

# =============================================================================
# Set Compilers and Tools
# =============================================================================

set(CMAKE_C_COMPILER "${CLANG_CL_PATH}")
set(CMAKE_CXX_COMPILER "${CLANG_CL_PATH}")
set(CMAKE_LINKER "${LLD_LINK_PATH}")
set(CMAKE_AR "${LLVM_LIB_PATH}")
set(CMAKE_C_COMPILER_TARGET "x86_64-pc-windows-msvc")
set(CMAKE_CXX_COMPILER_TARGET "x86_64-pc-windows-msvc")

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

# =============================================================================
# VFS Overlay Map Generation for Case-Insensitive Header Resolution
# =============================================================================

set(VFSOVERLAY_FILE "${CMAKE_BINARY_DIR}/vfsoverlay.yaml")

function(generate_case_mapping input_dir output_list)
    set(_mappings "")
    
    file(GLOB_RECURSE _all_files "${input_dir}/*")
    foreach(_file ${_all_files})
        get_filename_component(_filename "${_file}" NAME)
        string(TOLOWER "${_filename}" _lower_filename)
        
        # Only add mapping if case differs
        if(NOT "${_filename}" STREQUAL "${_lower_filename}")
            get_filename_component(_dir "${_file}" DIRECTORY)
            string(APPEND _mappings "      - name: '${_lower_filename}'\n        type: file\n        external-contents: '${_file}'\n")
        endif()
    endforeach()
    
    set(${output_list} "${_mappings}" PARENT_SCOPE)
endfunction()

function(generate_vfsoverlay)
    toolchain_log("INFO" "Generating VFS overlay map for case-insensitive header resolution...")
    
    set(_vfs_content "{\n  'version': 0,\n  'case-sensitive': 'false',\n  'roots': [\n")
    
    # Process MSVC include directory
    if(IS_DIRECTORY "${MSVC_INCLUDE}")
        file(GLOB_RECURSE _msvc_headers "${MSVC_INCLUDE}/*")
        set(_msvc_entries "")
        foreach(_header ${_msvc_headers})
            get_filename_component(_filename "${_header}" NAME)
            string(TOLOWER "${_filename}" _lower_filename)
            if(NOT "${_filename}" STREQUAL "${_lower_filename}")
                get_filename_component(_dir "${_header}" DIRECTORY)
                string(APPEND _msvc_entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
            endif()
        endforeach()
        
        if(_msvc_entries)
            string(APPEND _vfs_content "    {\n      'name': '${MSVC_INCLUDE}',\n      'type': 'directory',\n      'contents': [\n${_msvc_entries}      ]\n    },\n")
        endif()
    endif()
    
    # Process WDK include directories
    foreach(_wdk_dir ${WDK_INCLUDE_UM} ${WDK_INCLUDE_UCRT} ${WDK_INCLUDE_SHARED} ${WDK_INCLUDE_KM})
        if(IS_DIRECTORY "${_wdk_dir}")
            file(GLOB_RECURSE _wdk_headers "${_wdk_dir}/*")
            set(_wdk_entries "")
            foreach(_header ${_wdk_headers})
                get_filename_component(_filename "${_header}" NAME)
                string(TOLOWER "${_filename}" _lower_filename)
                if(NOT "${_filename}" STREQUAL "${_lower_filename}")
                    string(APPEND _wdk_entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                endif()
            endforeach()
            
            if(_wdk_entries)
                string(APPEND _vfs_content "    {\n      'name': '${_wdk_dir}',\n      'type': 'directory',\n      'contents': [\n${_wdk_entries}      ]\n    },\n")
            endif()
        endif()
    endforeach()
    
    string(APPEND _vfs_content "  ]\n}\n")
    
    # Only write the file if content has changed to avoid triggering CMake re-runs
    set(_write_file TRUE)
    if(EXISTS "${VFSOVERLAY_FILE}")
        file(READ "${VFSOVERLAY_FILE}" _existing_content)
        if("${_existing_content}" STREQUAL "${_vfs_content}")
            set(_write_file FALSE)
            toolchain_log("INFO" "VFS overlay map unchanged: ${VFSOVERLAY_FILE}")
        endif()
    endif()

    if(_write_file)
        file(WRITE "${VFSOVERLAY_FILE}" "${_vfs_content}")
        toolchain_log("INFO" "VFS overlay map generated: ${VFSOVERLAY_FILE}")
    endif()
endfunction()

# Generate VFS overlay at configure time
generate_vfsoverlay()

# =============================================================================
# Compiler Flags
# =============================================================================

# Use /imsvc with proper quoting for paths with spaces
set(_common_includes
    "/imsvc\"${MSVC_INCLUDE}\""
    "/imsvc\"${WDK_INCLUDE_UCRT}\""
    "/imsvc\"${WDK_INCLUDE_SHARED}\""
    "/imsvc\"${WDK_INCLUDE_UM}\""
)

string(JOIN " " _include_flags ${_common_includes})

set(CMAKE_C_FLAGS_INIT "${_include_flags} -Wno-msvc-not-found")
set(CMAKE_CXX_FLAGS_INIT "${_include_flags} -Wno-msvc-not-found")

# Linker flags - use quoted paths for spaces
set(_common_link_dirs
    "\"/LIBPATH:${MSVC_LIB}\""
    "\"/LIBPATH:${WDK_LIB_UCRT}\""
    "\"/LIBPATH:${WDK_LIB_UM}\""
)
string(JOIN " " _link_flags ${_common_link_dirs})

set(CMAKE_EXE_LINKER_FLAGS_INIT "${_link_flags}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_link_flags}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_link_flags}")

# =============================================================================
# Custom Target Functions
# =============================================================================

# Add a Windows executable
function(add_win_executable target_name)
    set(options WIN32 CONSOLE)
    set(oneValueArgs SUBSYSTEM)
    set(multiValueArgs SOURCES LIBS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    add_executable(${target_name} ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Set subsystem
    if(ARG_WIN32)
        set(_subsystem "WINDOWS")
    elseif(ARG_CONSOLE)
        set(_subsystem "CONSOLE")
    elseif(ARG_SUBSYSTEM)
        set(_subsystem "${ARG_SUBSYSTEM}")
    else()
        set(_subsystem "CONSOLE")
    endif()
    
    target_link_options(${target_name} PRIVATE "/SUBSYSTEM:${_subsystem}")
    
    # Link libraries
    if(ARG_LIBS)
        target_link_libraries(${target_name} PRIVATE ${ARG_LIBS})
    endif()
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows executable: ${target_name} (Subsystem: ${_subsystem})")
endfunction()

# Add a Windows DLL
function(add_win_dll target_name)
    set(options "")
    set(oneValueArgs DEF_FILE)
    set(multiValueArgs SOURCES LIBS EXPORTS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    add_library(${target_name} SHARED ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Set DLL-specific options
    target_link_options(${target_name} PRIVATE "/DLL")
    
    # Use DEF file if provided
    if(ARG_DEF_FILE)
        target_link_options(${target_name} PRIVATE "/DEF:${ARG_DEF_FILE}")
    endif()
    
    # Export symbols
    if(ARG_EXPORTS)
        foreach(_export ${ARG_EXPORTS})
            target_link_options(${target_name} PRIVATE "/EXPORT:${_export}")
        endforeach()
    endif()
    
    # Link libraries
    if(ARG_LIBS)
        target_link_libraries(${target_name} PRIVATE ${ARG_LIBS})
    endif()
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows DLL: ${target_name}")
endfunction()

# Add a Windows static library
function(add_win_lib target_name)
    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    add_library(${target_name} STATIC ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows static library: ${target_name}")
endfunction()

# Add a Windows kernel driver (SYS)
function(add_win_driver target_name)
    set(options WDM KMDF)
    set(oneValueArgs KMDF_VERSION)
    set(multiValueArgs SOURCES LIBS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    add_library(${target_name} SHARED ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Kernel mode include paths
    # Note: Order matters! KM headers should be searched first to avoid
    # accidentally including user-mode headers (e.g., ucrt's stdio.h)
    target_include_directories(${target_name} BEFORE PRIVATE
        "${WDK_INCLUDE_KM}"
        "${WDK_INCLUDE_SHARED}"
        "${MSVC_INCLUDE}"
    )
    
    # Kernel mode compiler definitions
    # NTSTRSAFE_LIB: Use kernel-mode safe string functions from ntstrsafe.lib
    #                This prevents ntstrsafe.h from using user-mode CRT functions
    target_compile_definitions(${target_name} PRIVATE
        _AMD64_
        _WIN64
        AMD64
        DEPRECATE_DDK_FUNCTIONS=1
        _KERNEL_MODE
        NTSTRSAFE_LIB
    )
    
    # Kernel mode compile options
    # Note: We explicitly add kernel-mode include paths here because the global
    # CMAKE_C_FLAGS already includes UCRT paths. By adding these with BEFORE,
    # clang will search these paths first and find kernel-mode headers.
    target_compile_options(${target_name} BEFORE PRIVATE
        # Kernel-specific system include paths - must come BEFORE any UCRT paths
        "/imsvc${WDK_INCLUDE_KM}"
        "/imsvc${WDK_INCLUDE_SHARED}"
        "/imsvc${MSVC_INCLUDE}"
    )
    
    target_compile_options(${target_name} PRIVATE
        /kernel
        /GS-
        /Gy
    )
    
    # Kernel mode linker options
    target_link_options(${target_name} PRIVATE
        "/DRIVER"
        "/SUBSYSTEM:NATIVE"
        "/ENTRY:DriverEntry"
        "/NODEFAULTLIB"
    )
    
    # Add kernel library path using link_directories for proper quoting
    target_link_directories(${target_name} PRIVATE "${WDK_LIB_KM}")
    
    # KMDF support
    if(ARG_KMDF)
        set(_kmdf_version "${ARG_KMDF_VERSION}")
        if(NOT _kmdf_version)
            set(_kmdf_version "1.15")
        endif()
        
        target_include_directories(${target_name} PRIVATE
            "${WDKBASE}/Include/wdf/kmdf/${_kmdf_version}"
        )
        target_link_libraries(${target_name} PRIVATE
            WdfLdr.lib
            WdfDriverEntry.lib
        )
        target_compile_definitions(${target_name} PRIVATE
            KMDF_VERSION_MAJOR=1
        )
    endif()
    
    # Basic kernel libraries
    target_link_libraries(${target_name} PRIVATE
        ntoskrnl.lib
        hal.lib
        wmilib.lib
        BufferOverflowK.lib
    )
    
    # Additional libraries
    if(ARG_LIBS)
        target_link_libraries(${target_name} PRIVATE ${ARG_LIBS})
    endif()
    
    # Set output extension to .sys
    set_target_properties(${target_name} PROPERTIES
        SUFFIX ".sys"
        PREFIX ""
        # Clear default libraries to avoid linking user-mode libs (kernel32, etc.)
        C_STANDARD_LIBRARIES ""
        CXX_STANDARD_LIBRARIES ""
    )
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows kernel driver: ${target_name}")
endfunction()

# =============================================================================
# Helper function to configure target with common settings
# =============================================================================

function(target_win_common target_name)
    set(options UNICODE)
    set(oneValueArgs RUNTIME)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Unicode support
    if(ARG_UNICODE)
        target_compile_definitions(${target_name} PRIVATE UNICODE _UNICODE)
    endif()
    
    # Runtime library
    if(ARG_RUNTIME)
        if(ARG_RUNTIME STREQUAL "MT")
            target_compile_options(${target_name} PRIVATE /MT)
        elseif(ARG_RUNTIME STREQUAL "MTd")
            target_compile_options(${target_name} PRIVATE /MTd)
        elseif(ARG_RUNTIME STREQUAL "MD")
            target_compile_options(${target_name} PRIVATE /MD)
        elseif(ARG_RUNTIME STREQUAL "MDd")
            target_compile_options(${target_name} PRIVATE /MDd)
        endif()
    endif()
endfunction()

# =============================================================================
# LLVM Bitcode LTO Support
# =============================================================================
# This section provides functions to:
# 1. Compile C/C++ sources to LLVM bitcode (.bc) instead of object files
# 2. Merge bitcode files using llvm-link
# 3. Optimize merged bitcode using opt
# 4. Compile optimized bitcode to object using llc
# 5. Link with other object files (e.g., from assembly)

# Enable LTO mode - compile C/C++ to bitcode
option(ENABLE_LTO_BITCODE "Compile C/C++ sources to LLVM bitcode for LTO" OFF)

# Default optimization passes for opt
set(LTO_OPT_PASSES "-O2" CACHE STRING "Optimization passes for opt command")

# Helper function to get source file extension type
function(_get_source_type source_file result_var)
    get_filename_component(_ext "${source_file}" EXT)
    string(TOLOWER "${_ext}" _ext_lower)
    
    if(_ext_lower MATCHES "\\.(c|cpp|cxx|cc|c\\+\\+)$")
        set(${result_var} "C_CXX" PARENT_SCOPE)
    elseif(_ext_lower MATCHES "\\.(asm|s|S)$")
        set(${result_var} "ASM" PARENT_SCOPE)
    else()
        set(${result_var} "OTHER" PARENT_SCOPE)
    endif()
endfunction()

# Function to add custom compile rules for bitcode generation
# This creates .bc files from C/C++ sources
function(_add_bitcode_compile_rules target_name source_files bc_output_list obj_output_list)
    set(_bc_files "")
    set(_obj_files "")
    
    # Get target's compile definitions, include directories, and compile options
    get_target_property(_target_defs ${target_name} COMPILE_DEFINITIONS)
    get_target_property(_target_includes ${target_name} INCLUDE_DIRECTORIES)
    get_target_property(_target_options ${target_name} COMPILE_OPTIONS)
    
    if(NOT _target_defs)
        set(_target_defs "")
    endif()
    if(NOT _target_includes)
        set(_target_includes "")
    endif()
    if(NOT _target_options)
        set(_target_options "")
    endif()
    
    # Build compile flags
    set(_compile_flags "")
    foreach(_def ${_target_defs})
        list(APPEND _compile_flags "-D${_def}")
    endforeach()
    foreach(_inc ${_target_includes})
        list(APPEND _compile_flags "-I${_inc}")
    endforeach()
    foreach(_opt ${_target_options})
        list(APPEND _compile_flags "${_opt}")
    endforeach()
    
    # Get the output directory
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    foreach(_source ${source_files})
        _get_source_type("${_source}" _source_type)
        
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        
        if(_source_type STREQUAL "C_CXX")
            # C/C++ source - compile to bitcode
            set(_bc_file "${_bc_dir}/${_source_name}.bc")
            
            # Determine if C or C++
            get_filename_component(_ext "${_source}" EXT)
            string(TOLOWER "${_ext}" _ext_lower)
            if(_ext_lower STREQUAL ".c")
                set(_lang_flag "/TC")
            else()
                set(_lang_flag "/TP")
            endif()
            
            add_custom_command(
                OUTPUT "${_bc_file}"
                COMMAND ${CMAKE_C_COMPILER}
                    ${_lang_flag}
                    -emit-llvm
                    -c
                    ${CMAKE_C_FLAGS}
                    ${_compile_flags}
                    -o "${_bc_file}"
                    "${_source_abs}"
                DEPENDS "${_source_abs}"
                COMMENT "Compiling ${_source_name} to LLVM bitcode"
                VERBATIM
            )
            
            list(APPEND _bc_files "${_bc_file}")
        elseif(_source_type STREQUAL "ASM")
            # Assembly source - compile to object directly
            set(_obj_file "${_bc_dir}/${_source_name}.obj")
            
            add_custom_command(
                OUTPUT "${_obj_file}"
                COMMAND ${CMAKE_ASM_COMPILER}
                    -c
                    -o "${_obj_file}"
                    "${_source_abs}"
                DEPENDS "${_source_abs}"
                COMMENT "Assembling ${_source_name}"
                VERBATIM
            )
            
            list(APPEND _obj_files "${_obj_file}")
        endif()
    endforeach()
    
    set(${bc_output_list} "${_bc_files}" PARENT_SCOPE)
    set(${obj_output_list} "${_obj_files}" PARENT_SCOPE)
endfunction()

# Function to merge, optimize, and compile bitcode files
# Returns the final object file path
function(_lto_merge_and_optimize target_name bc_files output_obj_var)
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    set(_merged_bc "${_bc_dir}/${target_name}_merged.bc")
    set(_optimized_bc "${_bc_dir}/${target_name}_optimized.bc")
    set(_final_obj "${_bc_dir}/${target_name}_lto.obj")
    
    # Step 1: Merge all bitcode files using llvm-link
    add_custom_command(
        OUTPUT "${_merged_bc}"
        COMMAND ${LLVM_LINK_PATH}
            -o "${_merged_bc}"
            ${bc_files}
        DEPENDS ${bc_files}
        COMMENT "Merging bitcode files for ${target_name}"
        VERBATIM
    )
    
    # Step 2: Optimize merged bitcode using opt
    separate_arguments(_lto_opt_passes_list NATIVE_COMMAND "${LTO_OPT_PASSES}")
    add_custom_command(
        OUTPUT "${_optimized_bc}"
        COMMAND ${LLVM_OPT_PATH}
            ${_lto_opt_passes_list}
            -o "${_optimized_bc}"
            "${_merged_bc}"
        DEPENDS "${_merged_bc}"
        COMMENT "Optimizing bitcode for ${target_name}"
        VERBATIM
    )
    
    # Step 3: Compile optimized bitcode to object using llc
    add_custom_command(
        OUTPUT "${_final_obj}"
        COMMAND ${LLVM_LLC_PATH}
            -filetype=obj
            -mtriple=x86_64-pc-windows-msvc
            -o "${_final_obj}"
            "${_optimized_bc}"
        DEPENDS "${_optimized_bc}"
        COMMENT "Compiling optimized bitcode to object for ${target_name}"
        VERBATIM
    )
    
    set(${output_obj_var} "${_final_obj}" PARENT_SCOPE)
endfunction()

# =============================================================================
# LTO-enabled Target Functions
# =============================================================================

# Helper macro to check LTO availability
macro(_check_lto_available)
    if(NOT LTO_TOOLS_AVAILABLE)
        toolchain_log("ERROR" "LTO functions require llvm-link, opt, and llc tools. Please install LLVM tools or use non-LTO functions.")
    endif()
endmacro()

# Add a Windows executable with LTO support
# Compiles C/C++ to bitcode, merges, optimizes, then links with other objects
# 
# Parameters:
#   target_name     - Name of the target
#   WIN32/CONSOLE   - Subsystem type (optional, default: CONSOLE)
#   SUBSYSTEM       - Custom subsystem string (optional)
#   SOURCES         - C/C++ source files
#   ASM_SOURCES     - Assembly source files (optional)
#   LIBS            - Libraries to link (optional)
#   OPT_PASSES      - Custom opt passes for this target (optional, default: ${LTO_OPT_PASSES})
#                     Examples: "-O3", "--passes='default<O3>'", "-O2 --time-passes"
#
function(add_win_executable_lto target_name)
    _check_lto_available()
    
    set(options WIN32 CONSOLE)
    set(oneValueArgs SUBSYSTEM OPT_PASSES)
    set(multiValueArgs SOURCES ASM_SOURCES LIBS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Collect all sources
    set(_all_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    set(_asm_sources ${ARG_ASM_SOURCES})
    
    # Create a helper target for compilation tracking
    set(_helper_target "${target_name}_bc_helper")
    
    # First, create a dummy interface library to hold compile properties
    add_library(${_helper_target} INTERFACE)
    
    # Set subsystem
    if(ARG_WIN32)
        set(_subsystem "WINDOWS")
    elseif(ARG_CONSOLE)
        set(_subsystem "CONSOLE")
    elseif(ARG_SUBSYSTEM)
        set(_subsystem "${ARG_SUBSYSTEM}")
    else()
        set(_subsystem "CONSOLE")
    endif()
    
    # Get output directory
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    # Separate C/C++ and ASM sources
    set(_cc_sources "")
    set(_asm_sources_from_main "")
    foreach(_source ${_all_sources})
        _get_source_type("${_source}" _source_type)
        if(_source_type STREQUAL "C_CXX")
            list(APPEND _cc_sources "${_source}")
        elseif(_source_type STREQUAL "ASM")
            list(APPEND _asm_sources_from_main "${_source}")
        endif()
    endforeach()
    
    # Add explicit ASM sources
    list(APPEND _asm_sources_from_main ${_asm_sources})
    
    # Compile C/C++ sources to bitcode
    set(_bc_files "")
    
    # Build include flags from global include paths (same as CMAKE_C_FLAGS_INIT)
    # For custom commands, we need to explicitly include these paths
    set(_include_flags
        "/imsvc${MSVC_INCLUDE}"
        "/imsvc${WDK_INCLUDE_UCRT}"
        "/imsvc${WDK_INCLUDE_SHARED}"
        "/imsvc${WDK_INCLUDE_UM}"
    )
    
    # Combine with CMAKE_C_FLAGS and add VFS overlay for case-insensitive headers
    set(_common_compile_flags ${_include_flags} -Wno-msvc-not-found "-ivfsoverlay${VFSOVERLAY_FILE}")
    
    # Append any user-specified CMAKE_C_FLAGS
    if(CMAKE_C_FLAGS)
        separate_arguments(_user_c_flags NATIVE_COMMAND "${CMAKE_C_FLAGS}")
        list(APPEND _common_compile_flags ${_user_c_flags})
    endif()
    
    foreach(_source ${_cc_sources})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_bc_file "${_bc_dir}/${_source_name}.bc")
        
        # Determine if C or C++
        get_filename_component(_ext "${_source}" EXT)
        string(TOLOWER "${_ext}" _ext_lower)
        if(_ext_lower STREQUAL ".c")
            set(_lang_flag "/TC")
        else()
            set(_lang_flag "/TP")
        endif()
        
        # clang-cl needs special handling for bitcode output:
        # Use -Xclang to pass -emit-llvm and /Fo for output file
        add_custom_command(
            OUTPUT "${_bc_file}"
            COMMAND ${CMAKE_C_COMPILER}
                ${_lang_flag}
                /c
                -Xclang -emit-llvm
                ${_common_compile_flags}
                "/Fo${_bc_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Compiling ${_source_name} to LLVM bitcode"
            VERBATIM
        )
        
        list(APPEND _bc_files "${_bc_file}")
    endforeach()
    
    # Assemble ASM sources to object files
    set(_asm_obj_files "")
    foreach(_source ${_asm_sources_from_main})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_obj_file "${_bc_dir}/${_source_name}.obj")
        
        add_custom_command(
            OUTPUT "${_obj_file}"
            COMMAND ${CMAKE_ASM_COMPILER}
                /c
                "/Fo${_obj_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Assembling ${_source_name}"
            VERBATIM
        )
        
        list(APPEND _asm_obj_files "${_obj_file}")
    endforeach()
    
    # Determine opt passes to use (target-specific or global default)
    if(ARG_OPT_PASSES)
        set(_opt_passes "${ARG_OPT_PASSES}")
    else()
        set(_opt_passes "${LTO_OPT_PASSES}")
    endif()
    
    separate_arguments(_opt_passes_list NATIVE_COMMAND "${_opt_passes}")

    # Merge and optimize bitcode if we have any
    set(_lto_obj "")
    if(_bc_files)
        set(_merged_bc "${_bc_dir}/${target_name}_merged.bc")
        set(_optimized_bc "${_bc_dir}/${target_name}_optimized.bc")
        set(_lto_obj "${_bc_dir}/${target_name}_lto.obj")
        
        # Merge bitcode files
        add_custom_command(
            OUTPUT "${_merged_bc}"
            COMMAND ${LLVM_LINK_PATH}
                -o "${_merged_bc}"
                ${_bc_files}
            DEPENDS ${_bc_files}
            COMMENT "Merging bitcode files for ${target_name}"
            VERBATIM
        )
        
        # Optimize merged bitcode (using target-specific or global opt passes)
        add_custom_command(
            OUTPUT "${_optimized_bc}"
            COMMAND ${LLVM_OPT_PATH}
                ${_opt_passes_list}
                -o "${_optimized_bc}"
                "${_merged_bc}"
            DEPENDS "${_merged_bc}"
            COMMENT "Optimizing bitcode for ${target_name} (passes: ${_opt_passes})"
            VERBATIM
        )
        
        # Compile to object
        add_custom_command(
            OUTPUT "${_lto_obj}"
            COMMAND ${LLVM_LLC_PATH}
                -filetype=obj
                -mtriple=x86_64-pc-windows-msvc
                -o "${_lto_obj}"
                "${_optimized_bc}"
            DEPENDS "${_optimized_bc}"
            COMMENT "Compiling optimized bitcode to object for ${target_name}"
            VERBATIM
        )
    endif()
    
    # Collect all object files
    set(_all_obj_files "")
    if(_lto_obj)
        list(APPEND _all_obj_files "${_lto_obj}")
    endif()
    list(APPEND _all_obj_files ${_asm_obj_files})
    
    # Create final executable using link command
    set(_output_exe "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.exe")
    
    # Build library flags
    set(_lib_flags "")
    if(ARG_LIBS)
        foreach(_lib ${ARG_LIBS})
            list(APPEND _lib_flags "${_lib}")
        endforeach()
    endif()
    
    # Build linker library path flags separately for proper handling
    set(_linker_libpath_flags
        "/LIBPATH:${MSVC_LIB}"
        "/LIBPATH:${WDK_LIB_UCRT}"
        "/LIBPATH:${WDK_LIB_UM}"
    )
    
    add_custom_command(
        OUTPUT "${_output_exe}"
        COMMAND ${CMAKE_LINKER}
            "/OUT:${_output_exe}"
            "/SUBSYSTEM:${_subsystem}"
            "/machine:x64"
            ${_linker_libpath_flags}
            ${_all_obj_files}
            ${_lib_flags}
        DEPENDS ${_all_obj_files}
        COMMENT "Linking ${target_name}"
        VERBATIM
    )
    
    # Create custom target
    add_custom_target(${target_name} ALL DEPENDS "${_output_exe}")
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows LTO executable: ${target_name} (Subsystem: ${_subsystem})")
endfunction()

# Add a Windows DLL with LTO support
# 
# Parameters:
#   target_name     - Name of the target
#   DEF_FILE        - Module definition file (optional)
#   SOURCES         - C/C++ source files
#   ASM_SOURCES     - Assembly source files (optional)
#   LIBS            - Libraries to link (optional)
#   EXPORTS         - Symbols to export (optional)
#   OPT_PASSES      - Custom opt passes for this target (optional, default: ${LTO_OPT_PASSES})
#
function(add_win_dll_lto target_name)
    _check_lto_available()
    
    set(options "")
    set(oneValueArgs DEF_FILE OPT_PASSES)
    set(multiValueArgs SOURCES ASM_SOURCES LIBS EXPORTS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Collect all sources
    set(_all_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    set(_asm_sources ${ARG_ASM_SOURCES})
    
    # Get output directory
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    # Separate C/C++ and ASM sources
    set(_cc_sources "")
    set(_asm_sources_from_main "")
    foreach(_source ${_all_sources})
        _get_source_type("${_source}" _source_type)
        if(_source_type STREQUAL "C_CXX")
            list(APPEND _cc_sources "${_source}")
        elseif(_source_type STREQUAL "ASM")
            list(APPEND _asm_sources_from_main "${_source}")
        endif()
    endforeach()
    
    # Add explicit ASM sources
    list(APPEND _asm_sources_from_main ${_asm_sources})
    
    # Compile C/C++ sources to bitcode
    set(_bc_files "")
    
    # Build include flags from global include paths (same as CMAKE_C_FLAGS_INIT)
    # For custom commands, we need to explicitly include these paths
    set(_include_flags
        "/imsvc${MSVC_INCLUDE}"
        "/imsvc${WDK_INCLUDE_UCRT}"
        "/imsvc${WDK_INCLUDE_SHARED}"
        "/imsvc${WDK_INCLUDE_UM}"
    )
    
    # Combine with CMAKE_C_FLAGS and add VFS overlay for case-insensitive headers
    set(_common_compile_flags ${_include_flags} -Wno-msvc-not-found "-ivfsoverlay${VFSOVERLAY_FILE}")
    
    # Append any user-specified CMAKE_C_FLAGS
    if(CMAKE_C_FLAGS)
        separate_arguments(_user_c_flags NATIVE_COMMAND "${CMAKE_C_FLAGS}")
        list(APPEND _common_compile_flags ${_user_c_flags})
    endif()
    
    foreach(_source ${_cc_sources})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_bc_file "${_bc_dir}/${_source_name}.bc")
        
        # Determine if C or C++
        get_filename_component(_ext "${_source}" EXT)
        string(TOLOWER "${_ext}" _ext_lower)
        if(_ext_lower STREQUAL ".c")
            set(_lang_flag "/TC")
        else()
            set(_lang_flag "/TP")
        endif()
        
        add_custom_command(
            OUTPUT "${_bc_file}"
            COMMAND ${CMAKE_C_COMPILER}
                ${_lang_flag}
                -emit-llvm
                -c
                ${_common_compile_flags}
                -o "${_bc_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Compiling ${_source_name} to LLVM bitcode"
            VERBATIM
        )
        
        list(APPEND _bc_files "${_bc_file}")
    endforeach()
    
    # Assemble ASM sources to object files
    set(_asm_obj_files "")
    foreach(_source ${_asm_sources_from_main})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_obj_file "${_bc_dir}/${_source_name}.obj")
        
        add_custom_command(
            OUTPUT "${_obj_file}"
            COMMAND ${CMAKE_ASM_COMPILER}
                -c
                -o "${_obj_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Assembling ${_source_name}"
            VERBATIM
        )
        
        list(APPEND _asm_obj_files "${_obj_file}")
    endforeach()
    
    # Determine opt passes to use (target-specific or global default)
    if(ARG_OPT_PASSES)
        set(_opt_passes "${ARG_OPT_PASSES}")
    else()
        set(_opt_passes "${LTO_OPT_PASSES}")
    endif()
    
    separate_arguments(_opt_passes_list NATIVE_COMMAND "${_opt_passes}")

    # Merge and optimize bitcode if we have any
    set(_lto_obj "")
    if(_bc_files)
        set(_merged_bc "${_bc_dir}/${target_name}_merged.bc")
        set(_optimized_bc "${_bc_dir}/${target_name}_optimized.bc")
        set(_lto_obj "${_bc_dir}/${target_name}_lto.obj")
        
        # Merge bitcode files
        add_custom_command(
            OUTPUT "${_merged_bc}"
            COMMAND ${LLVM_LINK_PATH}
                -o "${_merged_bc}"
                ${_bc_files}
            DEPENDS ${_bc_files}
            COMMENT "Merging bitcode files for ${target_name}"
            VERBATIM
        )
        
        # Optimize merged bitcode (using target-specific or global opt passes)
        add_custom_command(
            OUTPUT "${_optimized_bc}"
            COMMAND ${LLVM_OPT_PATH}
                ${_opt_passes_list}
                -o "${_optimized_bc}"
                "${_merged_bc}"
            DEPENDS "${_merged_bc}"
            COMMENT "Optimizing bitcode for ${target_name} (passes: ${_opt_passes})"
            VERBATIM
        )
        
        # Compile to object
        add_custom_command(
            OUTPUT "${_lto_obj}"
            COMMAND ${LLVM_LLC_PATH}
                -filetype=obj
                -mtriple=x86_64-pc-windows-msvc
                -o "${_lto_obj}"
                "${_optimized_bc}"
            DEPENDS "${_optimized_bc}"
            COMMENT "Compiling optimized bitcode to object for ${target_name}"
            VERBATIM
        )
    endif()
    
    # Collect all object files
    set(_all_obj_files "")
    if(_lto_obj)
        list(APPEND _all_obj_files "${_lto_obj}")
    endif()
    list(APPEND _all_obj_files ${_asm_obj_files})
    
    # Create final DLL
    set(_output_dll "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.dll")
    set(_output_lib "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.lib")
    
    # Build link flags
    set(_link_flags "/DLL")
    
    if(ARG_DEF_FILE)
        get_filename_component(_def_abs "${ARG_DEF_FILE}" ABSOLUTE)
        set(_link_flags "${_link_flags} /DEF:${_def_abs}")
    endif()
    
    if(ARG_EXPORTS)
        foreach(_export ${ARG_EXPORTS})
            set(_link_flags "${_link_flags} /EXPORT:${_export}")
        endforeach()
    endif()
    
    # Build library flags
    set(_lib_flags "")
    if(ARG_LIBS)
        foreach(_lib ${ARG_LIBS})
            list(APPEND _lib_flags "${_lib}")
        endforeach()
    endif()
    
    add_custom_command(
        OUTPUT "${_output_dll}" "${_output_lib}"
        COMMAND ${CMAKE_LINKER}
            "/OUT:${_output_dll}"
            "/IMPLIB:${_output_lib}"
            ${_link_flags}
            ${CMAKE_SHARED_LINKER_FLAGS}
            ${_all_obj_files}
            ${_lib_flags}
        DEPENDS ${_all_obj_files}
        COMMENT "Linking ${target_name}"
        VERBATIM
    )
    
    # Create custom target
    add_custom_target(${target_name} ALL DEPENDS "${_output_dll}")
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows LTO DLL: ${target_name}")
endfunction()

# Add a Windows static library with LTO support (stores bitcode)
function(add_win_lib_lto target_name)
    _check_lto_available()
    
    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs SOURCES ASM_SOURCES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Collect all sources
    set(_all_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    set(_asm_sources ${ARG_ASM_SOURCES})
    
    # Get output directory
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    # Separate C/C++ and ASM sources
    set(_cc_sources "")
    set(_asm_sources_from_main "")
    foreach(_source ${_all_sources})
        _get_source_type("${_source}" _source_type)
        if(_source_type STREQUAL "C_CXX")
            list(APPEND _cc_sources "${_source}")
        elseif(_source_type STREQUAL "ASM")
            list(APPEND _asm_sources_from_main "${_source}")
        endif()
    endforeach()
    
    # Add explicit ASM sources
    list(APPEND _asm_sources_from_main ${_asm_sources})
    
    # Compile C/C++ sources to bitcode
    set(_bc_files "")
    
    # Build include flags from global include paths (same as CMAKE_C_FLAGS_INIT)
    # For custom commands, we need to explicitly include these paths
    set(_include_flags
        "/imsvc${MSVC_INCLUDE}"
        "/imsvc${WDK_INCLUDE_UCRT}"
        "/imsvc${WDK_INCLUDE_SHARED}"
        "/imsvc${WDK_INCLUDE_UM}"
    )
    
    # Combine with CMAKE_C_FLAGS and add VFS overlay for case-insensitive headers
    set(_common_compile_flags ${_include_flags} -Wno-msvc-not-found "-ivfsoverlay${VFSOVERLAY_FILE}")
    
    # Append any user-specified CMAKE_C_FLAGS
    if(CMAKE_C_FLAGS)
        separate_arguments(_user_c_flags NATIVE_COMMAND "${CMAKE_C_FLAGS}")
        list(APPEND _common_compile_flags ${_user_c_flags})
    endif()
    
    foreach(_source ${_cc_sources})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_bc_file "${_bc_dir}/${_source_name}.bc")
        
        # Determine if C or C++
        get_filename_component(_ext "${_source}" EXT)
        string(TOLOWER "${_ext}" _ext_lower)
        if(_ext_lower STREQUAL ".c")
            set(_lang_flag "/TC")
        else()
            set(_lang_flag "/TP")
        endif()
        
        add_custom_command(
            OUTPUT "${_bc_file}"
            COMMAND ${CMAKE_C_COMPILER}
                ${_lang_flag}
                -emit-llvm
                -c
                ${_common_compile_flags}
                -o "${_bc_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Compiling ${_source_name} to LLVM bitcode"
            VERBATIM
        )
        
        list(APPEND _bc_files "${_bc_file}")
    endforeach()
    
    # Assemble ASM sources to object files
    set(_asm_obj_files "")
    foreach(_source ${_asm_sources_from_main})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_obj_file "${_bc_dir}/${_source_name}.obj")
        
        add_custom_command(
            OUTPUT "${_obj_file}"
            COMMAND ${CMAKE_ASM_COMPILER}
                -c
                -o "${_obj_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Assembling ${_source_name}"
            VERBATIM
        )
        
        list(APPEND _asm_obj_files "${_obj_file}")
    endforeach()
    
    # For static library, we create a merged bitcode archive
    # This allows LTO at final link time
    set(_output_lib "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.lib")
    set(_output_bc "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.bc")
    
    # Merge bitcode files
    if(_bc_files)
        add_custom_command(
            OUTPUT "${_output_bc}"
            COMMAND ${LLVM_LINK_PATH}
                -o "${_output_bc}"
                ${_bc_files}
            DEPENDS ${_bc_files}
            COMMENT "Merging bitcode files for ${target_name}"
            VERBATIM
        )
    endif()
    
    # Create static library from ASM objects only (bitcode is kept separate)
    if(_asm_obj_files)
        add_custom_command(
            OUTPUT "${_output_lib}"
            COMMAND ${CMAKE_AR}
                "/OUT:${_output_lib}"
                ${_asm_obj_files}
            DEPENDS ${_asm_obj_files}
            COMMENT "Creating static library ${target_name}"
            VERBATIM
        )
    else()
        # Create empty marker file if no ASM sources
        add_custom_command(
            OUTPUT "${_output_lib}"
            COMMAND ${CMAKE_COMMAND} -E touch "${_output_lib}"
            COMMENT "Creating placeholder for ${target_name}"
            VERBATIM
        )
    endif()
    
    # Create custom target
    set(_all_outputs "${_output_lib}")
    if(_bc_files)
        list(APPEND _all_outputs "${_output_bc}")
    endif()
    
    add_custom_target(${target_name} ALL DEPENDS ${_all_outputs})
    
    # Store bitcode file path as target property for linking
    set_target_properties(${target_name} PROPERTIES
        LTO_BITCODE_FILE "${_output_bc}"
        LTO_LIBRARY_FILE "${_output_lib}"
    )
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows LTO static library: ${target_name}")
endfunction()

# Add a Windows kernel driver with LTO support
# 
# Parameters:
#   target_name     - Name of the target
#   WDM/KMDF        - Driver type (optional)
#   KMDF_VERSION    - KMDF version (optional, default: 1.15)
#   SOURCES         - C/C++ source files
#   ASM_SOURCES     - Assembly source files (optional)
#   LIBS            - Libraries to link (optional)
#   OPT_PASSES      - Custom opt passes for this target (optional, default: ${LTO_OPT_PASSES})
#
function(add_win_driver_lto target_name)
    _check_lto_available()
    
    set(options WDM KMDF)
    set(oneValueArgs KMDF_VERSION OPT_PASSES)
    set(multiValueArgs SOURCES ASM_SOURCES LIBS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Collect all sources
    set(_all_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    set(_asm_sources ${ARG_ASM_SOURCES})
    
    # Get output directory
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    # Build kernel mode compile flags
    set(_km_compile_flags
        "/kernel"
        "/GS-"
        "/Gy"
        "-D_AMD64_"
        "-D_WIN64"
        "-DAMD64"
        "-DDEPRECATE_DDK_FUNCTIONS=1"
        "-D_KERNEL_MODE"
        "-I${WDK_INCLUDE_KM}"
        "-I${WDK_INCLUDE_SHARED}"
    )
    
    # KMDF support flags
    if(ARG_KMDF)
        set(_kmdf_version "${ARG_KMDF_VERSION}")
        if(NOT _kmdf_version)
            set(_kmdf_version "1.15")
        endif()
        list(APPEND _km_compile_flags
            "-I${WDKBASE}/Include/wdf/kmdf/${_kmdf_version}"
            "-DKMDF_VERSION_MAJOR=1"
        )
    endif()
    
    # Separate C/C++ and ASM sources
    set(_cc_sources "")
    set(_asm_sources_from_main "")
    foreach(_source ${_all_sources})
        _get_source_type("${_source}" _source_type)
        if(_source_type STREQUAL "C_CXX")
            list(APPEND _cc_sources "${_source}")
        elseif(_source_type STREQUAL "ASM")
            list(APPEND _asm_sources_from_main "${_source}")
        endif()
    endforeach()
    
    # Add explicit ASM sources
    list(APPEND _asm_sources_from_main ${_asm_sources})
    
    # Compile C/C++ sources to bitcode
    set(_bc_files "")
    
    # Build kernel mode include flags
    # Kernel mode needs MSVC headers but NOT ucrt/um (user mode) headers
    set(_km_include_flags
        "/imsvc${MSVC_INCLUDE}"
    )
    
    # Combine with VFS overlay for case-insensitive headers
    set(_common_compile_flags ${_km_include_flags} -Wno-msvc-not-found "-ivfsoverlay${VFSOVERLAY_FILE}")
    
    # Append any user-specified CMAKE_C_FLAGS (but be careful with user mode paths)
    # Note: CMAKE_C_FLAGS may contain user mode include paths, so we don't blindly include them
    
    foreach(_source ${_cc_sources})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_bc_file "${_bc_dir}/${_source_name}.bc")
        
        # Determine if C or C++
        get_filename_component(_ext "${_source}" EXT)
        string(TOLOWER "${_ext}" _ext_lower)
        if(_ext_lower STREQUAL ".c")
            set(_lang_flag "/TC")
        else()
            set(_lang_flag "/TP")
        endif()
        
        add_custom_command(
            OUTPUT "${_bc_file}"
            COMMAND ${CMAKE_C_COMPILER}
                ${_lang_flag}
                -emit-llvm
                -c
                ${_common_compile_flags}
                ${_km_compile_flags}
                -o "${_bc_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Compiling ${_source_name} to LLVM bitcode (kernel mode)"
            VERBATIM
        )
        
        list(APPEND _bc_files "${_bc_file}")
    endforeach()
    
    # Assemble ASM sources to object files
    set(_asm_obj_files "")
    foreach(_source ${_asm_sources_from_main})
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        set(_obj_file "${_bc_dir}/${_source_name}.obj")
        
        add_custom_command(
            OUTPUT "${_obj_file}"
            COMMAND ${CMAKE_ASM_COMPILER}
                -c
                -o "${_obj_file}"
                "${_source_abs}"
            DEPENDS "${_source_abs}"
            COMMENT "Assembling ${_source_name}"
            VERBATIM
        )
        
        list(APPEND _asm_obj_files "${_obj_file}")
    endforeach()
    
    # Determine opt passes to use (target-specific or global default)
    if(ARG_OPT_PASSES)
        set(_opt_passes "${ARG_OPT_PASSES}")
    else()
        set(_opt_passes "${LTO_OPT_PASSES}")
    endif()
    
    separate_arguments(_opt_passes_list NATIVE_COMMAND "${_opt_passes}")

    # Merge and optimize bitcode if we have any
    set(_lto_obj "")
    if(_bc_files)
        set(_merged_bc "${_bc_dir}/${target_name}_merged.bc")
        set(_optimized_bc "${_bc_dir}/${target_name}_optimized.bc")
        set(_lto_obj "${_bc_dir}/${target_name}_lto.obj")
        
        # Merge bitcode files
        add_custom_command(
            OUTPUT "${_merged_bc}"
            COMMAND ${LLVM_LINK_PATH}
                -o "${_merged_bc}"
                ${_bc_files}
            DEPENDS ${_bc_files}
            COMMENT "Merging bitcode files for ${target_name}"
            VERBATIM
        )
        
        # Optimize merged bitcode (using target-specific or global opt passes)
        add_custom_command(
            OUTPUT "${_optimized_bc}"
            COMMAND ${LLVM_OPT_PATH}
                ${_opt_passes_list}
                -o "${_optimized_bc}"
                "${_merged_bc}"
            DEPENDS "${_merged_bc}"
            COMMENT "Optimizing bitcode for ${target_name} (passes: ${_opt_passes})"
            VERBATIM
        )
        
        # Compile to object
        add_custom_command(
            OUTPUT "${_lto_obj}"
            COMMAND ${LLVM_LLC_PATH}
                -filetype=obj
                -mtriple=x86_64-pc-windows-msvc
                -o "${_lto_obj}"
                "${_optimized_bc}"
            DEPENDS "${_optimized_bc}"
            COMMENT "Compiling optimized bitcode to object for ${target_name}"
            VERBATIM
        )
    endif()
    
    # Collect all object files
    set(_all_obj_files "")
    if(_lto_obj)
        list(APPEND _all_obj_files "${_lto_obj}")
    endif()
    list(APPEND _all_obj_files ${_asm_obj_files})
    
    # Create final driver
    set(_output_sys "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.sys")
    
    # Build kernel link flags
    set(_km_link_flags
        "/DRIVER"
        "/SUBSYSTEM:NATIVE"
        "/ENTRY:DriverEntry"
        "/NODEFAULTLIB"
        "/LIBPATH:${WDK_LIB_KM}"
    )
    
    # Build library flags
    set(_lib_flags "ntoskrnl.lib" "hal.lib" "wmilib.lib")
    
    if(ARG_KMDF)
        list(APPEND _lib_flags "WdfLdr.lib" "WdfDriverEntry.lib")
    endif()
    
    if(ARG_LIBS)
        foreach(_lib ${ARG_LIBS})
            list(APPEND _lib_flags "${_lib}")
        endforeach()
    endif()
    
    add_custom_command(
        OUTPUT "${_output_sys}"
        COMMAND ${CMAKE_LINKER}
            "/OUT:${_output_sys}"
            ${_km_link_flags}
            ${CMAKE_SHARED_LINKER_FLAGS}
            ${_all_obj_files}
            ${_lib_flags}
        DEPENDS ${_all_obj_files}
        COMMENT "Linking ${target_name}"
        VERBATIM
    )
    
    # Create custom target
    add_custom_target(${target_name} ALL DEPENDS "${_output_sys}")
    
    # Add VFS overlay as dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    
    toolchain_log("INFO" "Added Windows LTO kernel driver: ${target_name}")
endfunction()

# =============================================================================
# Summary
# =============================================================================

toolchain_log("INFO" "========================================")
toolchain_log("INFO" "MSVC Linux Cross-Compile Toolchain Loaded")
toolchain_log("INFO" "========================================")
toolchain_log("INFO" "Compiler: ${CLANG_CL_PATH}")
toolchain_log("INFO" "Linker: ${LLD_LINK_PATH}")
toolchain_log("INFO" "Archiver: ${LLVM_LIB_PATH}")
toolchain_log("INFO" "MSVC: ${MSVCBASE}")
toolchain_log("INFO" "WDK: ${WDKBASE} (${WDKVERSION})")
toolchain_log("INFO" "VFS Overlay: ${VFSOVERLAY_FILE}")
if(LTO_TOOLS_AVAILABLE)
    toolchain_log("INFO" "LTO Support: ENABLED")
    toolchain_log("INFO" "  - llvm-link: ${LLVM_LINK_PATH}")
    toolchain_log("INFO" "  - opt: ${LLVM_OPT_PATH}")
    toolchain_log("INFO" "  - llc: ${LLVM_LLC_PATH}")
else()
    toolchain_log("INFO" "LTO Support: DISABLED (missing tools)")
endif()
toolchain_log("INFO" "========================================")

# Generate compile_commands.json for VSCode IntelliSense
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

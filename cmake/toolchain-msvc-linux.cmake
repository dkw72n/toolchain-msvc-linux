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
    target_include_directories(${target_name} PRIVATE
        "${WDK_INCLUDE_KM}"
        "${WDK_INCLUDE_SHARED}"
    )
    
    # Kernel mode compiler definitions
    target_compile_definitions(${target_name} PRIVATE
        _AMD64_
        _WIN64
        AMD64
        DEPRECATE_DDK_FUNCTIONS=1
        _KERNEL_MODE
    )
    
    # Kernel mode compile options
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
    )
    
    # Additional libraries
    if(ARG_LIBS)
        target_link_libraries(${target_name} PRIVATE ${ARG_LIBS})
    endif()
    
    # Set output extension to .sys
    set_target_properties(${target_name} PROPERTIES
        SUFFIX ".sys"
        PREFIX ""
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
toolchain_log("INFO" "========================================")

# 生成 compile_commands.json 供 VSCode IntelliSense 使用
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

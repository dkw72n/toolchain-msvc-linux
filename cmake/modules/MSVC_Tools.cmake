# =============================================================================
# Find Compilers and Tools
# =============================================================================

# Helper function to find a tool with version fallback
function(_find_msvc_tool tool_name variable_name)
    # First try: plain names
    find_program(${variable_name} ${tool_name})
    if(${variable_name})
        toolchain_log("INFO" "Found ${tool_name}: ${${variable_name}}")
        return()
    endif()
    
    # Second try: versioned names (e.g., clang-cl-19, clang-cl-18, etc.)
    foreach(_version RANGE 20 10 -1)
        find_program(_tool_versioned "${tool_name}-${_version}")
        if(_tool_versioned)
            set(${variable_name} "${_tool_versioned}" PARENT_SCOPE)
            toolchain_log("INFO" "Found versioned ${tool_name}: ${_tool_versioned}")
            return()
        endif()
    endforeach()
    
    # Not found
    set(${variable_name} "" PARENT_SCOPE)
endfunction()

# Find clang-cl
_find_msvc_tool("clang-cl" CLANG_CL_PATH)
if(NOT CLANG_CL_PATH)
    toolchain_log("ERROR" "Could not find clang-cl or any versioned variant (clang-cl-XX) in PATH")
endif()

# Find lld-link
_find_msvc_tool("lld-link" LLD_LINK_PATH)
if(NOT LLD_LINK_PATH)
    toolchain_log("ERROR" "Could not find lld-link in PATH")
endif()

# Find llvm-lib
_find_msvc_tool("llvm-lib" LLVM_LIB_PATH)
if(NOT LLVM_LIB_PATH)
    toolchain_log("ERROR" "Could not find llvm-lib in PATH")
endif()

# =============================================================================
# Find LTO Tools (Optional)
# =============================================================================
# These tools are optional. If not found, LTO functions will not be available.

set(LTO_TOOLS_AVAILABLE TRUE)

# Find llvm-link (for merging bitcode files)
_find_msvc_tool("llvm-link" LLVM_LINK_PATH)
if(NOT LLVM_LINK_PATH)
    toolchain_log("WARNING" "llvm-link not found, LTO features will be disabled")
    set(LTO_TOOLS_AVAILABLE FALSE)
endif()

# Find opt (for LLVM IR optimization)
_find_msvc_tool("opt" LLVM_OPT_PATH)
if(NOT LLVM_OPT_PATH)
    toolchain_log("WARNING" "opt not found, LTO features will be disabled")
    set(LTO_TOOLS_AVAILABLE FALSE)
endif()

# Find llc (for compiling optimized bitcode to object)
_find_msvc_tool("llc" LLVM_LLC_PATH)
if(NOT LLVM_LLC_PATH)
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
# =============================================================================
# LLVM Bitcode LTO Support
# =============================================================================

# Enable LTO mode - compile C/C++ to bitcode
option(ENABLE_LTO_BITCODE "Compile C/C++ sources to LLVM bitcode for LTO" OFF)

# Default optimization passes for opt
set(LTO_OPT_PASSES "-O2" CACHE STRING "Optimization passes for opt command")

# Helper macro to check LTO availability
macro(_check_lto_available)
    if(NOT LTO_TOOLS_AVAILABLE)
        toolchain_log("ERROR" "LTO functions require llvm-link, opt, and llc tools. Please install LLVM tools or use non-LTO functions.")
    endif()
endmacro()

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

# Core function to compile sources to bitcode (C/C++) or object (ASM)
# 
# Parameters:
#   target_name: Name of the target (used for directory naming)
#   source_files: List of source files
#   compile_flags: A list of flags to pass to the compiler (includes, defines, etc.)
#   bc_output_list: [Output] Variable to store list of generated .bc files
#   obj_output_list: [Output] Variable to store list of generated .obj files (from ASM)
#
function(_compile_sources_to_bitcode target_name source_files compile_flags bc_output_list obj_output_list)
    set(_bc_files "")
    set(_obj_files "")
    
    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    file(MAKE_DIRECTORY "${_bc_dir}")
    
    foreach(_source ${source_files})
        _get_source_type("${_source}" _source_type)
        
        get_filename_component(_source_name "${_source}" NAME)
        get_filename_component(_source_abs "${_source}" ABSOLUTE)
        
        if(_source_type STREQUAL "C_CXX")
            set(_bc_file "${_bc_dir}/${_source_name}.bc")
            
            # Determine language flag
            get_filename_component(_ext "${_source}" EXT)
            string(TOLOWER "${_ext}" _ext_lower)
            if(_ext_lower STREQUAL ".c")
                set(_lang_flag "/TC")
            else()
                set(_lang_flag "/TP")
            endif()
            
            # Compile to bitcode using clang-cl
            # -Xclang -emit-llvm tells clang to output LLVM IR
            add_custom_command(
                OUTPUT "${_bc_file}"
                COMMAND ${CMAKE_C_COMPILER}
                    ${_lang_flag}
                    /c
                    -Xclang -emit-llvm
                    ${compile_flags}
                    "/Fo${_bc_file}"
                    "${_source_abs}"
                DEPENDS "${_source_abs}"
                COMMENT "Compiling ${_source_name} to LLVM bitcode"
                VERBATIM
            )
            
            list(APPEND _bc_files "${_bc_file}")
            
        elseif(_source_type STREQUAL "ASM")
            set(_obj_file "${_bc_dir}/${_source_name}.obj")
            
            # Assemble directly to object
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
            
            list(APPEND _obj_files "${_obj_file}")
        endif()
    endforeach()
    
    set(${bc_output_list} "${_bc_files}" PARENT_SCOPE)
    set(${obj_output_list} "${_obj_files}" PARENT_SCOPE)
endfunction()

# Function to merge, optimize, and compile bitcode files
# Returns the final object file path
function(_lto_merge_and_optimize target_name bc_files opt_passes output_obj_var)
    if(NOT bc_files)
        set(${output_obj_var} "" PARENT_SCOPE)
        return()
    endif()

    set(_bc_dir "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir")
    set(_merged_bc "${_bc_dir}/${target_name}_merged.bc")
    set(_optimized_bc "${_bc_dir}/${target_name}_optimized.bc")
    set(_final_obj "${_bc_dir}/${target_name}_lto.obj")
    
    # Defaults
    if(NOT opt_passes)
        set(_passes "${LTO_OPT_PASSES}")
    else()
        set(_passes "${opt_passes}")
    endif()
    separate_arguments(_lto_opt_passes_list NATIVE_COMMAND "${_passes}")

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
    set(_opt_deps "${_merged_bc}")
    
    # Extract plugin dependencies from opt_passes
    # Look for -load-pass-plugin followed by a path
    set(_plugin_deps "")
    set(_prev_token "")
    
    foreach(_token IN LISTS _lto_opt_passes_list)
        if(_prev_token STREQUAL "-load-pass-plugin")
            # This token is a plugin path
            # Check if it's a target name (rshit) or a full path
            get_filename_component(_plugin_name "${_token}" NAME_WE)
            message("[-] pass plugin: ${_token} ${_plugin_name}")
            list(APPEND _plugin_deps "${_token}")
        endif()
        set(_prev_token "${_token}")
    endforeach()
    
    # Add plugin dependencies to opt command
    if(_plugin_deps)
        list(APPEND _opt_deps ${_plugin_deps})
    endif()
    
    add_custom_command(
        OUTPUT "${_optimized_bc}"
        COMMAND ${LLVM_OPT_PATH}
            ${_lto_opt_passes_list}
            -o "${_optimized_bc}"
            "${_merged_bc}"
        DEPENDS ${_opt_deps}
        COMMENT "Optimizing bitcode for ${target_name} (passes: ${_passes})"
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
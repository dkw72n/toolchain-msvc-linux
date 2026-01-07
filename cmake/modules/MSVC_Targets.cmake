# =============================================================================
# MSVC Target Functions
# =============================================================================

include(MSVC_Flags)
include(MSVC_LTO)

# Add common settings to a Windows target
function(target_win_common target_name)
    cmake_parse_arguments(ARG "UNICODE" "RUNTIME" "" ${ARGN})
    
    if(ARG_UNICODE)
        target_compile_definitions(${target_name} PRIVATE UNICODE _UNICODE)
    endif()
    
    if(ARG_RUNTIME)
        # Check if ARG_RUNTIME matches standard MSVC runtime flags
        if(ARG_RUNTIME MATCHES "^(MT|MTd|MD|MDd)$")
             target_compile_options(${target_name} PRIVATE "/${ARG_RUNTIME}")
        else()
             message(WARNING "Unknown runtime: ${ARG_RUNTIME} for target ${target_name}")
        endif()
    endif()
endfunction()

# -----------------------------------------------------------------------------
# Standard Target Functions
# -----------------------------------------------------------------------------

# Add a standard Windows Executable (User Mode)
function(add_win_executable target_name)
    if(ENABLE_LTO_BITCODE)
        add_win_executable_lto(${target_name} ${ARGN})
        return()
    endif()

    cmake_parse_arguments(ARG "CONSOLE;GUI" "" "SOURCES;LIBS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})

    add_executable(${target_name} ${_sources})
    
    set_target_properties(${target_name} PROPERTIES 
        SUFFIX ".exe"
    )
    
    target_compile_options(${target_name} PRIVATE 
        ${MSVC_COMMON_COMPILE_FLAGS}
        ${MSVC_USER_MODE_INCLUDES}
    )
    
    target_link_options(${target_name} PRIVATE
        ${MSVC_USER_MODE_LINK_PATHS}
    )
    
    # Init flags just in case (though CMake init handles this mostly)
    # We rely on compile options above for strictness
endfunction()

# Add a standard Windows Library (User Mode - Static or Shared)
function(add_win_library target_name)
    cmake_parse_arguments(ARG "SHARED;STATIC" "DEF_FILE" "SOURCES;LIBS;EXPORTS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})

    set(_lib_type "")
    if(ARG_SHARED)
        set(_lib_type SHARED)
    elseif(ARG_STATIC)
        set(_lib_type STATIC)
    endif()

    if(ENABLE_LTO_BITCODE)
        add_win_library_lto(${target_name} ${_lib_type} ${ARGN})
        return()
    endif()
    
    # Handle DEF_FILE for standard build (add to sources)
    if(ARG_DEF_FILE)
        list(APPEND _sources "${ARG_DEF_FILE}")
    endif()
    
    add_library(${target_name} ${_lib_type} ${_sources})
    
    target_compile_options(${target_name} PRIVATE 
        ${MSVC_COMMON_COMPILE_FLAGS}
        ${MSVC_USER_MODE_INCLUDES}
    )
    
    if(ARG_SHARED)
        target_link_options(${target_name} PRIVATE
            ${MSVC_USER_MODE_LINK_PATHS}
        )
        # Handle EXPORTS
        if(ARG_EXPORTS)
            foreach(_export ${ARG_EXPORTS})
                target_link_options(${target_name} PRIVATE "/EXPORT:${_export}")
            endforeach()
        endif()
    endif()
endfunction()

# Wrapper for DLL
function(add_win_dll target_name)
    add_win_library(${target_name} SHARED ${ARGN})
endfunction()

# Wrapper for Static Library
function(add_win_lib target_name)
    add_win_library(${target_name} STATIC ${ARGN})
endfunction()

# Add a Windows Kernel Driver
function(add_win_driver target_name)
    if(ENABLE_LTO_BITCODE)
        add_win_driver_lto(${target_name} ${ARGN})
        return()
    endif()

    cmake_parse_arguments(ARG "KMDF;WDM" "" "SOURCES;LIBS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})

    add_executable(${target_name} ${_sources})
    
    set_target_properties(${target_name} PROPERTIES 
        SUFFIX ".sys"
    )
    
    target_compile_definitions(${target_name} PRIVATE
        ${MSVC_KERNEL_MODE_DEFINES}
    )
    
    target_compile_options(${target_name} PRIVATE
        ${MSVC_COMMON_COMPILE_FLAGS}
        ${MSVC_KERNEL_MODE_INCLUDES}
        ${MSVC_KERNEL_MODE_COMPILE_OPTIONS}
    )
    
    target_link_options(${target_name} PRIVATE
        ${MSVC_KERNEL_MODE_LINK_PATHS}
        ${MSVC_KERNEL_MODE_LINK_OPTIONS}
    )
    
    # Link default kernel libraries and user-specified libraries
    target_link_libraries(${target_name} PRIVATE 
        ${MSVC_KERNEL_MODE_LIBS}
        ${ARG_LIBS}
    )
endfunction()

# -----------------------------------------------------------------------------
# LTO Implementation Functions
# -----------------------------------------------------------------------------

# Internal helper to link LTO binary using IMPORTED objects + real executable/library
#
# This approach creates a proper CMake executable/library target, which allows
# generator expressions like $<TARGET_FILE:...> to work correctly.
#
# Parameters:
#   target_name: Name of the target
#   output_suffix: Output file suffix (.exe, .dll, .sys)
#   link_flags: Linker flags
#   obj_files: List of object files generated by LTO process
#   lib_files: List of libraries to link
#   link_type: EXE, DLL, or SYS
#
function(_link_lto_binary target_name output_suffix link_flags obj_files lib_files link_type)
    # Create a helper target that builds the object files via custom commands
    set(_obj_target "${target_name}_lto_objs")
    
    # Create a custom target that depends on all object files
    # This ensures the LTO compilation chain runs before linking
    add_custom_target(${_obj_target} DEPENDS ${obj_files})
    
    # Create an IMPORTED OBJECT library to hold the pre-built objects
    set(_imported_objs "${target_name}_imported_objs")
    add_library(${_imported_objs} OBJECT IMPORTED)
    set_target_properties(${_imported_objs} PROPERTIES
        IMPORTED_OBJECTS "${obj_files}"
    )
    
    # Create the actual executable or library target
    if(link_type STREQUAL "DLL")
        add_library(${target_name} SHARED $<TARGET_OBJECTS:${_imported_objs}>)
        set_target_properties(${target_name} PROPERTIES
            SUFFIX ".dll"
            PREFIX ""
            LINKER_LANGUAGE CXX
        )
    elseif(link_type STREQUAL "SYS")
        # Kernel drivers are executables with .sys extension
        add_executable(${target_name} $<TARGET_OBJECTS:${_imported_objs}>)
        set_target_properties(${target_name} PROPERTIES
            SUFFIX ".sys"
            PREFIX ""
            LINKER_LANGUAGE CXX
        )
    else()
        # EXE
        add_executable(${target_name} $<TARGET_OBJECTS:${_imported_objs}>)
        set_target_properties(${target_name} PROPERTIES
            SUFFIX ".exe"
            PREFIX ""
            LINKER_LANGUAGE CXX
        )
    endif()
    
    # Ensure the LTO object files are built before linking
    add_dependencies(${target_name} ${_obj_target})
    
    # Apply link flags
    target_link_options(${target_name} PRIVATE ${link_flags})
    
    # Link libraries
    if(lib_files)
        target_link_libraries(${target_name} PRIVATE ${lib_files})
    endif()
    
    # Disable default manifests for kernel drivers
    if(link_type STREQUAL "SYS")
        set_target_properties(${target_name} PROPERTIES
            LINK_FLAGS "/MANIFEST:NO"
        )
    endif()
    
    # VFS overlay dependency (for clang-cl header mapping)
    if(VFSOVERLAY_FILE)
        set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
    endif()
endfunction()


function(add_win_executable_lto target_name)
    _check_lto_available()
    cmake_parse_arguments(ARG "CONSOLE;GUI" "OPT_PASSES" "SOURCES;LIBS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Flags
    set(_compile_flags ${MSVC_COMMON_COMPILE_FLAGS_LTO} ${MSVC_USER_MODE_INCLUDES_LTO})
    
    # Compile
    _compile_sources_to_bitcode(${target_name} "${_sources}" "${_compile_flags}" _bc_files _asm_objs)
    
    # Optimize & CodeGen (Manual LTO step)
    _lto_merge_and_optimize(${target_name} "${_bc_files}" "${ARG_OPT_PASSES}" _lto_obj)
    
    # Link
    set(_output_exe "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.exe")
    set(_link_flags ${MSVC_USER_MODE_LINK_PATHS} "/SUBSYSTEM:CONSOLE")
    
    # Helper to construct lib strings
    set(_libs "")
    foreach(_lib ${ARG_LIBS})
        list(APPEND _libs "${_lib}")
    endforeach()
    
    # Collect objects
    set(_all_objs ${_lto_obj} ${_asm_objs})
    
    _link_lto_binary(${target_name} "${_output_exe}" "${_link_flags}" "${_all_objs}" "${_libs}" "EXE")
endfunction()


function(add_win_library_lto target_name)
    _check_lto_available()
    cmake_parse_arguments(ARG "SHARED;STATIC" "OPT_PASSES;DEF_FILE" "SOURCES;LIBS;EXPORTS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    set(_compile_flags ${MSVC_COMMON_COMPILE_FLAGS_LTO} ${MSVC_USER_MODE_INCLUDES_LTO})
    
    # Compile
    _compile_sources_to_bitcode(${target_name} "${_sources}" "${_compile_flags}" _bc_files _asm_objs)
    
    if(ARG_SHARED)
        # DLL Logic: Optimize -> Object -> Link
        _lto_merge_and_optimize(${target_name} "${_bc_files}" "${ARG_OPT_PASSES}" _lto_obj)
        
        set(_output_dll "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.dll")
        set(_link_flags ${MSVC_USER_MODE_LINK_PATHS})
        
        if(ARG_DEF_FILE)
            get_filename_component(_def_abs "${ARG_DEF_FILE}" ABSOLUTE)
            list(APPEND _link_flags "/DEF:${_def_abs}")
        endif()
        
        if(ARG_EXPORTS)
            foreach(_export ${ARG_EXPORTS})
                list(APPEND _link_flags "/EXPORT:${_export}")
            endforeach()
        endif()
        
         set(_libs "")
        foreach(_lib ${ARG_LIBS})
            list(APPEND _libs "${_lib}")
        endforeach()
        
        set(_all_objs ${_lto_obj} ${_asm_objs})
        _link_lto_binary(${target_name} "${_output_dll}" "${_link_flags}" "${_all_objs}" "${_libs}" "DLL")
        
    else()
        # STATIC Logic: Archive bitcode + ASM objects
        # This allows standard LTO usage by consumers
        set(_output_lib "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.lib")
        set(_archive_inputs ${_bc_files} ${_asm_objs})
        
        add_custom_command(
            OUTPUT "${_output_lib}"
            COMMAND ${CMAKE_AR} 
                "/OUT:${_output_lib}"
                ${_archive_inputs}
            DEPENDS ${_archive_inputs}
            COMMENT "Creating LTO static library ${target_name}"
            VERBATIM
        )
        add_custom_target(${target_name} ALL DEPENDS "${_output_lib}")
        
        # Backward compatibility: Property for merged bitcode
        if(_bc_files)
             set(_merged_bc "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.bc")
             add_custom_command(
                OUTPUT "${_merged_bc}"
                COMMAND ${LLVM_LINK_PATH} -o "${_merged_bc}" ${_bc_files}
                DEPENDS ${_bc_files}
                COMMENT "Merging bitcode for property"
                VERBATIM
             )
             set_target_properties(${target_name} PROPERTIES LTO_BITCODE_FILE "${_merged_bc}")
             # Ensure it builds
             set_property(TARGET ${target_name} APPEND PROPERTY SOURCES "${_merged_bc}")
        endif()
    endif()
endfunction()


function(add_win_driver_lto target_name)
    _check_lto_available()
    cmake_parse_arguments(ARG "KMDF;WDM" "OPT_PASSES" "SOURCES;LIBS" ${ARGN})
    set(_sources ${ARG_SOURCES} ${ARG_UNPARSED_ARGUMENTS})
    
    # Kernel Flags
    set(_compile_flags 
        ${MSVC_COMMON_COMPILE_FLAGS_LTO} 
        ${MSVC_KERNEL_MODE_INCLUDES_LTO}
        ${MSVC_KERNEL_MODE_COMPILE_OPTIONS}
    )
    # Add Defines explicitly to flags if needed? 
    # _compile_sources_to_bitcode accepts a single string list.
    # Defines need /D prefix.
    foreach(_def ${MSVC_KERNEL_MODE_DEFINES})
        list(APPEND _compile_flags "/D${_def}")
    endforeach()
    
    # Compile
    _compile_sources_to_bitcode(${target_name} "${_sources}" "${_compile_flags}" _bc_files _asm_objs)
    
    # Optimize & CodeGen
    _lto_merge_and_optimize(${target_name} "${_bc_files}" "${ARG_OPT_PASSES}" _lto_obj)
    
    # Link
    set(_output_sys "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.sys")
    set(_link_flags 
        ${MSVC_KERNEL_MODE_LINK_PATHS} 
        ${MSVC_KERNEL_MODE_LINK_OPTIONS}
    )
    
    # Combine default kernel libraries and user-specified libraries
    set(_libs ${MSVC_KERNEL_MODE_LIBS})
    foreach(_lib ${ARG_LIBS})
        list(APPEND _libs "${_lib}")
    endforeach()
    
    set(_all_objs ${_lto_obj} ${_asm_objs})
    
    _link_lto_binary(${target_name} "${_output_sys}" "${_link_flags}" "${_all_objs}" "${_libs}" "SYS")
endfunction()

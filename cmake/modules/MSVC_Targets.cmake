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

# Internal helper to link LTO binary
function(_link_lto_binary target_name output_file link_flags obj_files lib_files link_type)
    set(_extra_flags "")
    set(_out_flag "/OUT:${output_file}")
    
    if(link_type STREQUAL "DLL")
        list(APPEND _extra_flags "/DLL")
        set(_implib "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.lib")
        list(APPEND _extra_flags "/IMPLIB:${_implib}")
    endif()
    
    add_custom_command(
        OUTPUT "${output_file}"
        COMMAND ${CMAKE_LINKER}
            ${_out_flag}
            ${link_flags}
            ${_extra_flags}
            ${obj_files}
            ${lib_files}
        DEPENDS ${obj_files}
        COMMENT "Linking LTO binary ${target_name}"
        VERBATIM
    )
    
    add_custom_target(${target_name} ALL DEPENDS "${output_file}")
    
    # VFS overlay dependency
    set_property(TARGET ${target_name} APPEND PROPERTY OBJECT_DEPENDS "${VFSOVERLAY_FILE}")
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

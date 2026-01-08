# =============================================================================
# VFS Overlay Map Generation for Case-Insensitive Header Resolution
# =============================================================================

set(VFSOVERLAY_FILE "${CMAKE_BINARY_DIR}/vfsoverlay.yaml")

# Helper function: Convert first letter to uppercase (e.g., "driverspecs.h" -> "Driverspecs.h")
function(string_capitalize input output)
    string(SUBSTRING "${input}" 0 1 _first)
    string(SUBSTRING "${input}" 1 -1 _rest)
    string(TOUPPER "${_first}" _first_upper)
    set(${output} "${_first_upper}${_rest}" PARENT_SCOPE)
endfunction()

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
            string(TOUPPER "${_filename}" _upper_filename)
            string_capitalize("${_lower_filename}" _capitalized_filename)
            
            if(NOT "${_filename}" STREQUAL "${_lower_filename}")
                # File has mixed case, add lowercase alias
                string(APPEND _msvc_entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
            else()
                # File is already lowercase, add uppercase and capitalized aliases
                if(NOT "${_filename}" STREQUAL "${_upper_filename}")
                    string(APPEND _msvc_entries "        { 'name': '${_upper_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                endif()
                if(NOT "${_filename}" STREQUAL "${_capitalized_filename}" AND NOT "${_capitalized_filename}" STREQUAL "${_upper_filename}")
                    string(APPEND _msvc_entries "        { 'name': '${_capitalized_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                endif()
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
                string(TOUPPER "${_filename}" _upper_filename)
                string_capitalize("${_lower_filename}" _capitalized_filename)
                
                if(NOT "${_filename}" STREQUAL "${_lower_filename}")
                    # File has mixed case, add lowercase alias
                    string(APPEND _wdk_entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                else()
                    # File is already lowercase, add uppercase and capitalized aliases
                    if(NOT "${_filename}" STREQUAL "${_upper_filename}")
                        string(APPEND _wdk_entries "        { 'name': '${_upper_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                    endif()
                    if(NOT "${_filename}" STREQUAL "${_capitalized_filename}" AND NOT "${_capitalized_filename}" STREQUAL "${_upper_filename}")
                        string(APPEND _wdk_entries "        { 'name': '${_capitalized_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                    endif()
                endif()
            endforeach()
            
            if(_wdk_entries)
                string(APPEND _vfs_content "    {\n      'name': '${_wdk_dir}',\n      'type': 'directory',\n      'contents': [\n${_wdk_entries}      ]\n    },\n")
            endif()
        endif()
    endforeach()
    
    # Process KMDF WDF include directories
    set(_kmdf_version "1.15")
    set(_kmdf_wdf_dir "${WDKBASE}/Include/wdf/kmdf/${_kmdf_version}")
    if(IS_DIRECTORY "${_kmdf_wdf_dir}")
        file(GLOB_RECURSE _wdf_headers "${_kmdf_wdf_dir}/*")
        set(_wdf_entries "")
        foreach(_header ${_wdf_headers})
            get_filename_component(_filename "${_header}" NAME)
            string(TOLOWER "${_filename}" _lower_filename)
            string(TOUPPER "${_filename}" _upper_filename)
            string_capitalize("${_lower_filename}" _capitalized_filename)
            
            if(NOT "${_filename}" STREQUAL "${_lower_filename}")
                # File has mixed case, add lowercase alias
                string(APPEND _wdf_entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
            else()
                # File is already lowercase, add uppercase and capitalized aliases
                if(NOT "${_filename}" STREQUAL "${_upper_filename}")
                    string(APPEND _wdf_entries "        { 'name': '${_upper_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                endif()
                if(NOT "${_filename}" STREQUAL "${_capitalized_filename}" AND NOT "${_capitalized_filename}" STREQUAL "${_upper_filename}")
                    string(APPEND _wdf_entries "        { 'name': '${_capitalized_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
                endif()
            endif()
        endforeach()
        
        if(_wdf_entries)
            string(APPEND _vfs_content "    {\n      'name': '${_kmdf_wdf_dir}',\n      'type': 'directory',\n      'contents': [\n${_wdf_entries}      ]\n    },\n")
        endif()
    endif()

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
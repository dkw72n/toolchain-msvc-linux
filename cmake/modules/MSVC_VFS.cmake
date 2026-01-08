# =============================================================================
# VFS Overlay Map Generation for Case-Insensitive Header Resolution
# =============================================================================
# Since 'case-sensitive': 'false' is set in the VFS overlay, we only need to
# map each file once with a lowercase name alias pointing to the actual file.
# The VFS will handle case-insensitive matching automatically.
#
# IMPORTANT: Only process top-level files in each include directory.
# Do NOT use GLOB_RECURSE as it would incorrectly map files from subdirectories
# like cliext/utility to utility, causing conflicts with standard headers.
# =============================================================================

set(VFSOVERLAY_FILE "${CMAKE_BINARY_DIR}/vfsoverlay.yaml")

# Helper function: Generate lowercase alias entries for a directory
# Only processes TOP-LEVEL files (no recursion) to avoid subdirectory conflicts
function(generate_vfs_entries_for_dir dir_path out_entries)
    set(_entries "")
    
    if(IS_DIRECTORY "${dir_path}")
        # Use GLOB (not GLOB_RECURSE) to only get top-level files
        file(GLOB _headers "${dir_path}/*")
        foreach(_header ${_headers})
            # Skip directories - only process files
            if(IS_DIRECTORY "${_header}")
                continue()
            endif()
            get_filename_component(_filename "${_header}" NAME)
            string(TOLOWER "${_filename}" _lower_filename)
            # With 'case-sensitive': 'false', a lowercase alias is sufficient
            string(APPEND _entries "        { 'name': '${_lower_filename}', 'type': 'file', 'external-contents': '${_header}' },\n")
        endforeach()
    endif()
    
    set(${out_entries} "${_entries}" PARENT_SCOPE)
endfunction()

function(generate_vfsoverlay)
    toolchain_log("INFO" "Generating VFS overlay map for case-insensitive header resolution...")
    
    set(_vfs_content "{\n  'version': 0,\n  'case-sensitive': 'false',\n  'roots': [\n")
    
    # Process MSVC include directory
    generate_vfs_entries_for_dir("${MSVC_INCLUDE}" _msvc_entries)
    if(_msvc_entries)
        string(APPEND _vfs_content "    {\n      'name': '${MSVC_INCLUDE}',\n      'type': 'directory',\n      'contents': [\n${_msvc_entries}      ]\n    },\n")
    endif()
    
    # Process WDK include directories
    foreach(_wdk_dir ${WDK_INCLUDE_UM} ${WDK_INCLUDE_UCRT} ${WDK_INCLUDE_SHARED} ${WDK_INCLUDE_KM})
        generate_vfs_entries_for_dir("${_wdk_dir}" _wdk_entries)
        if(_wdk_entries)
            string(APPEND _vfs_content "    {\n      'name': '${_wdk_dir}',\n      'type': 'directory',\n      'contents': [\n${_wdk_entries}      ]\n    },\n")
        endif()
    endforeach()
    
    # Process KMDF WDF include directories
    set(_kmdf_version "1.15")
    set(_kmdf_wdf_dir "${WDKBASE}/Include/wdf/kmdf/${_kmdf_version}")
    generate_vfs_entries_for_dir("${_kmdf_wdf_dir}" _wdf_entries)
    if(_wdf_entries)
        string(APPEND _vfs_content "    {\n      'name': '${_kmdf_wdf_dir}',\n      'type': 'directory',\n      'contents': [\n${_wdf_entries}      ]\n    },\n")
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
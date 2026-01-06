# =============================================================================
# LTO Test - Windows console executable
# =============================================================================
# This test case demonstrates the usage of add_win_executable_lto function
# 
# Build process:
#   1. main.cpp and helper.cpp are compiled to LLVM bitcode (.bc)
#   2. Use llvm-link to merge all .bc files
#   3. Use opt to optimize the merged bitcode (Cross-Translation Unit Optimization)
#   4. Use llc to compile optimized bitcode to .obj
#   5. Use lld-link to link and generate final .exe

# =============================================================================
# OPT_PASSES parameter description
# =============================================================================
# Each LTO target can specify its own optimization configuration via OPT_PASSES parameter.
# If not specified, the global default ${LTO_OPT_PASSES} (default "-O2") is used
#
# Basic optimization levels:
#   -O0          : No optimization
#   -O1          : Basic optimization
#   -O2          : Standard optimization (default)
#   -O3          : Aggressive optimization
#   -Os          : Optimize for code size
#   -Oz          : Extreme code size optimization
#
# New Pass Manager (LLVM 13+) uses --passes= syntax:
#   --passes='default<O2>'                 : Equivalent to -O2
#   --passes='default<O3>'                 : Equivalent to -O3
#   --passes='inline,sroa,gvn'             : Manually specify pass sequence
#   --passes='module(inline,globaldce)'    : Module level pass
#   --passes='cgscc(inline,argpromo)'      : Call graph level pass
#   --passes='function(sroa,early-cse)'    : Function level pass
#   --passes='loop(licm,loop-unroll)'      : Loop level pass
#
# Common Pass description:
#   inline           : Function inlining
#   sroa             : Scalar Replacement of Aggregates
#   gvn              : Global Value Numbering
#   instcombine      : Instruction combining
#   simplifycfg      : Simplify CFG
#   loop-unroll      : Loop unrolling
#   licm             : Loop Invariant Code Motion
#   dce              : Dead Code Elimination
#   adce             : Aggressive Dead Code Elimination
#   globaldce        : Global Dead Code Elimination
#   mem2reg          : Memory to Register promotion
#   argpromo         : Argument Promotion
#   ipsccp           : Interprocedural SCCP
#   deadargelim      : Dead Argument Elimination
#   globalopt        : Global Variable Optimization
#   tailcallelim     : Tail Call Elimination
#
# Debug and Analysis options:
#   --time-passes               : Show execution time of each pass
#   --stats                     : Show optimization statistics
#   --debug-pass-manager        : Debug pass manager
#
# =============================================================================

# Example: Set custom optimization config for current target
# Method 1: Set via command line with -D (Recommended)
#   cmake -DLTO_OPT_PASSES="-O3" ..
#
# Method 2: Override in CMakeLists.txt (Affects subsequent targets only)
# set(LTO_OPT_PASSES "-O3 --time-passes" CACHE STRING "Custom opt passes" FORCE)
#
# Method 3: Set different optimization for different build types
# if(CMAKE_BUILD_TYPE STREQUAL "Release")
#     set(LTO_OPT_PASSES "-O3" CACHE STRING "" FORCE)
# elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
#     set(LTO_OPT_PASSES "-O2" CACHE STRING "" FORCE)
# elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
#     set(LTO_OPT_PASSES "-Oz" CACHE STRING "" FORCE)
# else()
#     set(LTO_OPT_PASSES "-O0" CACHE STRING "" FORCE)
# endif()

# Check if LTO is available
if(LTO_TOOLS_AVAILABLE)
    # Print current global optimization pass config
    message(STATUS "[LTO-Test] Global LTO_OPT_PASSES: ${LTO_OPT_PASSES}")

    add_win_executable_lto(test_exe_lto CONSOLE
	    OPT_PASSES "-load-pass-plugin $ENV{LLVM_LTO_PATH} -passes=$ENV{LLVM_LTO_PASS}"
        SOURCES 
            main.cpp 
            helper.cpp
        LIBS 
            kernel32.lib 
            user32.lib
    )
else()
    message(STATUS "[LTO-Test] Skipping test_exe_lto - LTO tools not available")
endif()
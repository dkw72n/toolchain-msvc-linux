# =============================================================================
# LTO 测试 - Windows 控制台可执行文件
# =============================================================================
# 此测试用例展示了 add_win_executable_lto 函数的使用
# 
# 构建流程:
#   1. main.cpp 和 helper.cpp 被编译为 LLVM bitcode (.bc)
#   2. 使用 llvm-link 将所有 .bc 文件合并
#   3. 使用 opt 对合并后的 bitcode 进行优化（跨编译单元优化）
#   4. 使用 llc 将优化后的 bitcode 编译为 .obj
#   5. 使用 lld-link 链接生成最终的 .exe

# =============================================================================
# OPT_PASSES 参数说明
# =============================================================================
# 每个 LTO target 都可以通过 OPT_PASSES 参数指定自己的优化配置。
# 如果不指定，则使用全局默认值 ${LTO_OPT_PASSES} (默认 "-O2")
#
# 基础优化级别:
#   -O0          : 不优化
#   -O1          : 基础优化
#   -O2          : 标准优化 (默认)
#   -O3          : 激进优化
#   -Os          : 优化代码大小
#   -Oz          : 极限压缩代码大小
#
# 新版 Pass Manager (LLVM 13+) 使用 --passes= 语法:
#   --passes='default<O2>'                 : 等同于 -O2
#   --passes='default<O3>'                 : 等同于 -O3
#   --passes='inline,sroa,gvn'             : 手动指定 pass 序列
#   --passes='module(inline,globaldce)'    : 模块级 pass
#   --passes='cgscc(inline,argpromo)'      : 调用图级 pass
#   --passes='function(sroa,early-cse)'    : 函数级 pass
#   --passes='loop(licm,loop-unroll)'      : 循环级 pass
#
# 常用 Pass 说明:
#   inline           : 函数内联
#   sroa             : Scalar Replacement of Aggregates (标量替换)
#   gvn              : Global Value Numbering (全局值编号)
#   instcombine      : 指令合并
#   simplifycfg      : 控制流简化
#   loop-unroll      : 循环展开
#   licm             : Loop Invariant Code Motion (循环不变量外提)
#   dce              : Dead Code Elimination (死代码消除)
#   adce             : Aggressive Dead Code Elimination
#   globaldce        : 全局死代码消除
#   mem2reg          : 内存到寄存器提升
#   argpromo         : Argument Promotion (参数提升)
#   ipsccp           : Interprocedural SCCP (过程间常量传播)
#   deadargelim      : 死参数消除
#   globalopt        : 全局变量优化
#   tailcallelim     : 尾调用消除
#
# 调试与分析选项:
#   --time-passes               : 显示每个 pass 的执行时间
#   --stats                     : 显示优化统计信息
#   --debug-pass-manager        : 调试 pass manager
#
# =============================================================================

# 示例: 为当前目标设置自定义优化配置
# 方法1: 在命令行通过 -D 设置 (推荐)
#   cmake -DLTO_OPT_PASSES="-O3" ..
#
# 方法2: 在 CMakeLists.txt 中覆盖 (仅影响后续目标)
# set(LTO_OPT_PASSES "-O3 --time-passes" CACHE STRING "Custom opt passes" FORCE)
#
# 方法3: 针对不同构建类型设置不同优化
# if(CMAKE_BUILD_TYPE STREQUAL "Release")
#     set(LTO_OPT_PASSES "-O3" CACHE STRING "" FORCE)
# elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
#     set(LTO_OPT_PASSES "-O2" CACHE STRING "" FORCE)
# elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
#     set(LTO_OPT_PASSES "-Oz" CACHE STRING "" FORCE)
# else()
#     set(LTO_OPT_PASSES "-O0" CACHE STRING "" FORCE)
# endif()

# 检查 LTO 是否可用
if(LTO_TOOLS_AVAILABLE)
    # 打印当前全局优化 pass 配置
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

## 功能概述

### 1. **必需变量验证**

- `WDKBASE` - Windows Driver Kit 的基础路径（必须定义）
- `MSVCBASE` - MSVC 的基础路径（必须定义）
- 脚本会检查这些目录是否存在，以及是否包含预期的子目录结构（Include、Lib 等）

### 2. **WDK 版本检测**

- `WDKVERSION` 是可选的
- 如果用户没有指定，脚本会自动在 `${WDKBASE}/Include/` 下查找 `10.*` 格式的版本目录，并选择最高版本
- 日志中会明确说明版本来源：`user-specified` 或 `auto-detected from ${WDKBASE}/Include/`

### 3. **编译器查找**

- 默认查找 `clang-cl`
- 如果找不到，会尝试带版本号的变体（如 `clang-cl-19`、`clang-cl-18` 等，从高到低）
- 同样的逻辑也适用于 `lld-link` 和 `llvm-lib`

### 4. **VFS Overlay 生成**

- 自动扫描 MSVC 和 WDK 的头文件目录
- 为所有包含大写字母的文件名创建小写别名映射
- 生成 `vfsoverlay.yaml` 文件，使用 clang 的 `-ivfsoverlay` 选项来实现大小写不敏感的头文件解析
- 这个 VFS overlay 文件作为所有目标的构建依赖

### 5. **自定义 Target 函数**

| 函数                   | 用途                           | 主要选项                                                     |
| ---------------------- | ------------------------------ | ------------------------------------------------------------ |
| `add_win_executable` | 创建 Windows 可执行文件 (.exe) | `WIN32`, `CONSOLE`, `SUBSYSTEM`, `SOURCES`, `LIBS` |
| `add_win_dll`        | 创建 Windows 动态链接库 (.dll) | `DEF_FILE`, `SOURCES`, `LIBS`, `EXPORTS`             |
| `add_win_lib`        | 创建 Windows 静态库 (.lib)     | `SOURCES`                                                  |
| `add_win_driver`     | 创建 Windows 内核驱动 (.sys)   | `WDM`, `KMDF`, `KMDF_VERSION`, `SOURCES`, `LIBS`   |

### 6. **辅助函数**

- `target_win_common` - 为目标添加通用设置（如 `UNICODE`、运行时库选择）

## 使用示例

```bash
# 配置项目
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-msvc-linux.cmake \
    -DWDKBASE=/path/to/wdk \
    -DMSVCBASE=/path/to/msvc \
    -DWDKVERSION=10.0.22621.0  # 可选

# 构建
cmake --build build
```

在 CMakeLists.txt 中使用：

```cmake
# 创建控制台程序
add_win_executable(myapp CONSOLE
    SOURCES main.cpp utils.cpp
    LIBS kernel32.lib user32.lib
)

# 创建 DLL
add_win_dll(mydll
    SOURCES dllmain.cpp exports.cpp
    DEF_FILE exports.def
)

# 创建内核驱动
add_win_driver(mydriver KMDF
    SOURCES driver.cpp
    LIBS wdfldr.lib
)
```

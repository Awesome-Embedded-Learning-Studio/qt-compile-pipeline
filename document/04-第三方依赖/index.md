# 第三方依赖系统

## 概述

third_party 系统是 Qt 交叉编译流水线中的核心组件，负责管理、编译和安装 Qt 所需的第三方依赖库。这些库通常在嵌入式 Linux 系统中不可用或版本不匹配，因此需要从源码交叉编译。

## 系统架构

### 目录结构

```
qt-compile-pipeline/
├── config/
│   └── third_party.conf          # 第三方库配置文件
├── scripts/
│   └── third_party/
│       ├── manager.sh             # 管理器主脚本
│       ├── common.sh              # 公共函数库
│       ├── tslib/
│       │   └── builtin.sh         # tslib 构建脚本
│       ├── libsndfile/
│       │   └── builtin.sh         # libsndfile 构建脚本
│       ├── pulseaudio/
│       │   └── builtin.sh         # PulseAudio 构建脚本
│       ├── ffmpeg/
│       │   └── builtin.sh         # FFmpeg 构建脚本
│       └── openssl/
│           └── builtin.sh         # OpenSSL 构建脚本
└── qt-workdir/
    └── third-party-sysroot/       # 依赖库安装目录
        ├── downloads/             # 源码包下载目录
        ├── src/                   # 源码解压目录
        ├── usr/                   # 库文件安装目录
        │   ├── include/           # 头文件
        │   └── lib/               # 库文件
        └── lib/
            ├── cmake/             # CMake 配置文件
            └── pkgconfig/         # pkg-config 文件
```

### 配置文件

第三方库的配置位于 `config/third_party.conf`，包含：

- **通用配置**：sysroot 路径、下载目录
- **库特定配置**：版本号、下载 URL、启用状态
- **库注册表**：启用的库列表

```bash
# 第三方库统一 sysroot 目录
THIRD_PARTY_SYSROOT="${WORK_DIR}/third-party-sysroot"

# 临时下载目录
THIRD_PARTY_DL_DIR="${THIRD_PARTY_SYSROOT}/downloads"

# 启用的第三方库列表（按安装顺序）
THIRD_PARTY_LIBS="tslib libsndfile pulseaudio ffmpeg openssl"
```

## 管理器脚本

### 使用方法

第三方库管理器 `scripts/third_party/manager.sh` 提供统一的命令行接口：

```bash
# 加载配置
source config/qt.conf

# 使用管理器
bash scripts/third_party/manager.sh <command> [args...]
```

### 可用命令

| 命令 | 说明 |
|------|------|
| `install [lib...]` | 安装指定的库（或全部） |
| `clean [lib...]` | 清理指定的库（或全部） |
| `status` | 显示所有库的安装状态 |
| `generate-cmake` | 生成 CMake 配置片段 |
| `get-sysroot [lib]` | 获取库的 sysroot 路径 |
| `get-lib-path <lib>` | 获取库的库文件路径 |
| `help` | 显示帮助信息 |

### 命令示例

```bash
# 安装所有启用的库
bash scripts/third_party/manager.sh install

# 只安装 PulseAudio
bash scripts/third_party/manager.sh install pulseaudio

# 安装多个库
bash scripts/third_party/manager.sh install tslib ffmpeg

# 查看状态
bash scripts/third_party/manager.sh status

# 清理所有库
bash scripts/third_party/manager.sh clean

# 清理特定库
bash scripts/third_party/manager.sh clean ffmpeg

# 生成 CMake 配置片段
bash scripts/third_party/manager.sh generate-cmake > fragment.cmake

# 获取 sysroot 路径
bash scripts/third_party/manager.sh get-sysroot
```

## 安装流程

### 1. 准备环境

```bash
# 加载 Qt 配置（设置 WORK_DIR 等变量）
source config/qt.conf

# 可选：加载工具链配置
source config/toolchain.conf
```

### 2. 安装依赖

```bash
# 安装所有第三方库
bash scripts/third_party/manager.sh install
```

安装过程会自动：
1. 创建必要的目录结构
2. 下载源码包到 `downloads/` 目录
3. 解压源码到 `src/` 目录
4. 交叉编译库
5. 安装到 sysroot 目录
6. 生成 CMake 和 pkg-config 配置文件

### 3. 验证安装

```bash
# 检查安装状态
bash scripts/third_party/manager.sh status
```

输出示例：
```
===============================================================
Third-Party Libraries Status
===============================================================
Library         Enabled   Installed
-------------------------------------------------------
tslib           true      Yes
libsndfile      true      Yes
pulseaudio      true      Yes
ffmpeg          true      Yes
openssl         true      Yes

Sysroot: /path/to/qt-workdir/third-party-sysroot
```

## 状态检查

### 检查特定库

每个库的安装状态通过以下方式判断：

1. **标记文件**：`${THIRD_PARTY_SYSROOT}/.${lib}-installed`
2. **库文件**：检查 `.so` 文件是否存在
3. **头文件**：检查关键头文件是否存在
4. **配置文件**：检查 pkg-config 文件是否存在

### 手动检查

```bash
# 检查 tslib
ls -la ${THIRD_PARTY_SYSROOT}/usr/lib/libts.so*
ls -la ${THIRD_PARTY_SYSROOT}/.tslib-installed

# 检查 FFmpeg
ls -la ${THIRD_PARTY_SYSROOT}/usr/lib/libavcodec.so*

# 检查 OpenSSL
ls -la ${THIRD_PARTY_SYSROOT}/usr/lib/libssl.so*
```

## 清理操作

### 清理特定库

```bash
# 清理单个库
bash scripts/third_party/manager.sh clean ffmpeg

# 清理多个库
bash scripts/third_party/manager.sh clean ffmpeg pulseaudio
```

### 清理所有库

```bash
# 清理所有已安装的库
bash scripts/third_party/manager.sh clean
```

### 完全清理

如需完全删除 third-party sysroot：

```bash
# 删除整个 sysroot 目录
rm -rf ${THIRD_PARTY_SYSROOT}
```

## 依赖关系

第三方库之间存在依赖关系，安装顺序很重要：

```
tslib           (独立，无依赖)
    |
    v
libsndfile      (独立，无依赖，被 PulseAudio 依赖)
    |
    v
pulseaudio      (依赖: libsndfile)
    |
    v
ffmpeg          (独立，无依赖)
    |
    v
openssl         (独立，无依赖)
```

管理器会按照配置文件中 `THIRD_PARTY_LIBS` 定义的顺序自动安装。

## 集成到 Qt 构建

第三方库编译完成后，会被集成到 Qt 交叉编译过程中：

```bash
# Qt 配置时会自动检测第三方库
# 通过 CMAKE_PREFIX_PATH 和 pkg-config

# 编译 Qt
bash scripts/03-build-target-qt.sh
```

Qt 模块与第三方库的对应关系：

| Qt 模块 | 第三方库 |
|---------|----------|
| Qt Gui | tslib |
| Qt Multimedia | PulseAudio, FFmpeg |
| Qt Network | OpenSSL |

## 配置库的启用状态

在 `config/third_party.conf` 中修改：

```bash
# 禁用某个库
PULSEAUDIO_ENABLED=false

# 修改版本
TSLIB_BUILTIN_VERSION=1.23
```

## 构建系统类型

不同的第三方库使用不同的构建系统：

| 库 | 构建系统 | 配置脚本 |
|---|---------|---------|
| tslib | Autotools | ./configure |
| libsndfile | Autotools | ./configure |
| PulseAudio | Meson | meson setup |
| FFmpeg | 自定义 | ./configure |
| OpenSSL | Perl Configure | ./Configure |

## 日志和调试

### 构建日志

每个库的构建日志保存在 `WORK_DIR/log/` 目录：

```bash
# 查看最近的构建日志
ls -lt ${WORK_DIR}/log/*_build_*.log

# 查看 FFmpeg 构建日志
cat ${WORK_DIR}/log/ffmpeg_build_*.log
```

### 常见问题

1. **下载失败**：检查网络连接和 URL 有效性
2. **编译错误**：查看构建日志的最后几行
3. **依赖缺失**：确保按正确顺序安装

## 相关文件

- 配置文件：`config/third_party.conf`
- 管理器：`scripts/third_party/manager.sh`
- 公共函数：`scripts/third_party/common.sh`
- 现有依赖列表：`现有依赖列表.md`

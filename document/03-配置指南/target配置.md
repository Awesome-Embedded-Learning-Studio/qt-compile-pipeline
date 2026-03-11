# Target Qt 配置

Target Qt 是交叉编译后运行在目标设备（如 ARM 嵌入式平台）上的 Qt 版本。

## 配置文件位置

```
config/target.conf
```

## 配置项详解

### 依赖检查

```bash
# 此文件依赖 qt.conf 中的 WORK_DIR 变量
: "${WORK_DIR:?Error: WORK_DIR is not set. Please source qt.conf first: source config/qt.conf}"
```

## 安装路径配置

### TARGET_INSTALL_PREFIX

```bash
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-imx6ull"
```

| 参数 | 说明 |
|------|------|
| 默认值 | `${WORK_DIR}/qt6-imx6ull` |
| 作用 | Target Qt 的本地安装目录（staging 目录） |
| 注意 | Qt 将安装到这里，然后再部署到目标设备 |

### TARGET_DEVICE_PREFIX

```bash
TARGET_DEVICE_PREFIX="/usr/local/qt6"
```

| 参数 | 说明 |
|------|------|
| 默认值 | `/usr/local/qt6` |
| 作用 | Qt 在目标设备上的实际路径 |
| 注意 | 用于运行时查找库和插件，通常设置为固定路径 |

**路径关系说明**：

```
[编译主机] TARGET_INSTALL_PREFIX   → Qt 编译产物存放位置
                                  ↓ (部署时复制)
[目标设备] TARGET_DEVICE_PREFIX    → Qt 运行时的实际路径
```

**示例**：

```bash
# 场景1：默认路径
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-imx6ull"
TARGET_DEVICE_PREFIX="/usr/local/qt6"

# 场景2：只读系统
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-target"
TARGET_DEVICE_PREFIX="/opt/qt6"

# 场景3：用户空间安装
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-home"
TARGET_DEVICE_PREFIX="/home/root/qt6"
```

## OpenGL 配置

```bash
# 是否启用 OpenGL 支持
TARGET_USE_OPENGL=false

# OpenGL 类型（仅在 TARGET_USE_OPENGL=true 时生效）
#   desktop: 桌面 OpenGL（X11 通常使用）
#   es2:     OpenGL ES 2.0（嵌入式设备通常使用）
# TARGET_OPENGL_TYPE="es2"
```

## ALSA 音频支持配置

```bash
# 是否启用 ALSA 音频支持 (QtMultiMedia 需要)
TARGET_USE_ALSA=true

# ALSA mini sysroot 路径 (由 scripts/install_target_deps.sh 自动生成)
# 如果为空，脚本将使用默认路径: ${WORK_DIR}/arm-sysroot-${TARGET_ARCH}
TARGET_SYSROOT_ALSA=""
```

## FFmpeg 多媒体支持配置

```bash
# 是否启用 FFmpeg 多媒体支持 (QtMultiMedia 需要)
TARGET_USE_FFMPEG=true

# FFmpeg 额外配置参数（可选）
TARGET_FFMPEG_EXTRA_CONFIG=""

# 目标架构 (用于下载正确的 .deb 包)
# 可选值: armhf (ARMv7-A), arm64 (ARMv8-A)
TARGET_ARCH="armhf"
```

## 目标平台配置 (mkspec)

### QT_TARGET_PLATFORM

```bash
QT_TARGET_PLATFORM="linux-arm-gnueabihf-g++"

# 验证关键变量
: "${QT_TARGET_PLATFORM:?Error: QT_TARGET_PLATFORM must be set and non-empty in target.conf}"
```

Qt 平台插件名称（mkspec），configure 通常会自动检测。

**常用平台**：

| 平台 | 说明 | 目标架构 |
|------|------|----------|
| `linux-arm-gnueabihf-g++` | ARMv7-A, hard float | i.MX6ULL, Raspberry Pi 2/3 |
| `linux-aarch64-gnu-g++` | ARMv8-A 64位 | i.MX8, Raspberry Pi 4 |
| `linux-arm-gnueabi-g++` | ARMv7-A, soft float | 老款 ARM 设备 |

## 渲染后端配置

### TARGET_RENDER_BACKENDS

根据目标平台的显示能力选择合适的渲染后端。

**精简版配置**（推荐）：

```bash
TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=ON \
  -DFEATURE_evdev=ON \
  -DFEATURE_tslib=ON \
  -DFEATURE_libinput=OFF \
  -DINPUT_opengl=no \
  -DFEATURE_glib=OFF \
  -DFEATURE_system_sqlite=OFF \
"
```

**说明**：
- 只保留必须显式设置的 flag
- 删除了默认值已为 OFF 的冗余 flag
- Qt 会自动使用内置版本替代缺失的系统库

### 渲染后端对比表

| 场景 | 推荐配置 | 说明 |
|------|----------|------|
| **裸 Framebuffer** | `FEATURE_linuxfb=ON`<br>`FEATURE_eglfs=OFF`<br>`FEATURE_xcb=OFF` | 无 GPU，直接写 framebuffer |
| **EGLFS (GPU直出)** | `FEATURE_eglfs=ON`<br>`FEATURE_linuxfb=OFF`<br>`FEATURE_xcb=OFF` | 有 GPU，使用 EGL/OpenGL ES |
| **X11 桌面** | `FEATURE_xcb=ON`<br>`FEATURE_eglfs=OFF` | 运行在 X Window 系统上 |
| **Wayland** | `FEATURE_wayland=ON` + 添加 `qtwayland` 模块 | 运行在 Wayland 合成器上 |

### 输入设备配置

| 设备 | 配置项 | 说明 |
|------|--------|------|
| `evdev` | `FEATURE_evdev=ON` | Linux event device 接口（触摸屏、鼠标、键盘） |
| `tslib` | `FEATURE_tslib=ON` | 触摸屏校准库（老旧设备，现在多用 libinput） |
| `libinput` | `FEATURE_libinput=ON` | 统一输入设备处理（推荐） |

## 渲染后端配置示例

### 裸 Framebuffer 配置

适用于无 GPU 的设备，直接操作 Linux framebuffer：

```bash
TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=ON \
  -DFEATURE_evdev=ON \
  -DFEATURE_tslib=OFF \
  -DFEATURE_libinput=OFF \
  -DINPUT_opengl=no \
  -DFEATURE_glib=OFF \
"

# 运行时环境变量
export QT_QPA_PLATFORM=linuxfb
```

### EGLFS 配置（GPU 加速）

适用于有 GPU 的设备，使用 EGL/OpenGL ES：

```bash
TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=ON \
  -DFEATURE_linuxfb=OFF \
  -DFEATURE_evdev=ON \
  -DFEATURE_tslib=OFF \
  -DFEATURE_libinput=ON \
  -DFEATURE_glib=ON \
"

# 运行时环境变量
export QT_QPA_PLATFORM=eglfs
```

### X11 配置

适用于运行在 X Window 系统上的设备：

```bash
TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=ON \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=OFF \
  -DFEATURE_evdev=OFF \
  -DFEATURE_libinput=ON \
  -DFEATURE_glib=ON \
"

# 运行时环境变量
export QT_QPA_PLATFORM=xcb
```

### Wayland 配置

适用于运行在 Wayland 合成器上的设备：

```bash
# 在 qt.conf 中添加 qtwayland 模块
QT_MODULES="... qtwayland"

TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=OFF \
  -DFEATURE_wayland=ON \
  -DFEATURE_evdev=OFF \
  -DFEATURE_libinput=ON \
  -DFEATURE_glib=ON \
"

# 运行时环境变量
export QT_QPA_PLATFORM=wayland
```

## 额外 Configure 参数

### TARGET_CONFIGURE_EXTRA

```bash
TARGET_CONFIGURE_EXTRA="\
  -DFEATURE_printsupport=OFF \
  -no-feature-opengl \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
"
```

### TARGET_CMAKE_EXTRA

```bash
TARGET_CMAKE_EXTRA="\
  -DCMAKE_CXX_FLAGS=-Wno-psabi \
"
```

用于设置编译器标志等 CMake 特定选项。

## 常用参数说明

### 构建类型

| 参数 | 说明 |
|------|------|
| `-release` | 发行版构建（嵌入式设备默认） |
| `-debug` | 调试版构建 |
| `-optimize-size` | 优化体积 |
| `-optimize-speed` | 优化速度 |

### 功能开关

```bash
-DFEATURE_xxx=ON/OFF    # 启用/禁用特定功能
```

### 交叉编译特定

| 参数 | 说明 |
|------|------|
| `-extprefix <path>` | 本地 staging 安装路径（脚本自动设置） |
| `-prefix <path>` | 目标设备上的路径（脚本自动设置） |
| `-qt-host-path <path>` | Host Qt 路径（脚本自动设置） |

## 配置示例

### i.MX6ULL 裸 Framebuffer

```bash
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-imx6ull"
TARGET_DEVICE_PREFIX="/usr/local/qt6"
QT_TARGET_PLATFORM="linux-arm-gnueabihf-g++"
TARGET_ARCH="armhf"

TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=ON \
  -DFEATURE_evdev=ON \
  -DFEATURE_tslib=ON \
  -DINPUT_opengl=no \
"

TARGET_CONFIGURE_EXTRA="\
  -DFEATURE_printsupport=OFF \
  -no-feature-opengl \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
"
```

### i.MX8 EGLFS GPU 加速

```bash
TARGET_INSTALL_PREFIX="${WORK_DIR}/qt6-imx8"
TARGET_DEVICE_PREFIX="/usr/local/qt6"
QT_TARGET_PLATFORM="linux-aarch64-gnu-g++"
TARGET_ARCH="arm64"

TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=ON \
  -DFEATURE_linuxfb=OFF \
  -DFEATURE_evdev=ON \
  -DFEATURE_libinput=ON \
  -DFEATURE_glib=ON \
"

TARGET_CONFIGURE_EXTRA="\
  -DFEATURE_printsupport=ON \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
"
```

## 注意事项

1. **配置顺序**：必须先 `source config/qt.conf`
2. **参数格式**：使用反斜杠 `\` 进行多行续行
3. **平台选择**：`QT_TARGET_PLATFORM` 必须正确设置，否则编译失败
4. **渲染后端**：根据目标设备硬件选择合适的后端
5. **官方文档**：详见 [Qt Embedded Linux](https://doc.qt.io/qt-6/embedded-linux.html)

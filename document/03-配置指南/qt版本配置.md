# Qt 版本配置

`config/qt.conf` 是 Qt 编译管道的核心配置文件，定义了 Qt 版本、源码下载地址、编译模块和构建开关。

## 配置文件位置

```
config/qt.conf
```

## 配置项详解

### QT_VERSION - Qt 版本号

指定要编译的 Qt 版本。

```bash
QT_VERSION="6.9.1"
```

**注意事项：**
- 版本号必须与源码包版本一致
- 建议使用官方稳定发布版本
- 版本格式：主版本.次版本.补丁版本

### QT_SRC_URL - 源码下载地址

指定 Qt 源码包的下载 URL。

```bash
QT_SRC_URL="https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-${QT_VERSION}.tar.xz"
```

**推荐下载源：**

| 来源 | URL | 说明 |
|------|-----|------|
| 官方源 | `https://download.qt.io/official_releases/qt/` | 官方服务器，速度较慢 |
| 清华镜像 | `https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/` | 国内推荐 |
| USTC 镜像 | `https://mirrors.ustc.edu.cn/qtproject/archive/qt/` | 国内备选 |

**配置示例：**

```bash
# 使用官方源
QT_SRC_URL="https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-6.9.1.tar.xz"

# 使用清华镜像
QT_SRC_URL="https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-6.9.1.tar.xz"

# 自动引用版本变量
QT_SRC_URL="https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/6.9/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz"
```

### QT_SRC_DIR - 源码目录名

解压后的源码目录名称。

```bash
QT_SRC_DIR="qt-everywhere-src-${QT_VERSION}"
```

**说明：**
- Qt 官方源码包解压后默认目录名为 `qt-everywhere-src-{version}`
- 通常不需要修改此配置

### WORK_DIR - 工作目录

编译工作的根目录，所有中间产物和最终安装都在此目录下。

```bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${PROJECT_ROOT}/qt-workdir"
```

**说明：**
- 默认位于项目根目录下的 `qt-workdir/`
- 包含源码、编译产物、安装文件等所有内容
- 建议使用绝对路径，确保编译产物不溢出

## QT_MODULES - 模块列表

指定要编译的 Qt 模块，使用空格分隔。

```bash
QT_MODULES="qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat"
```

### 常用模块说明

| 模块 | 说明 | 推荐场景 |
|------|------|---------|
| `qtbase` | 核心模块（必需） | 所有项目 |
| `qtdeclarative` | QML/Quick 支持 | 需要QML界面 |
| `qtmultimedia` | 多媒体支持 | 音视频播放 |
| `qtcharts` | 图表组件 | 数据可视化 |
| `qtshadertools` | 着色器工具 | 图形渲染 |
| `qtserialport` | 串口通信 | 硬件通信 |
| `qtvirtualkeyboard` | 虚拟键盘 | 触摸屏设备 |
| `qt5compat` | Qt 5 兼容层 | 迁移旧项目 |

### 完整模块列表

以下列出 Qt 6.x 常用模块：

| 模块名称 | 说明 | 是否必需 |
|---------|------|---------|
| `qtbase` | 核心基础库 | 必需 |
| `qtdeclarative` | QML/Quick 框架 | 推荐 |
| `qttools` | Qt 工具集（linguist, assistant 等） | 推荐 |
| `qtmultimedia` | 音视频多媒体支持 | 可选 |
| `qtcharts` | 图表组件库 | 可选 |
| `qtdatavis3d` | 3D 数据可视化 | 可选 |
| `qtshadertools` | 着色器工具链 | 可选 |
| `qtserialport` | 串口通信 API | 可选 |
| `qtserialbus` | 串口总线协议 | 可选 |
| `qtnetworkauth` | 网络认证支持 | 可选 |
| `qtwebsockets` | WebSocket 协议 | 可选 |
| `qtwebchannel` | Web 通信通道 | 可选 |
| `qtwebengine` | Chromium 浏览器引擎 | 可选（体积大） |
| `qtwebview` | 原生 WebView 封装 | 可选 |
| `qtquick3d` | 3D 渲染扩展 | 可选 |
| `qtquicktimeline` | 动画时间轴 | 可选 |
| `qt3d` | 3D 渲染框架 | 可选 |
| `qtimageformats` | 额外图片格式 | 可选 |
| `qtscxml` | 状态机框架 | 可选 |
| `qtvirtualkeyboard` | 虚拟键盘输入 | 可选 |
| `qtconnectivity` | 蓝牙/NFC 连接 | 可选 |
| `qtdoc` | 文档生成工具 | 可选 |
| `qt5compat` | Qt5 兼容层 | 迁移时需要 |
| `qtactiveqt` | ActiveX 支持（Windows） | Windows 可选 |
| `qtandroidextras` | Android 扩展 | Android 可选 |
| `qtmacextras` | macOS 扩展 | macOS 可选 |

### 模块配置示例

**最小配置（仅核心）：**
```bash
QT_MODULES="qtbase"
```

**桌面应用推荐：**
```bash
QT_MODULES="qtbase qtdeclarative qttools qtcharts qtmultimedia"
```

**嵌入式设备推荐：**
```bash
QT_MODULES="qtbase qtdeclarative qtserialport qtvirtualkeyboard qt5compat"
```

**完整功能（包含所有常用模块）：**
```bash
QT_MODULES="qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat qttools qtimageformats qtnetworkauth qtwebsockets"
```

## 编译开关

### BUILD_HOST_QT - 编译主机 Qt

控制是否编译主机版本的 Qt。

```bash
BUILD_HOST_QT=true
```

| 值 | 说明 |
|----|------|
| `true` | 编译主机版本 Qt（默认） |
| `false` | 跳过主机版本编译 |

**说明：**
- 主机 Qt 是在开发机器上运行的 Qt 版本
- 交叉编译时通常需要先编译主机版本
- 设置为 `false` 可以节省编译时间

### BUILD_TARGET_QT - 编译目标 Qt

控制是否编译目标设备的 Qt（交叉编译版本）。

```bash
BUILD_TARGET_QT=true
```

| 值 | 说明 |
|----|------|
| `true` | 编译目标设备 Qt（启用交叉编译） |
| `false` | 仅编译主机版本 |

**重要提示：**
- 设置 `BUILD_TARGET_QT=true` 会强制启用 `BUILD_HOST_QT`
- 交叉编译需要先编译主机 Qt 作为依赖
- 仅用于嵌入式设备或交叉编译场景

## 配置验证

配置文件内置变量验证机制，确保关键变量已正确设置：

```bash
: "${QT_VERSION:?Error: QT_VERSION must be set and non-empty in qt.conf}"
: "${QT_SRC_URL:?Error: QT_SRC_URL must be set and non-empty in qt.conf}"
: "${QT_MODULES:?Error: QT_MODULES must be set and non-empty in qt.conf}"
: "${WORK_DIR:?Error: WORK_DIR must be set and non-empty in qt.conf}"
```

如果任何必需变量为空，脚本将报错并退出。

## 完整配置示例

```bash
# ==============================================================================
# qt.conf - Qt 版本与源码配置
# ==============================================================================

# Qt 版本
QT_VERSION="6.9.1"

# 源码下载地址（使用清华镜像）
QT_SRC_URL="https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/6.9/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz"

# 源码目录
QT_SRC_DIR="qt-everywhere-src-${QT_VERSION}"

# 工作目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${PROJECT_ROOT}/qt-workdir"

# Qt 模块
QT_MODULES="qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat"

# 编译开关
BUILD_HOST_QT=true
BUILD_TARGET_QT=true
```

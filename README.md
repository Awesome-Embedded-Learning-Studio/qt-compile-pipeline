# Qt 交叉编译管道

<div align="center">

![Qt](https://img.shields.io/badge/Qt-6.9.1-41CD52?logo=qt)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-orange)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25)

**自动化 Qt6 交叉编译解决方案**

[快速开始](#-快速开始) • [配置指南](#-配置指南) • [文档](document/)

</div>

---

## ✨ 简介

> **定位**：作为其他仓库的 third-party 引入，提供预编译 Qt6 产物，规避交叉编译时现场编译的复杂性。
>
> **原则**：配置极薄，不造轮子——所有 configure 参数直接透传 Qt 官方 CMake，封装层为零。

### 核心特性

| 特性 | 说明 |
|------|------|
| 🔧 **配置极简** | 只需修改 `config/` 目录下的配置文件 |
| 📦 **一键构建** | 运行 `build.sh` 完成全流程 |
| 🔄 **幂等设计** | 已存在的产物自动跳过，支持断点续传 |
| 🎯 **多平台支持** | 支持 Host Qt 和 Target Qt 交叉编译 |
| 📦 **自动打包** | 生成 .tar.xz 压缩包和 SHA256 校验和 |
| 🔌 **第三方库** | 内置 tslib、PulseAudio、FFmpeg、OpenSSL |

### 适用场景

- **嵌入式 Linux 开发** - ARM、ARM64
- **特定 Qt 版本** - 需要定制化编译特定版本
- **CI/CD 集成** - 自动化构建流水线
- **团队协作** - 统一编译环境，避免"在我机器上能跑"

---

## 🚀 快速开始

### 前置要求

- **操作系统**: Ubuntu 20.04+ 或其他 Linux 发行版
- **磁盘空间**: 至少 20GB 可用空间
- **内存**: 建议 8GB+

### 1️⃣ 安装依赖

```bash
sudo bash scripts/install-host-deps.sh
```

### 2️⃣ 配置 Qt 版本

编辑 `config/qt.conf`：

```bash
QT_VERSION="6.9.1"
QT_SRC_URL="https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-${QT_VERSION}.tar.xz"
```

### 3️⃣ 开始构建

```bash
# 构建 Host Qt
bash build.sh

# 构建交叉编译 Qt (需要先配置 toolchain.conf 和 target.conf)
BUILD_TARGET_QT=true bash build.sh
```

### 4️⃣ 使用产物

```bash
# 解压到目标目录
tar -xJf qt-workdir/artifacts/qt6-host-*.tar.xz -C /opt/

# 在下游项目中使用
cmake -DCMAKE_PREFIX_PATH=/opt/qt6-host ..
```


---

## ⚙️ 配置指南

### config/qt.conf - Qt 核心配置

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `QT_VERSION` | Qt 版本号 | `6.9.1` |
| `QT_SRC_URL` | 源码下载地址 | Qt 官方地址 |
| `QT_MODULES` | 要编译的模块 | `qtbase qtdeclarative ...` |
| `BUILD_HOST_QT` | 是否编译 Host Qt | `true` |
| `BUILD_TARGET_QT` | 是否编译 Target Qt | `true` |

### config/target.conf - 交叉编译配置

| 变量 | 说明 |
|------|------|
| `QT_TARGET_PLATFORM` | Qt mkspec 名称 |
| `TARGET_RENDER_BACKENDS` | 渲染后端配置 |

**渲染后端选择**：

| 场景 | 关键 Feature |
|------|-------------|
| 裸 Framebuffer | `FEATURE_linuxfb=ON`, `FEATURE_eglfs=OFF` |
| EGLFS（GPU 直出） | `FEATURE_eglfs=ON`, `FEATURE_linuxfb=OFF` |
| X11 桌面 | `FEATURE_xcb=ON` |
| Wayland | `FEATURE_wayland=ON` + 添加 `qtwayland` 模块 |

### config/toolchain.conf - 工具链配置

| 变量 | 说明 |
|------|------|
| `TOOLCHAIN_URL` | 工具链下载 URL（留空使用本地） |
| `TOOLCHAIN_ROOT` | 工具链根目录 |
| `TOOLCHAIN_PREFIX` | 编译器前缀（如 `arm-linux-gnueabihf-`） |

---

## 📦 系统要求

### Host Qt 编译

- CMake >= 3.22
- Ninja
- Perl
- 开发库：OpenGL、FontConfig、FreeType、X11 等

### Target Qt 交叉编译

- 交叉编译工具链（gcc/g++）
- 对应架构的开发库

---

## 🔧 常用命令

```bash
# 设置并行编译线程数
export PARALLEL_JOBS=8

# 仅编译 Host Qt
BUILD_TARGET_QT=false bash build.sh

# 仅编译 Target Qt（跳过 Host Qt）
BUILD_HOST_QT=false BUILD_TARGET_QT=true bash build.sh

# 清理重新构建
rm -rf qt-workdir/
bash build.sh

# 安装第三方库
bash scripts/third_party/manager.sh install
bash scripts/third_party/manager.sh status
```

---

## 📚 文档

| 文档 | 描述 |
|------|------|
| [01-项目介绍](document/01-项目介绍/) | 项目定位、核心功能、适用场景 |
| [02-快速开始](document/02-快速开始/) | 详细安装步骤和验证方法 |
| [03-配置指南](document/03-配置指南/) | 各配置文件的详细说明 |
| [04-第三方依赖](document/04-第三方依赖/) | 现有依赖列表和添加新依赖教程 |
| [05-构建流程](document/05-构建流程/) | 7 阶段构建流程详解 |
| [06-部署使用](document/06-部署使用/) | 部署到设备和项目集成 |
| [07-常见问题](document/07-常见问题/) | FAQ 和故障排查 |

---

## ❓ 常见问题

<details>
<summary><b>Q: 如何只编译 Host Qt？</b></summary>

保持 `config/qt.conf` 中 `BUILD_TARGET_QT=false`，直接运行 `build.sh`。
</details>

<details>
<summary><b>Q: 编译失败如何重试？</b></summary>

脚本支持幂等操作，可以直接重新运行 `build.sh`，已完成的步骤会自动跳过。
</details>

<details>
<summary><b>Q: OpenGL 相关错误怎么办？</b></summary>

安装 OpenGL 开发包：
```bash
sudo apt install -y libgl-dev libglvnd-dev libglx-dev libgles-dev
```

或在配置中禁用 OpenGL：`-DFEATURE_opengl=OFF`
</details>

<details>
<summary><b>Q: 如何使用本地工具链？</b></summary>

在 `config/toolchain.conf` 中留空 `TOOLCHAIN_URL`，设置正确的 `TOOLCHAIN_ROOT` 和 `TOOLCHAIN_PREFIX`。
</details>

<details>
<summary><b>Q: 支持哪些 Qt 模块？</b></summary>

Qt6 官方所有模块，常用包括：
- `qtbase` - 核心模块（必需）
- `qtdeclarative` - QML/Quick
- `qtmultimedia` - 多媒体
- `qtcharts` - 图表
- `qtserialport` - 串口
- `qtvirtualkeyboard` - 虚拟键盘
- `qt5compat` - Qt 5 兼容层

详见 [Qt 官方文档](https://doc.qt.io/qt-6/qtmodules.html)
</details>

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

在提交 PR 前，请确保：
1. 代码符合项目的编码风格
2. 添加必要的注释和文档
3. 测试通过

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

**注意**：本项目编译产物包含 Qt 框架，Qt 遵循 [LGPLv3](https://www.qt.io/licensing) 或商业协议。请根据你的使用场景遵守 Qt 的许可条款。

---

## 🔗 相关链接

- [Qt 官方文档](https://doc.qt.io/qt-6/)
- [Qt 配置选项参考](https://doc.qt.io/qt-6/configure-options.html)
- [Qt 交叉编译指南](https://doc.qt.io/qt-6/embedded-linux.html)
- [开源 README 最佳实践](https://github.com/othneildrew/Best-README-Template)

---

<div align="center">

**[⬆ 返回顶部](#qt-交叉编译管道)**

Made with ❤️ for embedded developers

</div>

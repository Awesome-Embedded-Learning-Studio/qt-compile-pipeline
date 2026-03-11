# 快速开始

本指南将帮助您在最短时间内完成 Qt 交叉编译管道的配置和构建。

## 最小化配置步骤

### 1. 安装系统依赖

```bash
sudo bash scripts/install-host-deps.sh
```

或手动安装关键依赖：

```bash
sudo apt install -y build-essential cmake ninja-build perl ccache \
    libgl-dev libglvnd-dev libglx-dev libgles-dev libdrm-dev libegl1-mesa-dev \
    libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libx11-dev libxkbcommon-dev \
    libxcb1-dev libxcb-util-dev libxcb-xinerama0 libxcb-cursor0 \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    libasound2-dev libpulse-dev libicu-dev libpcre2-dev libsqlite3-dev
```

详细的环境准备说明请参考 [环境准备.md](./环境准备.md)。

### 2. 配置 Qt 版本和源码

编辑 `config/qt.conf`，设置 Qt 版本和源码地址：

```bash
# config/qt.conf
QT_VERSION="6.9.1"
QT_SRC_URL="https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-${QT_VERSION}.tar.xz"
```

### 3. 配置编译选项

根据需要编辑以下配置文件：

- `config/host.conf` - Host Qt 编译配置
- `config/target.conf` - Target Qt 交叉编译配置
- `config/toolchain.conf` - 交叉编译工具链配置

## 运行构建

### 构建 Host Qt

```bash
bash build.sh
```

### 构建 Target Qt（交叉编译）

首先配置 `config/toolchain.conf` 和 `config/target.conf`，然后：

```bash
BUILD_TARGET_QT=true bash build.sh
```

## 验证构建结果

构建完成后，产物位于 `${WORK_DIR}/artifacts/` 目录：

```bash
# 查看产物目录
ls -la ${WORK_DIR}/artifacts/

# 示例输出：
# qt6-host-6.9.1-linux-x86_64.tar.xz
# qt6-host-6.9.1-linux-x86_64.tar.xz.sha256
# qt6-target-6.9.1-linux-arm-gnueabihf.tar.xz
# qt6-target-6.9.1-linux-arm-gnueabihf.tar.xz.sha256
```

验证 SHA256 校验和：

```bash
sha256sum -c qt6-host-6.9.1-linux-x86_64.tar.xz.sha256
```

测试解压：

```bash
tar -xJf qt6-host-6.9.1-linux-x86_64.tar.xz -C /tmp/
ls /tmp/qt6-host-6.9.1-linux-x86_64/
```

## 在下游项目中使用

```bash
# 解压到目标目录
tar -xJf qt6-host-6.9.1-linux-x86_64.tar.xz -C /opt/

# 在下游项目中使用
cmake -DCMAKE_PREFIX_PATH=/opt/qt6-host-6.9.1-linux-x86_64 ..
```

## 下一步

- [环境准备](./环境准备.md) - 详细的系统要求和依赖安装
- [配置说明](../03-配置说明/) - 深入了解各种配置选项
- [常见问题](../05-常见问题/) - 解决构建过程中的常见问题

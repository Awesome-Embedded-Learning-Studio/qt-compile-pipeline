# 部署到目标设备

本文档介绍如何将编译好的 Qt 部署到目标设备并正确配置环境。

## 解压 tar.xz 包到目标设备

### 传输文件

首先将编译好的 Qt 包传输到目标设备：

```bash
# 使用 scp 传输
scp qt-6.8.1-linux-x64.tar.xz user@target-device:/opt/

# 或使用 rsync 传输（支持断点续传）
rsync -avz --progress qt-6.8.1-linux-x64.tar.xz user@target-device:/opt/
```

### 解压安装

在目标设备上解压：

```bash
# SSH 登录到目标设备
ssh user@target-device

# 解压到目标目录
cd /opt
tar -xf qt-6.8.1-linux-x64.tar.xz

# 可选：创建软链接便于版本切换
ln -s qt-6.8.1 qt
```

解压后的目录结构：

```
/opt/qt-6.8.1/
├── bin/           # 可执行文件（qmake, qtb等）
├── lib/           # 库文件
├── plugins/       # Qt 插件
├── qml/           # QML 模块
├── include/       # 头文件
├── mkspecs/       # qmake 规范文件
├── cmake/         # CMake 配置文件
└── translations/  # 翻译文件
```

## 设置环境变量

### 临时设置（当前终端会话）

```bash
# 设置 Qt 安装路径
export QT_HOME=/opt/qt-6.8.1

# 添加可执行文件到 PATH
export PATH=$QT_HOME/bin:$PATH

# 设置库文件搜索路径
export LD_LIBRARY_PATH=$QT_HOME/lib:$LD_LIBRARY_PATH

# 设置 Qt 插件路径
export QT_PLUGIN_PATH=$QT_HOME/plugins

# 设置 QML 导入路径
export QML_IMPORT_PATH=$QT_HOME/qml
```

### 永久设置

#### 方法一：用户级别配置

编辑 `~/.bashrc` 或 `~/.zshrc`：

```bash
# Qt 6.8.1 环境变量
export QT_HOME=/opt/qt-6.8.1
export PATH=$QT_HOME/bin:$PATH
export LD_LIBRARY_PATH=$QT_HOME/lib:$LD_LIBRARY_PATH
export QT_PLUGIN_PATH=$QT_HOME/plugins
export QML_IMPORT_PATH=$QT_HOME/qml

# CMake 前缀路径（可选）
export CMAKE_PREFIX_PATH=$QT_HOME:$CMAKE_PREFIX_PATH
```

使配置生效：

```bash
source ~/.bashrc
# 或
source ~/.zshrc
```

#### 方法二：系统级别配置

创建 `/etc/profile.d/qt.sh`：

```bash
sudo tee /etc/profile.d/qt.sh > /dev/null << 'EOF'
# Qt 6.8.1 系统环境变量
export QT_HOME=/opt/qt-6.8.1
export PATH=$QT_HOME/bin:$PATH
export LD_LIBRARY_PATH=$QT_HOME/lib:$LD_LIBRARY_PATH
export QT_PLUGIN_PATH=$QT_HOME/plugins
export QML_IMPORT_PATH=$QT_HOME/qml
export CMAKE_PREFIX_PATH=$QT_HOME:$CMAKE_PREFIX_PATH
EOF
```

重新登录或执行：

```bash
source /etc/profile.d/qt.sh
```

#### 方法三：ld.so.conf 配置

将 Qt 库路径添加到系统库搜索路径：

```bash
sudo tee /etc/ld.so.conf.d/qt.conf > /dev/null << 'EOF'
/opt/qt-6.8.1/lib
EOF

# 更新动态链接库缓存
sudo ldconfig
```

## 验证 Qt 安装

### 基本验证

```bash
# 检查 qmake 版本
qmake --version

# 检查 qtb（Qt Bootstrapping Tool）
qtb --version

# 检查 Qt 配置
qt-config
```

预期输出示例：

```
QMake version 3.1+
Using Qt version 6.8.1 in /opt/qt-6.8.1/lib
```

### 编译测试程序

创建测试文件 `test_qt.cpp`：

```cpp
#include <QCoreApplication>
#include <QDebug>
#include <QtGlobal>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    qDebug() << "Qt version:" << QT_VERSION_STR;
    qDebug() << "Qt is working correctly!";

    return 0;
}
```

编译并运行：

```bash
# 使用 qmake
qmake -project
qmake
make
./test_qt

# 或直接使用 g++
g++ -o test_qt test_qt.cpp -I/opt/qt-6.8.1/include \
    -L/opt/qt-6.8.1/lib -lQt6Core -Wl,-rpath,/opt/qt-6.8.1/lib
./test_qt
```

### CMake 验证

创建 `CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.16)
project(QtTest)

find_package(Qt6 REQUIRED COMPONENTS Core)

add_executable(test_qt test_qt.cpp)
target_link_libraries(test_qt Qt6::Core)
```

编译：

```bash
cmake -DCMAKE_PREFIX_PATH=/opt/qt-6.8.1 .
cmake --build .
./test_qt
```

## 常见部署问题

### 问题 1：找不到共享库

**错误信息：**

```
error while loading shared libraries: libQt6Core.so.6:
cannot open shared object file: No such file or directory
```

**解决方案：**

```bash
# 临时解决
export LD_LIBRARY_PATH=/opt/qt-6.8.1/lib:$LD_LIBRARY_PATH

# 永久解决 - 添加到 ld.so.conf
echo "/opt/qt-6.8.1/lib" | sudo tee /etc/ld.so.conf.d/qt.conf
sudo ldconfig
```

### 问题 2：找不到 Qt 插件

**错误信息：**

```
Failed to load platform plugin "xcb"
```

**解决方案：**

```bash
export QT_PLUGIN_PATH=/opt/qt-6.8.1/plugins
```

或在代码中设置：

```cpp
QCoreApplication::addLibraryPath("/opt/qt-6.8.1/plugins");
```

### 问题 3：QML 模块找不到

**错误信息：**

```
module "QtQuick" is not installed
```

**解决方案：**

```bash
export QML_IMPORT_PATH=/opt/qt-6.8.1/qml
```

或在 qmlproject/qmldir 中添加：

```qml
import "/opt/qt-6.8.1/qml" as QtRoot
```

### 问题 4：权限问题

如果需要多用户访问，调整权限：

```bash
sudo chown -R root:root /opt/qt-6.8.1
sudo chmod -R 755 /opt/qt-6.8.1
```

### 问题 5：磁盘空间不足

清理不必要的文件：

```bash
# 删除调试符号（如果不需要调试）
find /opt/qt-6.8.1/lib -name "*.a" -delete
find /opt/qt-6.8.1/lib -name "lib*.so.*.*.*" -type f -exec strip --strip-debug {} \;

# 删除示例和文档（可选）
rm -rf /opt/qt-6.8.1/examples
rm -rf /opt/qt-6.8.1/doc
```

### 问题 6：架构不匹配

确认目标设备架构：

```bash
# 检查目标设备架构
uname -m

# 检查库文件架构
file /opt/qt-6.8.1/lib/libQt6Core.so.6
```

常见架构：
- `x86_64` - 64位 Intel/AMD
- `aarch64` - 64位 ARM
- `armv7l` - 32位 ARM

## 嵌入式设备特殊注意事项

### 交叉编译环境

对于嵌入式设备，需要使用交叉编译工具链：

```bash
# 设置交叉编译工具链
export CC=arm-linux-gnueabihf-gcc
export CXX=arm-linux-gnueabihf-g++
export RANLIB=arm-linux-gnueabihf-ranlib
export STRIP=arm-linux-gnueabihf-strip

# 设置 sysroot
export SYSROOT=/path/to/sysroot
export CFLAGS="--sysroot=$SYSROOT"
export CXXFLAGS="--sysroot=$SYSROOT"
export LDFLAGS="--sysroot=$SYSROOT"
```

### 瘦身部署

对于存储空间有限的设备：

```bash
# 只复制运行时必需的文件
mkdir -p qt-runtime
cp -r qt/lib/libQt6*.so.* qt-runtime/lib/
cp -r qt/plugins/platforms qt-runtime/plugins/
cp -r qt/qml/QtQuick qt-runtime/qml/
```

## 下一步

部署完成后，参考 [在项目中使用编译好的 Qt](./在项目中使用.md) 了解如何在你的项目中配置和使用 Qt。

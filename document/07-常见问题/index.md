# 常见问题 (FAQ)

本文档列出了 Qt 交叉编译流水线使用过程中的常见问题和解决方案。

## 构建问题

### 编译失败如何重试？

**问题：** 编译过程中失败，如何重新开始？

**解决方案：**

1. **从断点继续**（推荐）：
   ```bash
   # 流水线支持增量构建，直接重新运行即可
   ./build.sh
   ```

2. **清理并重新构建**：
   ```bash
   # 清理构建产物
   rm -rf build/

   # 重新构建
   ./build.sh
   ```

3. **仅重试特定阶段**：
   编辑 `config/build.conf`，调整 `START_STAGE` 和 `END_STAGE` 参数。

---

### 如何只编译 Host Qt 或 Target Qt？

**问题：** 不需要完整构建，只想编译特定部分？

**解决方案：**

1. **仅编译 Host Qt**（用于开发工具）：
   ```bash
   # 编辑 config/build.conf
   BUILD_TARGET_QT="off"
   BUILD_HOST_QT="on"
   ```

2. **仅编译 Target Qt**（交叉编译到目标平台）：
   ```bash
   # 编辑 config/build.conf
   BUILD_HOST_QT="off"
   BUILD_TARGET_QT="on"
   ```

3. **跳过 Host Qt**（如果有预编译版本）：
   ```bash
   # 设置已安装的 Host Qt 路径
   HOST_QT_PATH="/path/to/existing/qt"
   BUILD_HOST_QT="off"
   ```

---

### 如何清理重新构建？

**问题：** 需要完全清理并从头开始构建？

**解决方案：**

```bash
# 完全清理
./build.sh --clean

# 或手动清理
rm -rf build/
rm -rf install/
rm -rf downloads/

# 清理特定组件
rm -rf build/qt-host/
rm -rf build/qt-target/
```

---

## 配置问题

### 如何修改 Qt 版本？

**问题：** 需要使用不同版本的 Qt？

**解决方案：**

1. **修改配置文件**：
   编辑 `config/qt.conf`：
   ```ini
   [qt]
   version = "6.7.2"
   # 或
   version = "6.8.0"
   ```

2. **使用特定版本**：
   ```bash
   # 在命令行指定版本
   ./build.sh --qt-version 6.7.2
   ```

3. **使用自定义 Qt 源码**：
   ```ini
   [qt]
   source_type = "local"
   source_path = "/path/to/qt/source"
   ```

---

### 如何启用/禁用 Qt 模块？

**问题：** 不需要某些 Qt 模块，想自定义构建？

**解决方案：**

1. **编辑配置文件** `config/qt.conf`：
   ```ini
   [qt]
   # 启用的模块
   enabled_modules = [
       "qtbase",
       "qtdeclarative",
       "qtsvg",
       "qtimageformats"
   ]

   # 排除的模块
   excluded_modules = [
       "qtwebengine",
       "qt3d",
       "qtvirtualkeyboard"
   ]
   ```

2. **常用模块说明**：
   - `qtbase`：核心模块（必需）
   - `qtdeclarative`：QML/Quick 支持
   - `qtsvg`：SVG 图形支持
   - `qtwebengine`：Web 浏览器引擎（构建时间长）

---

### 如何更改目标平台？

**问题：** 需要交叉编译到不同的目标平台？

**解决方案：**

1. **选择预定义平台**：
   编辑 `config/platform.conf`：
   ```ini
   [platform]
   target = "imx8mm"
   # 可选值: imx8mm, imx8mp, rk3588, am335x, etc.
   ```

2. **配置自定义平台**：
   编辑 `config/toolchain.conf`：
   ```ini
   [toolchain]
   triplet = "arm-linux-gnueabihf"
   arch = "arm"
   ```

3. **切换平台后清理**：
   ```bash
   ./build.sh --clean
   ./build.sh
   ```

---

## 工具链问题

### 工具链找不到

**问题：** 提示 "toolchain not found" 或类似错误？

**解决方案：**

1. **检查工具链路径**：
   ```bash
   # 验证工具链目录存在
   ls -la /opt/toolchain/

   # 或检查配置
   cat config/toolchain.conf
   ```

2. **设置工具链路径**：
   编辑 `config/toolchain.conf`：
   ```ini
   [toolchain]
   path = "/opt/custom-toolchain"
   ```

3. **设置环境变量**：
   ```bash
   export TOOLCHAIN_PATH="/opt/toolchain-arm"
   ./build.sh
   ```

---

### 如何验证工具链正确性？

**问题：** 确认交叉编译工具链是否配置正确？

**解决方案：**

```bash
# 1. 检查编译器版本
${TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-gcc --version

# 2. 检查 sysroot
ls -la ${TOOLCHAIN_PATH}/arm-linux-gnueabihf/sysroot/

# 3. 测试简单编译
cat > test.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello Cross\n");
    return 0;
}
EOF

${TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-gcc test.c -o test-arm
file test-arm
# 应显示：ARM 架构的可执行文件

# 4. 检查工具链完整性
./scripts/verify-toolchain.sh
```

---

## 依赖问题

### OpenGL 相关错误

**问题：** 编译时提示 OpenGL 或 EGL 相关错误？

**解决方案：**

1. **检查 OpenGL 库**：
   ```bash
   # 查找 OpenGL 库
   find ${TOOLCHAIN_PATH} -name "libGL*"
   find ${TOOLCHAIN_PATH} -name "libEGL*"
   ```

2. **配置 OpenGL 选项**：
   编辑 `config/qt.conf`：
   ```ini
   [qt]
   # 禁用 OpenGL（如果目标平台不支持）
   opengl = "no"

   # 或指定具体后端
   opengl = "dynamic"
   ```

3. **使用软件渲染**：
   ```ini
   [qt]
   opengl = "desktop"
   linuxfb = "yes"
   ```

---

### 第三方库编译失败

**问题：** Qt 依赖的第三方库（如 openssl, libjpeg）编译失败？

**解决方案：**

1. **使用系统预装库**：
   ```ini
   [qt]
   # 使用系统的 OpenSSL
   openssl = "runtime"
   ```

2. **指定第三方库路径**：
   ```ini
   [dependencies]
   openssl_path = "/usr/local/openssl-arm"
   jpeg_path = "/usr/local/libjpeg-arm"
   ```

3. **禁用不必要的功能**：
   ```ini
   [qt]
   # 减少依赖
   libjpeg = "no"
   libpng = "qt"
   ```

---

## 运行时问题

### 找不到共享库

**问题：** 在目标设备上运行时提示找不到共享库？

**解决方案：**

1. **检查依赖**：
   ```bash
   # 在开发机上检查
   ${TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-readelf -d app | grep NEEDED

   # 或使用 ldd（如果可用）
   ${TOOLCHAIN_PATH}/bin/arm-linux-gnueabihf-ldd ./app
   ```

2. **设置库路径**（在目标设备上）：
   ```bash
   # 临时设置
   export LD_LIBRARY_PATH=/opt/qt/lib:$LD_LIBRARY_PATH

   # 永久设置（添加到 /etc/profile）
   echo 'export LD_LIBRARY_PATH=/opt/qt/lib:$LD_LIBRARY_PATH' >> /etc/profile
   ```

3. **使用 RPATH**：
   编辑 `config/qt.conf`：
   ```ini
   [qt]
   rpath = "/opt/qt/lib"
   ```

---

### 插件加载失败

**问题：** Qt 插件（如平台插件、图像格式插件）加载失败？

**解决方案：**

1. **设置插件路径**：
   ```bash
   # 在目标设备上
   export QT_PLUGIN_PATH=/opt/qt/plugins
   ```

2. **检查插件目录**：
   ```bash
   ls -la /opt/qt/plugins/platforms/
   # 应包含 libqeglfs.so, libqlinuxfb.so 等
   ```

3. **调试插件加载**：
   ```bash
   # 启用插件调试输出
   export QT_DEBUG_PLUGINS=1
   ./your_app
   ```

4. **配置 qt.conf**（在应用目录下创建）：
   ```ini
   [Paths]
   Plugins=/opt/qt/plugins
   ```

---

### 触摸屏/显示问题

**问题：** 触摸屏不工作或显示异常？

**解决方案：**

1. **指定平台插件**：
   ```bash
   # 使用特定的平台后端
   export QT_QPA_PLATFORM=eglfs
   # 或
   export QT_QPA_PLATFORM=linuxfb
   ```

2. **配置触摸设备**：
   ```bash
   # 指定触摸设备
   export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS=/dev/input/event0
   ```

3. **环境变量配置**：
   ```bash
   # 禁用鼠标光标
   export QT_QPA_EGLFS_DISABLE_INPUT=1

   # 设置屏幕尺寸
   export QT_QPA_EGLFS_WIDTH=800
   export QT_QPA_EGLFS_HEIGHT=480
   ```

4. ** tslib 触摸校准**：
   ```bash
   # 使用 tslib 进行触摸校准
   export TSLIB_FBDEVICE=/dev/fb0
   export TSLIB_TSDEVICE=/dev/input/event0
   export QT_QPA_GENERIC_PLUGINS=tslib
   ```

---

## 其他问题

### 查看详细日志

如果遇到问题，可以启用详细日志：

```bash
# 启用 CMake 详细输出
./build.sh --verbose

# 或设置环境变量
export CMAKE_VERBOSE_MAKEFILE=1
./build.sh
```

### 获取帮助

- 查看完整文档：`document/` 目录
- 运行帮助命令：`./build.sh --help`
- 检查配置示例：`config/examples/`

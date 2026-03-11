# Host Qt 配置

Host Qt 是运行在编译主机（通常是 x86_64 Linux）上的 Qt 版本，用于交叉编译 Target Qt 时提供工具（如 qmake、moc、rcc 等）。

## 配置文件位置

```
config/host.conf
```

## 配置项详解

### 依赖检查

```bash
# 此文件依赖 qt.conf 中的 WORK_DIR 变量
: "${WORK_DIR:?Error: WORK_DIR is not set. Please source qt.conf first: source config/qt.conf}"
```

**说明**：确保在使用 `host.conf` 之前已经加载了 `qt.conf`，否则会报错退出。

### 安装路径配置

#### HOST_INSTALL_PREFIX

```bash
HOST_INSTALL_PREFIX="${WORK_DIR}/qt6-host"
```

| 参数 | 说明 |
|------|------|
| 默认值 | `${WORK_DIR}/qt6-host` |
| 作用 | Host Qt 的安装目录 |
| 注意 | 通常使用默认值即可 |

**示例**：

```bash
# 使用默认路径（推荐）
HOST_INSTALL_PREFIX="${WORK_DIR}/qt6-host"

# 自定义路径
HOST_INSTALL_PREFIX="/opt/qt6-host"
```

### 构建类型配置

#### HOST_BUILD_DEBUG

```bash
HOST_BUILD_DEBUG=false
```

| 值 | 说明 |
|----|------|
| `false` | Release 构建（默认，优化体积和速度） |
| `true` | Debug 构建（包含调试符号，便于调试） |

**使用场景**：

```bash
# 生产环境/部署使用（推荐）
HOST_BUILD_DEBUG=false

# 开发调试
HOST_BUILD_DEBUG=true
```

### 额外 Configure 参数

#### HOST_CONFIGURE_EXTRA

```bash
HOST_CONFIGURE_EXTRA="\
  -optimize-size \
  -DFEATURE_sql=OFF \
  -DFEATURE_boringssl=OFF \
  -DFEATURE_openssl=OFF \
"
```

这些参数会原样追加到 `./configure` 命令末尾。

## 常用参数说明

### 构建类型参数

| 参数 | 说明 |
|------|------|
| `-release` | 发行版构建（不含调试符号） |
| `-debug` | 调试版构建 |
| `-debug-and-release` | 同时构建 debug 和 release（仅 Windows） |
| `-optimize-size` | 优化体积而非速度 |
| `-optimize-speed` | 优化速度而非体积 |
| `-force-debug-info` | release 构建包含调试信息 |

### 功能开关参数

使用 `-DFEATURE_xxx=ON/OFF` 格式启用或禁用特定功能：

```bash
# 启用功能
-DFEATURE_sql=ON
-DFEATURE_network=ON
-DFEATURE_printsupport=ON

# 禁用功能
-DFEATURE_sql=OFF
-DFEATURE_boringssl=OFF
-DFEATURE_openssl=OFF
```

## 配置示例

### 最小化配置（推荐）

```bash
HOST_INSTALL_PREFIX="${WORK_DIR}/qt6-host"
HOST_BUILD_DEBUG=false
HOST_CONFIGURE_EXTRA="\
  -optimize-size \
  -DFEATURE_sql=OFF \
  -DFEATURE_openssl=OFF \
"
```

### 开发调试配置

```bash
HOST_INSTALL_PREFIX="${WORK_DIR}/qt6-host-debug"
HOST_BUILD_DEBUG=true
HOST_CONFIGURE_EXTRA="\
  -DFEATURE_sql=ON \
  -DFEATURE_openssl=ON \
  -DFEATURE_printsupport=ON \
"
```

### 完整功能配置

```bash
HOST_INSTALL_PREFIX="${WORK_DIR}/qt6-host-full"
HOST_BUILD_DEBUG=false
HOST_CONFIGURE_EXTRA="\
  -optimize-size \
  -DFEATURE_sql=ON \
  -DFEATURE_network=ON \
  -DFEATURE_printsupport=ON \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
"
```

## 注意事项

1. **配置顺序**：必须先 `source config/qt.conf`，再使用 `host.conf` 中的变量
2. **参数格式**：使用反斜杠 `\` 进行多行续行
3. **引号使用**：整个参数字符串用双引号包裹
4. **官方文档**：更多参数详见 [Qt Configure Options](https://doc.qt.io/qt-6/configure-options.html)

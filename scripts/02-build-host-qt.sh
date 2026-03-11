#!/usr/bin/env bash
# 02-build-host-qt.sh - Host Qt 编译脚本
# 阶段 3：编译并安装 Host Qt（主机版本）
# 使用 Qt 官方推荐的 ./configure 方式进行编译

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/../config/qt.conf"
source "${SCRIPT_DIR}/../config/host.conf"

# ================================================================
# 前置检查
# ================================================================
# 如果不编译 Host Qt，直接跳过
if [[ "${BUILD_HOST_QT}" != "true" ]]; then
    log_info "BUILD_HOST_QT is false, skipping Host Qt build"
    exit 0
fi

# 检查必需命令
require_cmd cmake ninja perl

# 检查源码目录是否存在
SRC_DIR="${WORK_DIR}/src/${QT_SRC_DIR}"
if [[ ! -d "$SRC_DIR" ]]; then
    die "Qt source not found: ${SRC_DIR}"$'\n'\
         "Please run: bash scripts/00-fetch-qt-src.sh"
fi

# ================================================================
# 路径定义
# ================================================================
BUILD_DIR="${WORK_DIR}/build-host"
INSTALL_PREFIX="${HOST_INSTALL_PREFIX}"
CONFIGURE_SCRIPT="${SRC_DIR}/configure"

# ================================================================
# 执行编译
# ================================================================
stage "Stage 3: Build Host Qt (using ./configure)"

log_info "Configuration:"
log_info "  Qt Version: ${QT_VERSION}"
log_info "  Source: ${SRC_DIR}"
log_info "  Build: ${BUILD_DIR}"
log_info "  Install: ${INSTALL_PREFIX}"
log_info "  Modules: ${QT_MODULES}"

# ---------------------------------------------------------------
# 检查是否已经编译过
# ---------------------------------------------------------------
if [[ -f "${INSTALL_PREFIX}/bin/qmake" ]]; then
    log_ok "Host Qt already installed: ${INSTALL_PREFIX}"
    log_info "Skipping build"
    exit 0
fi

# ---------------------------------------------------------------
# 检查 configure 脚本是否存在
# ---------------------------------------------------------------
if [[ ! -x "$CONFIGURE_SCRIPT" ]]; then
    # 如果不可执行，尝试添加执行权限
    if [[ -f "$CONFIGURE_SCRIPT" ]]; then
        log_info "Making configure script executable..."
        chmod +x "$CONFIGURE_SCRIPT"
    else
        die "Configure script not found: ${CONFIGURE_SCRIPT}"
    fi
fi

# ---------------------------------------------------------------
# 准备构建目录
# ---------------------------------------------------------------
log_info "Preparing build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ---------------------------------------------------------------
# 配置 Qt 使用 ./configure
# ---------------------------------------------------------------
log_info "Configuring Qt with ./configure..."

# 构建 configure 命令数组
# Qt 6 configure 脚本推荐参数格式
CONFIGURE_ARGS=(
    "-prefix" "${INSTALL_PREFIX}"
)

# 添加模块列表（如果指定了）
if [[ -n "${QT_MODULES:-}" ]]; then
    # configure 使用逗号分隔模块
    MODULES_LIST="${QT_MODULES// /,}"
    CONFIGURE_ARGS+=("-submodules" "${MODULES_LIST}")
    log_info "Submodules: ${MODULES_LIST}"
fi

# 添加优化/调试配置（从配置文件读取）
if [[ "${HOST_BUILD_DEBUG:-false}" == "true" ]]; then
    CONFIGURE_ARGS+=("-debug")
else
    CONFIGURE_ARGS+=("-release")
fi

# 添加不编译示例和测试（默认）
CONFIGURE_ARGS+=("-nomake" "examples")
CONFIGURE_ARGS+=("-nomake" "tests")

# 添加用户自定义参数（原样展开）
eval "set -- ${HOST_CONFIGURE_EXTRA:-}"
CONFIGURE_ARGS+=("$@")

# 打印完整 configure 命令（便于调试）
log_info "Full configure command (run from build directory):"
echo "${CONFIGURE_SCRIPT} \\"
for arg in "${CONFIGURE_ARGS[@]}"; do
    echo "  ${arg}"
done
echo ""

# 切换到构建目录并运行 configure
cd "${BUILD_DIR}" || die "Failed to enter build directory: ${BUILD_DIR}"

# 执行 configure 脚本
# 注意：configure 会自动调用 CMake 并使用 Ninja
"${CONFIGURE_SCRIPT}" "${CONFIGURE_ARGS[@]}" || die "Configure failed"

# ---------------------------------------------------------------
# 编译
# ---------------------------------------------------------------
log_info "Building Qt..."
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"
log_info "Parallel jobs: ${PARALLEL_JOBS}"

# Qt 官方推荐使用 cmake --build
cmake --build . --parallel "${PARALLEL_JOBS}" \
    || die "Build failed"

# ---------------------------------------------------------------
# 安装
# ---------------------------------------------------------------
log_info "Installing Qt to: ${INSTALL_PREFIX}"
cmake --install . \
    || die "Install failed"

# ---------------------------------------------------------------
# 验证安装
# ---------------------------------------------------------------
log_info "Verifying installation..."
if [[ ! -f "${INSTALL_PREFIX}/bin/qmake" ]]; then
    die "qmake not found after installation"
fi

log_ok "Host Qt installed successfully"
log_info "Qt version info:"
"${INSTALL_PREFIX}/bin/qmake" -v || true

log_info "Installation summary:"
log_info "  Prefix: ${INSTALL_PREFIX}"
log_info "  Bin: ${INSTALL_PREFIX}/bin"
log_info "  Lib: ${INSTALL_PREFIX}/lib"
log_info "  Plugins: ${INSTALL_PREFIX}/plugins"

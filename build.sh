#!/usr/bin/env bash
# build.sh - Qt 编译管道主入口脚本
# 一键执行完整的 Qt 编译流程

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"
source "${SCRIPT_DIR}/config/qt.conf"
# 加载其他配置文件（用于显示安装路径等）
source "${SCRIPT_DIR}/config/host.conf"
source "${SCRIPT_DIR}/config/target.conf"
source "${SCRIPT_DIR}/config/toolchain.conf"

# ================================================================
# 配置联动检查
# ================================================================
# TARGET 强制依赖 HOST
if [[ "${BUILD_TARGET_QT}" == "true" && "${BUILD_HOST_QT}" != "true" ]]; then
    log_warn "BUILD_TARGET_QT=true requires BUILD_HOST_QT=true"
    log_warn "Automatically enabling BUILD_HOST_QT"
    export BUILD_HOST_QT=true
fi

# ================================================================
# 打印配置摘要
# ================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Qt Cross-Compilation Pipeline                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_info "Configuration Summary:"
echo "  Qt Version:      ${QT_VERSION}"
echo "  Source URL:      ${QT_SRC_URL}"
echo "  Work Directory:  ${WORK_DIR}"
echo "  Modules:         ${QT_MODULES}"
echo "  Build Host Qt:   ${BUILD_HOST_QT}"
echo "  Build Target Qt: ${BUILD_TARGET_QT}"
echo ""

# ================================================================
# 顺序执行各阶段脚本
# ================================================================
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# 阶段 1: 获取源码
log_info "Step 1/7: Fetch Qt source"
bash "${SCRIPTS_DIR}/00-fetch-qt-src.sh"
echo ""

# 阶段 2: 获取工具链
log_info "Step 2/7: Fetch toolchain"
bash "${SCRIPTS_DIR}/01-fetch-toolchain.sh"
echo ""

# 阶段 3: 编译 Host Qt
if [[ "${BUILD_HOST_QT}" == "true" ]]; then
    log_info "Step 3/7: Build Host Qt"
    bash "${SCRIPTS_DIR}/02-build-host-qt.sh"
    echo ""
else
    log_info "Step 3/7: Skip Host Qt build (disabled)"
fi

# 阶段 3.5: 重新安装 Target 依赖 (Host Qt 编译后)
if [[ "${BUILD_TARGET_QT}" == "true" ]]; then
    log_info "Step 2.5/7: Install target dependencies (ARM ALSA, etc.)"
    bash "${SCRIPTS_DIR}/install_target_deps.sh" "${TARGET_ARCH:-armhf}"
    echo ""
else
    log_info "Step 2.5/7: Skip target dependencies (BUILD_TARGET_QT=false)"
fi

# 阶段 4: 编译 Target Qt
if [[ "${BUILD_TARGET_QT}" == "true" ]]; then
    log_info "Step 4/7: Build Target Qt"
    bash "${SCRIPTS_DIR}/03-build-target-qt.sh"
    echo ""
else
    log_info "Step 4/7: Skip Target Qt build (disabled)"
fi

# 阶段 5: 打包
log_info "Step 5/7: Package Qt installations"
bash "${SCRIPTS_DIR}/04-package.sh"
echo ""

# ================================================================
# 打印产物摘要
# ================================================================
log_ok "Build pipeline completed!"
echo ""
echo "Installation Paths:"
if [[ "${BUILD_HOST_QT}" == "true" ]]; then
    echo "  Host Qt:   ${HOST_INSTALL_PREFIX}"
fi
if [[ "${BUILD_TARGET_QT}" == "true" ]]; then
    echo "  Target Qt: ${TARGET_INSTALL_PREFIX}"
fi
echo ""

ARTIFACT_DIR="${WORK_DIR}/artifacts"
if [[ -d "$ARTIFACT_DIR" && -n "$(ls -A "$ARTIFACT_DIR" 2>/dev/null)" ]]; then
    echo "Generated Packages:"
    for f in "$ARTIFACT_DIR"/*.tar.xz; do
        if [[ -f "$f" ]]; then
            size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "?")
            name=$(basename "$f")
            echo "  📦 ${name} ($((size / 1024 / 1024)) MB)"
        fi
    done
    echo ""
    log_info "Artifact directory: ${ARTIFACT_DIR}"
fi

echo ""
echo "To use the compiled Qt in your project:"
echo "  cmake -DCMAKE_PREFIX_PATH=<installation_path> .."
echo ""

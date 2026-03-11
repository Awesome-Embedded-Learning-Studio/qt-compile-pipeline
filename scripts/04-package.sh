#!/usr/bin/env bash
# 04-package.sh - Qt 安装包打包脚本
# 阶段 5：将编译好的 Qt 打包为 .tar.xz 并生成校验和

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/../config/qt.conf"
source "${SCRIPT_DIR}/../config/host.conf"
source "${SCRIPT_DIR}/../config/target.conf"
source "${SCRIPT_DIR}/../config/toolchain.conf"

# ================================================================
# 路径定义
# ================================================================
ARTIFACT_DIR="${WORK_DIR}/artifacts"
mkdir -p "${ARTIFACT_DIR}"

# ================================================================
# 执行打包
# ================================================================
stage "Stage 5: Package Qt Installations"

PACKAGED_FILES=()

# ---------------------------------------------------------------
# 打包 Host Qt（如果已编译）
# ---------------------------------------------------------------
if [[ "${BUILD_HOST_QT}" == "true" && -d "${HOST_INSTALL_PREFIX}" ]]; then
    log_info "Packaging Host Qt..."

    HOST_PACKAGE_NAME="qt6-host-${QT_VERSION}-linux-x86_64"
    HOST_ARCHIVE="${ARTIFACT_DIR}/${HOST_PACKAGE_NAME}.tar.xz"

    # 检查是否已经打包过
    if [[ -f "$HOST_ARCHIVE" && -f "${HOST_ARCHIVE}.sha256" ]]; then
        log_ok "Host Qt package already exists: ${HOST_ARCHIVE}"
        PACKAGED_FILES+=("$HOST_ARCHIVE" "${HOST_ARCHIVE}.sha256")
    else
        # 删除旧包
        rm -f "${HOST_ARCHIVE}" "${HOST_ARCHIVE}.sha256"

        log_info "Creating archive: ${HOST_ARCHIVE}"
        tar -cJf "${HOST_ARCHIVE}" \
            -C "$(dirname "${HOST_INSTALL_PREFIX}")" \
            "$(basename "${HOST_INSTALL_PREFIX}")" \
            || die "Failed to create Host Qt archive"

        # 生成 SHA256 校验和
        log_info "Generating SHA256 checksum..."
        (cd "${ARTIFACT_DIR}" && sha256sum "$(basename "${HOST_ARCHIVE}")" > "$(basename "${HOST_ARCHIVE}").sha256")

        log_ok "Host Qt packaged successfully"
        PACKAGED_FILES+=("$HOST_ARCHIVE" "${HOST_ARCHIVE}.sha256")
    fi
fi

# ---------------------------------------------------------------
# 打包 Target Qt（如果已编译）
# ---------------------------------------------------------------
if [[ "${BUILD_TARGET_QT}" == "true" && -d "${TARGET_INSTALL_PREFIX}" ]]; then
    log_info "Packaging Target Qt..."

    # 从 QT_TARGET_PLATFORM 提取平台标识（去掉 g++ 后缀）
    PLATFORM_ID="${QT_TARGET_PLATFORM%-g++}"

    TARGET_PACKAGE_NAME="qt6-target-${QT_VERSION}-${TARGET_ARCH}-${PLATFORM_ID}"
    TARGET_ARCHIVE="${ARTIFACT_DIR}/${TARGET_PACKAGE_NAME}.tar.xz"

    # 检查是否已经打包过
    if [[ -f "$TARGET_ARCHIVE" && -f "${TARGET_ARCHIVE}.sha256" ]]; then
        log_ok "Target Qt package already exists: ${TARGET_ARCHIVE}"
        PACKAGED_FILES+=("$TARGET_ARCHIVE" "${TARGET_ARCHIVE}.sha256")
    else
        # 删除旧包
        rm -f "${TARGET_ARCHIVE}" "${TARGET_ARCHIVE}.sha256"

        log_info "Creating archive: ${TARGET_ARCHIVE}"
        tar -cJf "${TARGET_ARCHIVE}" \
            -C "$(dirname "${TARGET_INSTALL_PREFIX}")" \
            "$(basename "${TARGET_INSTALL_PREFIX}")" \
            || die "Failed to create Target Qt archive"

        # 生成 SHA256 校验和
        log_info "Generating SHA256 checksum..."
        (cd "${ARTIFACT_DIR}" && sha256sum "$(basename "${TARGET_ARCHIVE}")" > "$(basename "${TARGET_ARCHIVE}").sha256")

        log_ok "Target Qt packaged successfully"
        PACKAGED_FILES+=("$TARGET_ARCHIVE" "${TARGET_ARCHIVE}.sha256")
    fi
fi

# ---------------------------------------------------------------
# 打印摘要
# ---------------------------------------------------------------
if [[ ${#PACKAGED_FILES[@]} -eq 0 ]]; then
    log_warn "No Qt installations found to package"
    log_info "Please run the build scripts first:"
    log_info "  bash scripts/02-build-host-qt.sh"
    log_info "  bash scripts/03-build-target-qt.sh"
else
    echo ""
    log_ok "Packaging completed successfully"
    echo ""
    echo "Package Summary:"
    echo "================"
    for file in "${PACKAGED_FILES[@]}"; do
        if [[ "$file" == *.sha256 ]]; then
            echo "📋 $(basename "$file")"
            cat "$file"
        else
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
            echo "📦 $(basename "$file") ($((size / 1024 / 1024)) MB)"
        fi
    done
    echo ""
    log_info "Artifact directory: ${ARTIFACT_DIR}"
fi

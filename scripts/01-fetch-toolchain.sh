#!/usr/bin/env bash
# 01-fetch-toolchain.sh - 交叉编译工具链下载与解压
# 阶段 2：下载并解压交叉编译工具链（可选）

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/../config/qt.conf"
source "${SCRIPT_DIR}/../config/toolchain.conf"

# ================================================================
# 前置检查
# ================================================================
# 如果不编译 Target Qt，直接跳过
if [[ "${BUILD_TARGET_QT}" != "true" ]]; then
    log_info "BUILD_TARGET_QT is false, skipping toolchain fetch"
    exit 0
fi

# ================================================================
# 执行工具链准备
# ================================================================
stage "Stage 2: Fetch Toolchain"

# ----------------------------------------------------------------------
# 情况 A: TOOLCHAIN_URL 为空 - 使用本地工具链
# ----------------------------------------------------------------------
if [[ -z "${TOOLCHAIN_URL:-}" ]]; then
    log_info "TOOLCHAIN_URL is empty, using local toolchain"
    log_info "TOOLCHAIN_ROOT: ${TOOLCHAIN_ROOT}"

    if [[ ! -d "${TOOLCHAIN_ROOT}" ]]; then
        die "Local toolchain not found: ${TOOLCHAIN_ROOT}"$'\n'\
             "Please either:"$'\n'\
             "  1. Set TOOLCHAIN_URL in config/toolchain.conf to download"$'\n'\
             "  2. Install toolchain to: ${TOOLCHAIN_ROOT}"
    fi

    log_ok "Local toolchain found"

    # 解析 TOOLCHAIN_BIN_DIR
    if [[ -z "${TOOLCHAIN_BIN_DIR:-}" ]]; then
        TOOLCHAIN_BIN_DIR="$(auto_detect_toolchain_bin "${TOOLCHAIN_ROOT}" "${TOOLCHAIN_PREFIX}")"
        log_info "Auto-detected TOOLCHAIN_BIN_DIR: ${TOOLCHAIN_BIN_DIR}"
    fi

    # 验证工具链可执行文件
    gcc_path="${TOOLCHAIN_BIN_DIR}/${TOOLCHAIN_PREFIX}gcc"
    if [[ ! -x "$gcc_path" ]]; then
        die "Toolchain gcc not executable: ${gcc_path}"
    fi

    log_ok "Toolchain gcc verified: ${gcc_path}"
    log_info "Toolchain version:"
    "$gcc_path" --version | head -n 1

    exit 0
fi

# ----------------------------------------------------------------------
# 情况 B: TOOLCHAIN_URL 非空 - 下载工具链
# ----------------------------------------------------------------------
log_info "Downloading toolchain from: ${TOOLCHAIN_URL}"

# 创建工具链下载目录
TOOLCHAIN_DL_DIR="${WORK_DIR}/toolchain-dl"
mkdir -p "${TOOLCHAIN_DL_DIR}"

# 下载
ARCHIVE_NAME="$(basename "${TOOLCHAIN_URL}")"
ARCHIVE_PATH="${TOOLCHAIN_DL_DIR}/${ARCHIVE_NAME}"

download_file "${TOOLCHAIN_URL}" "${ARCHIVE_PATH}"

# 解压（使用 --strip-components=1 去除顶层目录）
log_info "Extracting toolchain to: ${TOOLCHAIN_ROOT}"
mkdir -p "${TOOLCHAIN_ROOT}"

# 根据压缩包类型解压
case "$ARCHIVE_PATH" in
    *.tar.xz|*.txz)
        tar -xJf "$ARCHIVE_PATH" --strip-components=1 -C "${TOOLCHAIN_ROOT}" \
            || die "Failed to extract toolchain archive"
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$ARCHIVE_PATH" --strip-components=1 -C "${TOOLCHAIN_ROOT}" \
            || die "Failed to extract toolchain archive"
        ;;
    *.tar.bz2|*.tbz)
        tar -xjf "$ARCHIVE_PATH" --strip-components=1 -C "${TOOLCHAIN_ROOT}" \
            || die "Failed to extract toolchain archive"
        ;;
    *.zip)
        # unzip 不支持 --strip-components，需要手动处理
        local temp_extract="${TOOLCHAIN_DL_DIR}/temp_extract"
        mkdir -p "$temp_extract"
        unzip -q "$ARCHIVE_PATH" -d "$temp_extract" \
            || die "Failed to extract toolchain archive"

        # 移动第一个子目录的内容到 TOOLCHAIN_ROOT
        local first_dir=$(find "$temp_extract" -maxdepth 1 -type d ! -name "$temp_extract" | head -n 1)
        if [[ -n "$first_dir" ]]; then
            mv "$first_dir"/* "$first_dir"/.* "$TOOLCHAIN_ROOT" 2>/dev/null || true
            rm -rf "$temp_extract"
        else
            die "Failed to process zip archive structure"
        fi
        ;;
    *)
        die "Unsupported archive format: ${ARCHIVE_PATH}"
        ;;
esac

log_ok "Toolchain extracted successfully"

# 解析 TOOLCHAIN_BIN_DIR
if [[ -z "${TOOLCHAIN_BIN_DIR:-}" ]]; then
    TOOLCHAIN_BIN_DIR="$(auto_detect_toolchain_bin "${TOOLCHAIN_ROOT}" "${TOOLCHAIN_PREFIX}")"
    log_info "Auto-detected TOOLCHAIN_BIN_DIR: ${TOOLCHAIN_BIN_DIR}"
fi

# 验证工具链
gcc_path="${TOOLCHAIN_BIN_DIR}/${TOOLCHAIN_PREFIX}gcc"
if [[ ! -x "$gcc_path" ]]; then
    die "Toolchain gcc not found or not executable: ${gcc_path}"
fi

log_ok "Toolchain gcc verified: ${gcc_path}"
log_info "Toolchain version:"
"$gcc_path" --version | head -n 1

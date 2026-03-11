#!/usr/bin/env bash
# 00-fetch-qt-src.sh - Qt 源码下载与解压
# 阶段 1：下载并解压 Qt 源码包

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/../config/qt.conf"

# ================================================================
# 前置检查
# ================================================================
# 检查 QT_SRC_URL 是否已配置
if [[ -z "${QT_SRC_URL:-}" ]]; then
    die "QT_SRC_URL is empty. Please edit config/qt.conf and set QT_SRC_URL"
fi

# ================================================================
# 路径定义
# ================================================================
SRC_DIR="${WORK_DIR}/src"
ARCHIVE_NAME="$(basename "$QT_SRC_URL")"
ARCHIVE_PATH="${SRC_DIR}/${ARCHIVE_NAME}"
EXTRACTED_SRC_PATH="${SRC_DIR}/${QT_SRC_DIR}"

# ================================================================
# 中断清理函数
# ================================================================
_cleanup_fetch() {
    log_warn "Interrupted! Cleaning up..."

    # 清理下载中的临时文件
    rm -f "${ARCHIVE_PATH}.download."*

    # 如果解压目录不完整，删除它
    if [[ -d "$EXTRACTED_SRC_PATH" ]]; then
        # 检查是否有核心文件（如 CMakeLists.txt）
        if [[ ! -f "${EXTRACTED_SRC_PATH}/CMakeLists.txt" ]]; then
            log_warn "Removing incomplete extraction: $EXTRACTED_SRC_PATH"
            rm -rf "$EXTRACTED_SRC_PATH"
        fi
    fi

    # 如果压缩包不存在或不完整，删除
    if [[ -f "$ARCHIVE_PATH" ]] && [[ ! -s "$ARCHIVE_PATH" ]]; then
        rm -f "$ARCHIVE_PATH"
    fi
}

# 注册中断处理
# 注意：不捕获 EXIT，否则正常退出也会触发清理
trap _cleanup_fetch INT TERM

# ================================================================
# 执行下载与解压
# ================================================================
stage "Stage 1: Fetch Qt Source"

log_info "Qt version: ${QT_VERSION}"
log_info "Source URL: ${QT_SRC_URL}"

# 检查源码是否已存在
if [[ -d "$EXTRACTED_SRC_PATH" ]]; then
    # 验证完整性
    if [[ -f "${EXTRACTED_SRC_PATH}/CMakeLists.txt" ]]; then
        log_ok "Qt source already exists: ${EXTRACTED_SRC_PATH}"
        log_info "Skipping download and extraction"
        exit 0
    else
        log_warn "Incomplete source directory found, removing: $EXTRACTED_SRC_PATH"
        rm -rf "$EXTRACTED_SRC_PATH"
    fi
fi

# 下载源码压缩包
download_file "$QT_SRC_URL" "$ARCHIVE_PATH"

# 解压源码
log_info "Extracting Qt source..."
extract_archive "$ARCHIVE_PATH" "$SRC_DIR"

# 验证解压后的目录
if [[ ! -d "$EXTRACTED_SRC_PATH" ]]; then
    die "Source directory not found after extraction: ${EXTRACTED_SRC_PATH}"
fi

# 验证源码完整性（检查 CMakeLists.txt）
if [[ ! -f "${EXTRACTED_SRC_PATH}/CMakeLists.txt" ]]; then
    die "Source extraction incomplete: CMakeLists.txt not found"
fi

log_ok "Qt source ready: ${EXTRACTED_SRC_PATH}"

# 显示源码目录内容（前几行）
log_info "Source directory contents (top level):"
ls -1 "$EXTRACTED_SRC_PATH" | head -n 10

#!/usr/bin/env bash
# common.sh - Qt 编译管道公共函数库
# 提供日志、错误处理、文件下载、压缩包解压等通用功能

# ================================================================
# 颜色定义
# ================================================================
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_CYAN='\033[36m'
readonly COLOR_GRAY='\033[90m'

# ================================================================
# 全局变量：用于中断时清理下载中的文件
# ================================================================
DOWNLOAD_IN_PROGRESS_FILE=""
DOWNLOAD_TEMP_FILE=""

# ================================================================
# 日志函数
# ================================================================

# 信息日志 - 蓝色
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

# 成功日志 - 绿色
log_ok() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

# 警告日志 - 黄色
log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

# 错误日志 - 红色
log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# 进度信息 - 灰色（用于下载进度）
log_progress() {
    echo -e "${COLOR_GRAY}$*${COLOR_RESET}" >&2
}

# ================================================================
# 错误处理
# ================================================================

# 打印错误信息并退出
die() {
    log_error "$@"
    exit 1
}

# ================================================================
# 命令检查
# ================================================================

# 检查命令是否存在，不存在则 die
require_cmd() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            die "Required command not found: $cmd"
        fi
    done
}

# ================================================================
# 变量检查
# ================================================================

# 检查变量是否非空，为空则 die
# 用法: require_var "VAR_NAME"
require_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    if [[ -z "$var_value" ]]; then
        die "Required variable is empty: $var_name"
    fi
}

# ================================================================
# 阶段分隔
# ================================================================

# 打印醒目的阶段分隔标题
stage() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(printf '=%.0s' $(seq 1 $width))${COLOR_RESET}"
    printf "${COLOR_BOLD}${COLOR_CYAN}%*s%s%*s${COLOR_RESET}\n" $padding "" " $title " $padding ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(printf '=%.0s' $(seq 1 $width))${COLOR_RESET}"
    echo ""
}

# ================================================================
# 下载清理函数（中断时调用）
# ================================================================

# 清理下载中的临时文件
_cleanup_download() {
    if [[ -n "${DOWNLOAD_TEMP_FILE:-}" && -f "$DOWNLOAD_TEMP_FILE" ]]; then
        log_warn "Download interrupted, cleaning up: $DOWNLOAD_TEMP_FILE"
        rm -f "$DOWNLOAD_TEMP_FILE"
    fi
    if [[ -n "${DOWNLOAD_IN_PROGRESS_FILE:-}" && -f "$DOWNLOAD_IN_PROGRESS_FILE" ]]; then
        rm -f "$DOWNLOAD_IN_PROGRESS_FILE"
    fi
}

# 注册中断处理
# 注意：不捕获 EXIT，否则正常完成也会触发清理
_register_download_handlers() {
    trap _cleanup_download INT TERM
}

# ================================================================
# 文件下载
# ================================================================

# 下载文件，支持重试、幂等和进度条
# 用法: download_file <url> <dest>
download_file() {
    local url="$1"
    local dest="$2"
    local max_retries=3
    local retry_count=0

    # 幂等检查：目标文件已存在且非空则跳过
    if [[ -f "$dest" && -s "$dest" ]]; then
        local file_size
        file_size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null || echo "?")
        local size_mb=$((file_size / 1024 / 1024))
        log_info "File already exists: $dest (${size_mb} MB)"
        log_info "Skipping download"
        return 0
    fi

    # 确保目标目录存在
    local dest_dir
    dest_dir="$(dirname "$dest")"
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir" || die "Failed to create directory: $dest_dir"
    fi

    # 使用临时文件下载，完成后重命名（确保原子性）
    DOWNLOAD_TEMP_FILE="${dest}.download.$$"
    DOWNLOAD_IN_PROGRESS_FILE="$dest"

    log_info "Downloading: $url"
    log_info "Destination: $dest"

    # 注册中断处理
    _register_download_handlers

    while (( retry_count < max_retries )); do
        # 删除可能存在的旧临时文件
        rm -f "$DOWNLOAD_TEMP_FILE"

        # 使用 wget 下载，显示进度条
        # --show-progress: 显示进度条
        # --progress-bar: 使用进度条模式（默认也是）
        # -O: 输出到文件
        if wget --show-progress -O "$DOWNLOAD_TEMP_FILE" "$url" 2>&1; then
            # 下载成功，重命名为目标文件
            mv "$DOWNLOAD_TEMP_FILE" "$dest"
            DOWNLOAD_TEMP_FILE=""
            DOWNLOAD_IN_PROGRESS_FILE=""

            # 清除 trap
            trap - INT TERM

            # 显示文件大小
            local file_size
            file_size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null || echo "?")
            local size_mb=$((file_size / 1024 / 1024))
            log_ok "Download completed successfully (${size_mb} MB)"
            return 0
        else
            local exit_code=$?

            # 退出码 130 = SIGINT (用户按 Ctrl+C)，直接退出不重试
            if (( exit_code == 130 )); then
                # 清理临时文件和 trap
                rm -f "$DOWNLOAD_TEMP_FILE"
                DOWNLOAD_TEMP_FILE=""
                DOWNLOAD_IN_PROGRESS_FILE=""
                trap - INT TERM
                log_warn "Download cancelled by user"
                exit 130
            fi

            retry_count=$((retry_count + 1))

            # 清理失败的临时文件
            rm -f "$DOWNLOAD_TEMP_FILE"

            if (( retry_count < max_retries )); then
                log_warn "Download failed (exit code: ${exit_code}), retrying ($retry_count/$max_retries)..."
                sleep 2
            else
                # 清理临时文件和 trap
                rm -f "$DOWNLOAD_TEMP_FILE"
                DOWNLOAD_TEMP_FILE=""
                DOWNLOAD_IN_PROGRESS_FILE=""
                trap - INT TERM
                die "Failed to download after ${max_retries} attempts: $url"
            fi
        fi
    done

    # 清理注册的中断处理
    trap - INT TERM
    die "Failed to download after $max_retries attempts: $url"
}

# ================================================================
# 压缩包解压
# ================================================================

# 自动识别压缩包格式并解压
# 用法: extract_archive <archive> <dest_dir>
extract_archive() {
    local archive="$1"
    local dest_dir="$2"

    if [[ ! -f "$archive" ]]; then
        die "Archive not found: $archive"
    fi

    # 确保目标目录存在
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir" || die "Failed to create directory: $dest_dir"
    fi

    log_info "Extracting: $archive"
    log_info "Destination: $dest_dir"

    case "$archive" in
        *.tar.xz|*.txz)
            tar --checkpoint=50 --checkpoint-action=dot -xJf "$archive" -C "$dest_dir" \
                || die "Failed to extract .tar.xz"
            ;;
        *.tar.gz|*.tgz)
            tar --checkpoint=50 --checkpoint-action=dot -xzf "$archive" -C "$dest_dir" \
                || die "Failed to extract .tar.gz"
            ;;
        *.tar.bz2|*.tbz)
            tar --checkpoint=50 --checkpoint-action=dot -xjf "$archive" -C "$dest_dir" \
                || die "Failed to extract .tar.bz2"
            ;;
        *.zip)
            unzip -q "$archive" -d "$dest_dir" || die "Failed to extract .zip"
            ;;
        *)
            die "Unsupported archive format: $archive"
            ;;
    esac

    log_ok "Extraction completed successfully"
}

# ================================================================
# 工具链相关
# ================================================================

# 自动检测工具链 bin 目录
# 在 root 下递归查找 {prefix}gcc，返回其所在目录
# 用法: auto_detect_toolchain_bin <root> <prefix>
auto_detect_toolchain_bin() {
    local root="$1"
    local prefix="$2"
    local gcc_path

    if [[ ! -d "$root" ]]; then
        die "Toolchain root not found: $root"
    fi

    # 递归查找 {prefix}gcc
    gcc_path=$(find "$root" -type f -name "${prefix}gcc" 2>/dev/null | head -n 1)

    if [[ -z "$gcc_path" ]]; then
        die "Toolchain gcc not found: ${prefix}gcc in $root"
    fi

    # 返回 bin 目录
    dirname "$gcc_path"
}

# ================================================================
# 导出函数（供 subshell 使用）
# ================================================================
export -f log_info log_ok log_warn log_error log_progress
export -f die require_cmd require_var
export -f stage download_file extract_archive
export -f auto_detect_toolchain_bin
export -f _cleanup_download _register_download_handlers

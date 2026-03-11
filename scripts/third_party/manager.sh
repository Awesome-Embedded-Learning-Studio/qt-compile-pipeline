#!/usr/bin/env bash
# third_party/manager.sh - 第三方库管理器
# 用法: bash third_party/manager.sh <command> [args...]
#
# 命令:
#   install [lib...]  - 安装指定的库（或全部）
#   clean [lib...]    - 清理指定的库（或全部）
#   status            - 显示所有库的安装状态
#   generate-cmake    - 生成 CMake 配置片段（输出到 stdout）
#   get-sysroot <lib> - 获取库的 sysroot 路径

set -euo pipefail

# ================================================================
# 加载公共库
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 先加载 qt.conf（third_party.conf 依赖其中的 WORK_DIR 变量）
if [[ -f "${PROJECT_ROOT}/config/qt.conf" ]]; then
    source "${PROJECT_ROOT}/config/qt.conf"
else
    echo "Error: qt.conf not found at ${PROJECT_ROOT}/config/qt.conf" >&2
    exit 1
fi

source "${SCRIPT_DIR}/common.sh"

# 加载配置
third_party_load_config

# ================================================================
# 命令函数
# ================================================================

# install 命令：安装库
cmd_install() {
    local libs=("$@")

    # 如果没有指定库，安装所有启用的库
    if [[ ${#libs[@]} -eq 0 ]]; then
        libs=(${THIRD_PARTY_LIBS})
    fi

    stage "Third-Party Libraries Installer"

    # 初始化环境
    third_party_init

    # 安装每个库
    for lib in "${libs[@]}"; do
        if [[ "$(third_party_get_enabled "$lib")" != "true" ]]; then
            log_info "Skipping disabled library: ${lib}"
            continue
        fi

        log_info "Installing ${lib}..."

        # 使用 builtin.sh
        local lib_script="${SCRIPT_DIR}/${lib}/builtin.sh"

        if [[ ! -f "$lib_script" ]]; then
            log_warn "Script not found: ${lib_script}"
            continue
        fi

        # 加载库脚本
        source "$lib_script"

        # 调用安装函数
        local install_func="${lib}_builtin_install"

        if declare -f "$install_func" > /dev/null; then
            if $install_func; then
                third_party_mark_installed "$lib"
                log_ok "${lib} installed successfully"
            else
                log_warn "${lib} installation failed"
            fi
        else
            log_warn "Install function not found: ${install_func}"
        fi
    done

    # 生成 CMake 配置片段
    log_info "Generating CMake configuration fragment..."
    third_party_generate_cmake_fragment_for_toolchain > /dev/null
    log_ok "CMake fragment generated"

    log_ok "Third-party libraries installation completed!"
}

# clean 命令：清理库
cmd_clean() {
    local libs=("$@")

    # 如果没有指定库，清理所有库
    if [[ ${#libs[@]} -eq 0 ]]; then
        libs=(${THIRD_PARTY_LIBS})
    fi

    stage "Third-Party Libraries Cleaner"

    for lib in "${libs[@]}"; do
        log_info "Cleaning ${lib}..."

        # 使用 builtin.sh
        local lib_script="${SCRIPT_DIR}/${lib}/builtin.sh"

        if [[ -f "$lib_script" ]]; then
            source "$lib_script"

            local clean_func="${lib}_builtin_clean"

            if declare -f "$clean_func" > /dev/null; then
                $clean_func
            fi
        fi

        # 取消安装标记
        third_party_unmark_installed "$lib"

        log_ok "${lib} cleaned"
    done
}

# status 命令：显示状态
cmd_status() {
    stage "Third-Party Libraries Status"

    printf "%-15s %-10s %-15s\n" "Library" "Enabled" "Installed"
    printf "%s\n" "------------------------------------------------"

    for lib in ${THIRD_PARTY_LIBS}; do
        local enabled="$(third_party_get_enabled "$lib")"
        local installed="No"

        if third_party_is_installed "$lib"; then
            installed="Yes"
        fi

        printf "%-15s %-10s %-15s\n" "$lib" "$enabled" "$installed"
    done

    echo ""
    log_info "Sysroot: ${THIRD_PARTY_SYSROOT}"
}

# generate-cmake 命令：生成 CMake 配置片段
cmd_generate_cmake() {
    third_party_init
    local fragment_file
    fragment_file=$(third_party_generate_cmake_fragment_for_toolchain)
    if [[ -n "$fragment_file" && -f "$fragment_file" ]]; then
        cat "$fragment_file"
    fi
}

# get-sysroot 命令：获取库的 sysroot 路径
cmd_get_sysroot() {
    local lib="$1"

    if [[ -z "$lib" ]]; then
        # 如果没有指定库，返回主 sysroot
        echo "${THIRD_PARTY_SYSROOT}"
        return 0
    fi

    third_party_get_sysroot "$lib"
}

# get-lib-path 命令：获取库的库文件路径
cmd_get_lib_path() {
    local lib="$1"
    local arch="${2:-armhf}"

    third_party_get_lib_path "$lib" "$arch"
}

# help 命令：显示帮助
cmd_help() {
    cat <<EOF
Third-Party Libraries Manager

Usage: $0 <command> [args...]

Commands:
    install [lib...]      Install specified libraries (or all if none specified)
    clean [lib...]        Clean specified libraries (or all if none specified)
    status                Show installation status of all libraries
    generate-cmake        Generate CMake configuration fragment (to stdout)
    get-sysroot [lib]     Get sysroot path for library (or main sysroot if none specified)
    get-lib-path <lib>    Get library file path for library
    help                  Show this help message

Examples:
    $0 install                      # Install all enabled libraries
    $0 install pulseaudio           # Install PulseAudio only
    $0 status                       # Show status
    $0 generate-cmake > fragment.cmake  # Generate CMake fragment
    $0 get-sysroot pulseaudio       # Get PulseAudio sysroot path

Configuration file: config/third_party.conf
EOF
}

# ================================================================
# 主入口
# ================================================================
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        install)
            cmd_install "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        status)
            cmd_status
            ;;
        generate-cmake)
            cmd_generate_cmake
            ;;
        get-sysroot)
            cmd_get_sysroot "$@"
            ;;
        get-lib-path)
            cmd_get_lib_path "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo "Unknown command: $command" >&2
            echo "Run '$0 help' for usage" >&2
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本（非 source），运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

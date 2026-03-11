#!/usr/bin/env bash
# install-dependencies.sh - 安装 Qt 6.9 编译所需的系统依赖

set -euo pipefail

# ================================================================
# 加载公共库
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ================================================================
# 检测系统类型
# ================================================================
detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect Linux distribution. /etc/os-release not found."
    fi

    . /etc/os-release

    DISTRO_ID="$ID"
    DISTRO_LIKE="${ID_LIKE:-}"

    log_info "Detected distribution: $DISTRO_ID"

    # 判断包管理器系列
    if [[ "$DISTRO_ID" =~ ^(ubuntu|debian)$ ]] || [[ "$DISTRO_LIKE" =~ @(ubuntu|debian) ]]; then
        PKG_MANAGER="apt"
    elif [[ "$DISTRO_ID" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]] || [[ "$DISTRO_LIKE" =~ @(fedora|rhel|centos) ]]; then
        PKG_MANAGER="dnf"
    elif [[ "$DISTRO_ID" == "arch" ]] || [[ "$DISTRO_LIKE" == "arch" ]]; then
        PKG_MANAGER="pacman"
    else
        die "Unsupported distribution: $DISTRO_ID"
    fi

    log_info "Package manager: $PKG_MANAGER"
}

# ================================================================
# 检查并显示缺失的命令
# ================================================================
check_missing_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    printf '%s\n' "${missing[@]:-}"
}

# ================================================================
# Ubuntu/Debian 依赖安装
# ================================================================
install_apt_deps() {
    stage "Installing Dependencies (apt)"

    # 核心构建工具
    local packages=(
        build-essential
        cmake
        ninja-build
        perl
        python3
        pkg-config
        git

        # Qt 构建工具
        bison
        flex
        gperf

        # X11 和图形库
        libx11-dev
        libxext-dev
        libxrender-dev
        libxcb1-dev
        libx11-xcb-dev
        libxkbcommon-dev
        libxkbcommon-x11-dev
        libfontconfig1-dev
        libfreetype6-dev

        # 图像和多媒体
        libpng-dev
        libjpeg-dev
        libwebp-dev

        # 系统库
        zlib1g-dev
        libglib2.0-dev
        libicu-dev
        libharfbuzz-dev
        libpcre2-dev
        libdouble-conversion-dev

        # 输入
        libevdev-dev
        libinput-dev

        # XCB 扩展 (Ubuntu 24.04+ 使用新的包名)
        libxcb-cursor-dev
        libxcb-xinerama0-dev
        libxcb-xfixes0-dev
        libxcb-util-dev
    )

    log_info "Updating package list..."
    sudo apt-get update

    log_info "Installing ${#packages[@]} packages..."
    sudo apt-get install -y "${packages[@]}"

    log_ok "Dependencies installed successfully"
}

# ================================================================
# Fedora/RHEL 依赖安装
# ================================================================
install_dnf_deps() {
    stage "Installing Dependencies (dnf)"

    log_info "Ensuring development tools group..."
    sudo dnf install -y dnf-plugins-core || true
    sudo dnf groupinstall -y "Development Tools" || true

    local packages=(
        cmake
        ninja-build
        perl
        python3
        pkgconf
        git

        bison
        flex
        gperf

        libX11-devel
        libXext-devel
        libXrender-devel
        libxcb-devel
        libxkbcommon-devel
        libxkbcommon-x11-devel
        fontconfig-devel
        freetype-devel

        libpng-devel
        libjpeg-turbo-devel
        libwebp-devel

        zlib-devel
        glib2-devel
        libicu-devel
        harfbuzz-devel
        pcre2-devel
        double-conversion-devel

        libevdev-devel
        libinput-devel

        libxcb-cursor-devel
        libxcb-xinerama-devel
        libxcb-xfixes-devel
    )

    log_info "Installing ${#packages[@]} packages..."
    sudo dnf install -y "${packages[@]}"

    log_ok "Dependencies installed successfully"
}

# ================================================================
# Arch Linux 依赖安装
# ================================================================
install_pacman_deps() {
    stage "Installing Dependencies (pacman)"

    local packages=(
        base-devel
        cmake
        ninja
        perl
        python
        pkgconf
        git

        bison
        flex
        gperf

        libx11
        libxext
        libxrender
        libxcb
        libxkbcommon
        fontconfig
        freetype2

        libpng
        libjpeg
        libwebp

        zlib
        glib2
        icu
        harfbuzz
        pcre2
        double-conversion

        libevdev
        libinput

        xcb-util-cursor
        xcb-util-xrm
    )

    log_info "Installing ${#packages[@]} packages..."
    sudo pacman -S --noconfirm "${packages[@]}"

    log_ok "Dependencies installed successfully"
}

# ================================================================
# 验证安装结果
# ================================================================
verify_installation() {
    stage "Verification"

    local required_commands=(
        cmake
        ninja
        gcc
        g++
        perl
        python3
        bison
        flex
        gperf
        pkg-config
    )

    local missing=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "All required dependencies are installed!"
        echo ""
        log_info "You can now run the build pipeline:"
        echo "  ./build.sh"
        return 0
    else
        log_warn "Missing commands: ${missing[*]}"
        return 1
    fi
}

# ================================================================
# 主流程
# ================================================================
main() {
    stage "Qt 6.9 Build Dependencies Installer"

    # 检测发行版
    detect_distro

    # 根据包管理器安装依赖
    case "$PKG_MANAGER" in
        apt)
            install_apt_deps
            ;;
        dnf)
            install_dnf_deps
            ;;
        pacman)
            install_pacman_deps
            ;;
        *)
            die "Unknown package manager: $PKG_MANAGER"
            ;;
    esac

    # 验证安装
    verify_installation
}

# 执行主流程
main "$@"

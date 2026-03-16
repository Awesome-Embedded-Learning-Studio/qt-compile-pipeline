#!/usr/bin/env bash
# install-host-deps.sh - Install host system dependencies for Qt 6 build
# Supports: Ubuntu/Debian (apt), Fedora/RHEL (dnf), Arch Linux (pacman)
# Usage: sudo bash scripts/install-host-deps.sh

set -euo pipefail

# ================================================================
# 加载公共库
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# ================================================================
# 检测系统类型
# ================================================================
detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        echo "Error: Cannot detect Linux distribution. /etc/os-release not found." >&2
        exit 1
    fi

    . /etc/os-release

    DISTRO_ID="$ID"
    DISTRO_LIKE="${ID_LIKE:-}"

    echo "Detected distribution: $DISTRO_ID"

    # 判断包管理器系列
    if [[ "$DISTRO_ID" =~ ^(ubuntu|debian)$ ]] || [[ "$DISTRO_LIKE" =~ @(ubuntu|debian) ]]; then
        PKG_MANAGER="apt"
    elif [[ "$DISTRO_ID" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]] || [[ "$DISTRO_LIKE" =~ @(fedora|rhel|centos) ]]; then
        PKG_MANAGER="dnf"
    elif [[ "$DISTRO_ID" == "arch" ]] || [[ "$DISTRO_LIKE" == "arch" ]]; then
        PKG_MANAGER="pacman"
    else
        echo "Unsupported distribution: $DISTRO_ID" >&2
        exit 1
    fi

    echo "Package manager: $PKG_MANAGER"
}

# ================================================================
# Ubuntu/Debian 依赖安装
# ================================================================
install_apt_deps() {
    echo "=============================================================================="
    echo "  Installing Qt 6 Build Dependencies (Ubuntu/Debian)"
    echo "=============================================================================="
    echo ""

    # 更新包列表
    echo "Updating package list..."
    apt update

    # 核心构建工具
    echo ""
    echo "Installing core build dependencies..."
    apt install -y \
        build-essential \
        cmake \
        meson \
        ninja-build \
        perl \
        python3 \
        pkg-config \
        git \
        curl \
        wget \
        tar \
        xz-utils \
        ccache \
        bison \
        flex \
        gperf

    # OpenGL / 图形库
    echo ""
    echo "Installing OpenGL / graphics dependencies..."
    apt install -y \
        libgl-dev \
        libglvnd-dev \
        libglvnd-core-dev \
        libglx-dev \
        libgles-dev \
        libglu1-mesa-dev \
        libdrm-dev \
        libegl1-mesa-dev \
        mesa-common-dev

    # X11 核心库
    echo ""
    echo "Installing X11 core dependencies..."
    apt install -y \
        libx11-dev \
        libx11-xcb-dev \
        libxext-dev \
        libxfixes-dev \
        libxrender-dev \
        libxi-dev \
        libxrandr-dev \
        libxcursor-dev \
        libxft-dev \
        libxinerama-dev \
        libxv-dev \
        libxcomposite-dev \
        libxdamage-dev \
        libsm-dev \
        libice-dev

    # XKB 输入处理
    echo ""
    echo "Installing XKB input dependencies..."
    apt install -y \
        libxkbcommon-dev \
        libxkbcommon-x11-dev

    # XCB 核心及扩展（完整的 Qt 编译所需）
    echo ""
    echo "Installing XCB dependencies..."
    apt install -y \
        libxcb1-dev \
        libxcb-util-dev \
        libxcb-cursor-dev \
        libxcb-xinerama0-dev \
        libxcb-xfixes0-dev \
        libxcb-randr0-dev \
        libxcb-shape0-dev \
        libxcb-sync-dev \
        libxcb-keysyms1-dev \
        libxcb-image0-dev \
        libxcb-shm0-dev \
        libxcb-icccm4-dev \
        libxcb-render0-dev \
        libxcb-render-util0-dev \
        libxcb-glx0-dev \
        libxcb-xkb-dev \
        libxcb-xinput-dev \
        libxcb-cursor0

    # 字体和图像库
    echo ""
    echo "Installing font and image dependencies..."
    apt install -y \
        libfontconfig1-dev \
        libfreetype6-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        libjpeg8-dev \
        libpng-dev \
        libtiff-dev \
        libwebp-dev \
        libb2-dev

    # 输入设备和 ICU
    echo ""
    echo "Installing input, ICU and text rendering dependencies..."
    apt install -y \
        libinput-dev \
        libevdev-dev \
        libts-dev \
        libicu-dev \
        libpcre2-dev \
        libsqlite3-dev \
        libdouble-conversion-dev

    # 网络和安全
    echo ""
    echo "Installing network and security dependencies..."
    apt install -y \
        libssl-dev \
        libglib2.0-dev \
        libdbus-1-dev \
        zlib1g-dev

    # 多媒体 / 音频
    echo ""
    echo "Installing multimedia / audio dependencies..."
    apt install -y \
        libpulse-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-bad1.0-dev \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-tools \
        gstreamer1.0-x \
        gstreamer1.0-gl \
        gstreamer1.0-pulseaudio

    echo ""
    echo "=============================================================================="
    echo "  Dependencies installed successfully!"
    echo "=============================================================================="
}

# ================================================================
# Fedora/RHEL 依赖安装
# ================================================================
install_dnf_deps() {
    echo "=============================================================================="
    echo "  Installing Qt 6 Build Dependencies (Fedora/RHEL)"
    echo "=============================================================================="
    echo ""

    echo "Ensuring development tools group..."
    dnf install -y dnf-plugins-core || true
    dnf groupinstall -y "Development Tools" || true

    # 核心构建工具
    echo ""
    echo "Installing core build dependencies..."
    dnf install -y \
        cmake \
        ninja-build \
        meson \
        perl \
        python3 \
        pkgconf \
        git \
        curl \
        wget \
        xz \
        ccache \
        bison \
        flex \
        gperf

    # OpenGL / 图形库
    echo ""
    echo "Installing OpenGL / graphics dependencies..."
    dnf install -y \
        mesa-libGL-devel \
        mesa-libGLU-devel \
        mesa-libEGL-devel \
        mesa-libGLES-devel \
        libdrm-devel \
        mesa-libGL-devel

    # X11 核心库
    echo ""
    echo "Installing X11 core dependencies..."
    dnf install -y \
        libX11-devel \
        libX11-xcb \
        libXext-devel \
        libXfixes-devel \
        libXrender-devel \
        libXi-devel \
        libXrandr-devel \
        libXcursor-devel \
        libXft-devel \
        libXinerama-devel \
        libXv-devel \
        libXcomposite-devel \
        libXdamage-devel \
        libSM-devel \
        libICE-devel

    # XKB 输入处理
    echo ""
    echo "Installing XKB input dependencies..."
    dnf install -y \
        libxkbcommon-devel \
        libxkbcommon-x11-devel

    # XCB 核心及扩展
    echo ""
    echo "Installing XCB dependencies..."
    dnf install -y \
        libxcb-devel \
        xcb-util-devel \
        xcb-util-cursor-devel \
        xcb-util-xinerama-devel \
        xcb-util-xfixes-devel \
        xcb-util-renderutil-devel \
        xcb-util-wm-devel \
        xcb-util-keysyms-devel \
        xcb-util-image-devel

    # 字体和图像库
    echo ""
    echo "Installing font and image dependencies..."
    dnf install -y \
        fontconfig-devel \
        freetype-devel \
        harfbuzz-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libtiff-devel \
        libwebp-devel \
        libb2-devel

    # 输入设备和 ICU
    echo ""
    echo "Installing input, ICU and text rendering dependencies..."
    dnf install -y \
        libinput-devel \
        libevdev-devel \
    dnf install -y \
        libicu-devel \
        pcre2-devel \
        sqlite-devel \
        double-conversion-devel \
        zlib-devel

    # 网络和安全
    echo ""
    echo "Installing network and security dependencies..."
    dnf install -y \
        openssl-devel \
        glib2-devel \
        dbus-devel

    # 多媒体 / 音频
    echo ""
    echo "Installing multimedia / audio dependencies..."
    dnf install -y \
        pulseaudio-libs-devel \
        gstreamer1-devel \
        gstreamer1-plugins-base-devel \
        gstreamer1-plugins-bad-free-devel \
        gstreamer1-plugins-base \
        gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free \
        gstreamer1-libav \
        gstreamer1-plugins-good-extras \
        gstreamer1-plugins-ugly-free

    echo ""
    echo "=============================================================================="
    echo "  Dependencies installed successfully!"
    echo "=============================================================================="
}

# ================================================================
# Arch Linux 依赖安装
# ================================================================
install_pacman_deps() {
    echo "=============================================================================="
    echo "  Installing Qt 6 Build Dependencies (Arch Linux)"
    echo "=============================================================================="
    echo ""

    # 核心构建工具
    echo ""
    echo "Installing core build dependencies..."
    pacman -S --noconfirm \
        base-devel \
        cmake \
        ninja \
        meson \
        perl \
        python \
        pkgconf \
        git \
        curl \
        wget \
        xz \
        ccache \
        bison \
        flex \
        gperf

    # OpenGL / 图形库
    echo ""
    echo "Installing OpenGL / graphics dependencies..."
    pacman -S --noconfirm \
        mesa \
        libdrm \
        libglvnd

    # X11 核心库
    echo ""
    echo "Installing X11 core dependencies..."
    pacman -S --noconfirm \
        libx11 \
        libxext \
        libxfixes \
        libxrender \
        libxi \
        libxrandr \
        libxcursor \
        libxft \
        libxinerama \
        libxv \
        libxcomposite \
        libxdamage \
        libsm \
        libice

    # XKB 输入处理
    echo ""
    echo "Installing XKB input dependencies..."
    pacman -S --noconfirm \
        libxkbcommon \
        libxkbcommon-x11

    # XCB 核心及扩展
    echo ""
    echo "Installing XCB dependencies..."
    pacman -S --noconfirm \
        libxcb \
        xcb-util \
        xcb-util-cursor \
        xcb-util-xrm \
        xcb-util-wm \
        xcb-util-keysyms \
        xcb-util-image \
        xcb-util-renderutil

    # 字体和图像库
    echo ""
    echo "Installing font and image dependencies..."
    pacman -S --noconfirm \
        fontconfig \
        freetype2 \
        harfbuzz \
        libjpeg \
        libpng \
        libtiff \
        libwebp

    # 输入设备和 ICU
    echo ""
    echo "Installing input, ICU and text rendering dependencies..."
    pacman -S --noconfirm \
        libinput \
        libevdev \
        icu \
        pcre2 \
        sqlite \
        double-conversion \
        zlib

    # 网络和安全
    echo ""
    echo "Installing network and security dependencies..."
    pacman -S --noconfirm \
        openssl \
        glib2 \
        dbus

    # 多媒体 / 音频
    echo ""
    echo "Installing multimedia / audio dependencies..."
    pacman -S --noconfirm \
        pulseaudio \
        gstreamer \
        gst-plugins-base \
        gst-plugins-good \
        gst-plugins-bad \
        gst-plugins-ugly \
        gst-libav

    echo ""
    echo "=============================================================================="
    echo "  Dependencies installed successfully!"
    echo "=============================================================================="
}

# ================================================================
# 验证安装结果
# ================================================================
verify_installation() {
    echo ""
    echo "=============================================================================="
    echo "  Verifying Installation"
    echo "=============================================================================="

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
        echo "  All required dependencies are installed!"
        echo ""
        echo "  You can now run the build pipeline:"
        echo "    ./build.sh"
        echo "=============================================================================="
        return 0
    else
        echo "  Warning: Missing commands: ${missing[*]}"
        echo "=============================================================================="
        return 1
    fi
}

# ================================================================
# 主流程
# ================================================================
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
       echo "Error: This script must be run as root (use sudo)"
       exit 1
    fi

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
            echo "Unknown package manager: $PKG_MANAGER" >&2
            exit 1
            ;;
    esac

    # 验证安装
    verify_installation
}

# 执行主流程
main "$@"

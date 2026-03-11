#!/usr/bin/env bash
# install_target_deps.sh - 下载并解包 ARM 目标依赖库（构建 mini sysroot）
# Usage: sudo bash scripts/install_target_deps.sh [arch]
#
# 支持的架构:
#   armhf    - ARMv7-A hard float (如 i.MX6ULL)
#   arm64    - ARMv8-A 64位 (aarch64)
#
# 默认架构: armhf
#
# 注意: 此脚本已委托给 third_party/manager.sh
#       如果 third_party/manager.sh 存在，将使用新模块
#       否则使用原有的实现逻辑

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ================================================================
# 委托给新的 third_party 模块（如果存在）
# ================================================================
# 检查是否存在新的 third_party 管理器
if [[ -f "${SCRIPT_DIR}/third_party/manager.sh" ]]; then
    log_info "Using new third_party module..."
    # 委托给新的管理器（manager.sh 会自动加载 qt.conf 和 third_party.conf）
    # 注意：不传递 $@ 中的架构参数，manager.sh 会安装所有启用的库
    exec bash "${SCRIPT_DIR}/third_party/manager.sh" install
fi

# 如果 third_party 模块不存在，使用原有的实现逻辑（向后兼容）
log_info "Using legacy install_target_deps implementation..."

# ================================================================
# 配置参数
# ================================================================
# 目标架构 (默认 armhf)
TARGET_ARCH="${1:-armhf}"

# Mini sysroot 安装目录
MINI_SYSROOT="${WORK_DIR:-./qt-workdir}/arm-sysroot-${TARGET_ARCH}"

# Ubuntu 版本 (用于下载 .deb 包)
# 重要: noble (24.04) 没有 armhf 包，jammy (22.04) 是最后一个支持 armhf 的 LTS
# 在 24.04 主机上使用 22.04 的 armhf 包进行交叉编译是完全兼容的
UBUNTU_VERSION="${UBUNTU_VERSION:-jammy}"  # 22.04 LTS (支持 armhf)
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://ports.ubuntu.com/ubuntu-ports/}"

# 临时下载目录
DL_DIR="${MINI_SYSROOT}/downloads"

# Debian 包列表
declare -A DEB_PACKAGES

# ================================================================
# 架构相关配置
# ================================================================
case "$TARGET_ARCH" in
    armhf)
        DEBIAN_ARCH="armhf"
        DEB_PACKAGES=(
            [pulseaudio]="libpulse0:armhf libpulse-dev:armhf"
            [glib]="libglib2.0-0:armhf libglib2.0-dev:armhf"
            [input]="libevdev5:armhf libevdev-dev:armhf libinput10:armhf libinput-dev:armhf"
            [dbus]="libdbus-1-3:armhf libdbus-1-dev:armhf"
            [icu]="libicu70:armhf libicu-dev:armhf"
            [ssl]="libssl3:armhf libssl-dev:armhf"
        )
        ;;
    arm64|aarch64)
        DEBIAN_ARCH="arm64"
        DEB_PACKAGES=(
            [pulseaudio]="libpulse0:arm64 libpulse-dev:arm64"
            [glib]="libglib2.0-0:arm64 libglib2.0-dev:arm64"
            [input]="libevdev5:arm64 libevdev-dev:arm64 libinput10:arm64 libinput-dev:arm64"
            [dbus]="libdbus-1-3:arm64 libdbus-1-dev:arm64"
            [icu]="libicu70:arm64 libicu-dev:arm64"
            [ssl]="libssl3:arm64 libssl-dev:arm64"
        )
        ;;
    *)
        die "Unsupported architecture: $TARGET_ARCH"$'\n'\
             "Supported: armhf, arm64"
        ;;
esac

# ================================================================
# 前置检查
# ================================================================
stage "Target Dependencies Installer"

log_info "Target architecture: ${TARGET_ARCH}"
log_info "Mini sysroot path: ${MINI_SYSROOT}"

# 检查必要的命令
require_cmd wget dpkg-deb

# ================================================================
# 目录初始化
# ================================================================
init_directories() {
    log_info "Creating directory structure..."

    mkdir -p "${MINI_SYSROOT}"
    mkdir -p "${DL_DIR}"

    log_ok "Directories created"
}

# ================================================================
# 获取包的下载 URL
# ================================================================
get_package_url() {
    local package_spec="$1"  # 格式: package_name:arch
    local package_name="${package_spec%:*}"

    # 使用 Ubuntu Packages API 获取下载 URL
    local url="${UBUNTU_MIRROR}dists/${UBUNTU_VERSION}/main/binary-${DEBIAN_ARCH}/Packages.bz2"
    local packages_file="${DL_DIR}/Packages_${DEBIAN_ARCH}.bz2"

    # 下载包索引 (如果不存在)
    if [[ ! -f "$packages_file" ]]; then
        log_info "Downloading package index for ${DEBIAN_ARCH}..."
        wget -q -O "$packages_file" "$url" || die "Failed to download package index"
    fi

    # 解压并查找 Filename
    local filename
    filename=$(bzcat "$packages_file" | grep -A 10 "^Package: ${package_name}$" | grep "^Filename:" | head -n 1 | cut -d' ' -f2)

    if [[ -z "$filename" ]]; then
        log_warn "Package not found in index: ${package_name}"
        return 1
    fi

    echo "${UBUNTU_MIRROR}${filename}"
}

# ================================================================
# 简化的下载方式 (使用 apt-get download)
# ================================================================
download_package_apt() {
    local package_spec="$1"

    log_info "Downloading: ${package_spec}"

    # 检查是否已下载
    local deb_file
    deb_file="${DL_DIR}/$(echo "${package_spec}" | tr ':' '_').deb"

    if [[ -f "$deb_file" ]]; then
        log_info "Already downloaded: $(basename "$deb_file")"
        echo "$deb_file"
        return 0
    fi

    # 使用 apt-get download (需要 sudo 和 foreign-architecture 支持)
    if command -v apt-get &>/dev/null; then
        # 添加外部架构 (如果尚未添加)
        if ! dpkg --print-foreign-architectures | grep -q "^${DEBIAN_ARCH}$"; then
            log_info "Adding foreign architecture: ${DEBIAN_ARCH}"
            sudo dpkg --add-architecture "${DEBIAN_ARCH}"
            sudo apt-get update
        fi

        # 下载包
        (
            cd "$DL_DIR"
            if sudo apt-get download "${package_spec}"; then
                # 重命名文件以包含架构后缀 (apt-get download 不会包含架构)
                local downloaded_file
                downloaded_file=$(ls -t "${package_spec%:*}"_*.deb 2>/dev/null | head -n 1)
                if [[ -n "$downloaded_file" && -f "$downloaded_file" ]]; then
                    mv "$downloaded_file" "$(basename "$deb_file")"
                    echo "$deb_file"
                    return 0
                fi
            fi
        )
    fi

    return 1
}

# ================================================================
# 直接从 Ubuntu 镜像下载 (无 sudo 方式)
# ================================================================
download_package_direct() {
    local package_spec="$1"
    local package_name="${package_spec%:*}"

    # 从 Ubuntu ports 镜像直接下载
    # 使用固定的 URL 格式: http://ports.ubuntu.com/pool/main/libX/libXXX/
    # 需要先获取包索引来找到确切的 URL

    local packages_index="${DL_DIR}/Packages_${DEBIAN_ARCH}"
    local index_xz="${packages_index}.xz"
    local index_url="${UBUNTU_MIRROR}dists/${UBUNTU_VERSION}/main/binary-${DEBIAN_ARCH}/Packages.xz"

    # 下载包索引 (如果不存在)
    if [[ ! -f "$packages_index" ]]; then
        if ! wget -q -O "$index_xz" "$index_url"; then
            return 1
        fi
        # 解压索引
        if ! xz -d -c "$index_xz" > "$packages_index"; then
            return 1
        fi
    fi

    # 查找包的 Filename
    local filename
    local in_package=false
    local found=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^Package:[[:space:]]*${package_name}$ ]]; then
            in_package=true
        elif [[ "$in_package" == true ]]; then
            if [[ "$line" =~ ^Filename:(.*)$ ]]; then
                filename="${BASH_REMATCH[1]}"
                filename=$(echo "$filename" | xargs)  # trim whitespace
            elif [[ "$line" =~ ^[[:space:]]*$ ]]; then
                if [[ -n "$filename" ]]; then
                    found=true
                    break
                fi
                in_package=false
            fi
        fi
    done < "$packages_index"

    if [[ "$found" != true || -z "$filename" ]]; then
        return 1
    fi

    # 构建下载 URL
    local download_url="${UBUNTU_MIRROR}${filename}"
    local deb_file="${DL_DIR}/$(basename "$filename")"

    # 检查是否已下载
    if [[ -f "$deb_file" && -s "$deb_file" ]]; then
        echo "$deb_file"
        return 0
    fi

    # 下载 .deb 文件 (quiet 模式，日志由 wget 显示)
    if wget -q --show-progress -O "$deb_file" "$download_url"; then
        echo "$deb_file"
        return 0
    else
        rm -f "$deb_file"
        return 1
    fi
}

# ================================================================
# 解包 .deb 文件到 sysroot
# ================================================================
extract_deb() {
    local deb_file="$1"

    if [[ ! -f "$deb_file" ]]; then
        die "Deb file not found: ${deb_file}"
    fi

    log_info "Extracting: $(basename "$deb_file")"

    # 使用 dpkg-deb -x 解包 (控制文件和数据)
    dpkg-deb -x "$deb_file" "${MINI_SYSROOT}" || die "Failed to extract: ${deb_file}"

    log_ok "Extracted: $(basename "$deb_file")"
}

# ================================================================
# 安装一组依赖包
# ================================================================
install_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")

    log_info "Installing package group: ${group_name}"

    for package_spec in "${packages[@]}"; do
        local deb_file
        local success=false

        # 优先尝试直接下载 (不需要 sudo)
        if deb_file=$(download_package_direct "$package_spec"); then
            extract_deb "$deb_file"
            success=true
        # 备用: 尝试 apt-get download (需要 sudo)
        elif deb_file=$(download_package_apt "$package_spec"); then
            extract_deb "$deb_file"
            success=true
        fi

        if [[ "$success" != true ]]; then
            log_warn "Failed to download: ${package_spec}"
        fi
    done
}

# ================================================================
# 生成 CMake 配置片段
# ================================================================
generate_cmake_config() {
    local config_file="${MINI_SYSROOT}/cmake-sysroot.conf"

    log_info "Generating CMake configuration..."

    # 自动检测库路径
    local lib_path=""
    local possible_paths=(
        "${MINI_SYSROOT}/usr/lib/${DEBIAN_ARCH}-linux-gnu"
        "${MINI_SYSROOT}/usr/lib"
        "${MINI_SYSROOT}/lib/${DEBIAN_ARCH}-linux-gnu"
        "${MINI_SYSROOT}/lib"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            lib_path="$path"
            break
        fi
    done

    cat > "$config_file" <<EOF
# Mini Sysroot CMake Configuration
# 由 install_target_deps.sh 自动生成
# 在 toolchain 文件中 source 此文件

# ================================================================
# 设置 Sysroot
# ================================================================
set(CMAKE_SYSROOT "${MINI_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "${MINI_SYSROOT}")

# ================================================================
# 库路径
# ================================================================
set(CMAKE_LIBRARY_PATH "${lib_path}" \${CMAKE_LIBRARY_PATH})
set(CMAKE_INCLUDE_PATH "${MINI_SYSROOT}/usr/include" \${CMAKE_INCLUDE_PATH})

# ================================================================
# PulseAudio (音频支持)
# ================================================================
if EXISTS "${MINI_SYSROOT}/usr/include/pulse/pulseaudio.h")
    set(PULSEAUDIO_INCLUDE_DIR "${MINI_SYSROOT}/usr/include")
    set(PULSEAUDIO_LIBRARY     "${lib_path}/libpulse.so")
endif()

# ================================================================
# GLib
# ================================================================
if EXISTS "${MINI_SYSROOT}/usr/include/glib-2.0/glib.h")
    set(GLIB_INCLUDE_DIR "${MINI_SYSROOT}/usr/include/glib-2.0")
    set(GLIB_LIBRARIES    "${lib_path}/libglib-2.0.so")
endif()

# ================================================================
# D-Bus
# ================================================================
if EXISTS "${MINI_SYSROOT}/usr/include/dbus-1.0/dbus/dbus.h")
    set(DBUS_INCLUDE_DIR "${MINI_SYSROOT}/usr/include/dbus-1.0")
    set(DBUS_LIBRARY     "${lib_path}/libdbus-1.so")
endif()

# ================================================================
# ICU
# ================================================================
if EXISTS "${MINI_SYSROOT}/usr/include/unicode/utypes.h")
    set(ICU_INCLUDE_DIR "${MINI_SYSROOT}/usr/include")
    set(ICU_UC_LIBRARY  "${lib_path}/libicuuc.so")
    set(ICU_I18N_LIBRARY "${lib_path}/libicui18n.so")
endif()
EOF

    log_ok "Configuration written to: ${config_file}"
}

# ================================================================
# 显示安装结果
# ================================================================
show_results() {
    stage "Installation Summary"

    echo ""
    log_info "Mini sysroot created at:"
    echo "  ${MINI_SYSROOT}"
    echo ""
    log_info "Directory structure:"
    if [[ -d "${MINI_SYSROOT}/usr/include" ]]; then
        echo "  Headers:"
        ls -1 "${MINI_SYSROOT}/usr/include" 2>/dev/null | head -n 10 | sed 's/^/    /'
    fi
    if [[ -d "${MINI_SYSROOT}/usr/lib" ]]; then
        echo "  Libraries:"
        find "${MINI_SYSROOT}/usr/lib" -name "*.so*" 2>/dev/null | head -n 10 | sed 's/^/    /'
    fi
    echo ""
    log_info "To use this sysroot in your CMake toolchain file:"
    echo ""
    echo "  set(CMAKE_SYSROOT \"${MINI_SYSROOT}\")"
    echo "  set(CMAKE_FIND_ROOT_PATH \"${MINI_SYSROOT}\")"
    echo ""
    echo "Or for PulseAudio specifically:"
    echo ""
    echo "  set(PULSEAUDIO_INCLUDE_DIR \"${MINI_SYSROOT}/usr/include\")"
    echo "  set(PULSEAUDIO_LIBRARY \"${MINI_SYSROOT}/usr/lib/${DEBIAN_ARCH}-linux-gnu/libpulse.so\")"
    echo ""
}

# ================================================================
# 主流程
# ================================================================
main() {
    # 创建目录
    init_directories

    # 默认安装 PulseAudio (音频支持)
    log_info "Installing PulseAudio libraries..."
    install_package_group pulseaudio ${DEB_PACKAGES[pulseaudio]}

    # 可选: 安装其他依赖
    # 取消下面的注释来安装更多包
    # log_info "Installing GLib libraries..."
    # install_package_group glib ${DEB_PACKAGES[glib]}
    #
    # log_info "Installing input libraries..."
    # install_package_group input ${DEB_PACKAGES[input]}

    # 生成配置
    generate_cmake_config

    # 显示结果
    show_results

    log_ok "Target dependencies installation completed!"
}

# 执行主流程
main "$@"

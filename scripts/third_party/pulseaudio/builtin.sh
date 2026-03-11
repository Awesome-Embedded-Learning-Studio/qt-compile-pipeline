#!/usr/bin/env bash
# pulseaudio/builtin.sh - PulseAudio builtin 模式实现
# 从源码交叉编译 PulseAudio 库（使用meson构建系统）

# ================================================================
# PulseAudio builtin 模式实现
# ================================================================

# 创建日志目录并初始化日志文件
pulseaudio_builtin_init_log() {
    local log_dir="${WORK_DIR}/log"
    mkdir -p "${log_dir}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    PULSEAUDIO_BUILD_LOG="${log_dir}/pulseaudio_build_${timestamp}.log"

    export PULSEAUDIO_BUILD_LOG
}

# PulseAudio builtin 模式：检查是否已安装
pulseaudio_builtin_check() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    # 检查关键库文件
    local found_lib=0
    for lib_dir in \
        "${sysroot}/usr/lib" \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/armhf-linux-gnueabihf" \
        "${sysroot}/usr/lib/armhf-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu"
    do
        if [[ -f "${lib_dir}/libpulse.so.0" ]] || [[ -f "${lib_dir}/libpulse.so" ]]; then
            found_lib=1
            break
        fi
    done

    if [[ $found_lib -eq 0 ]]; then
        return 1
    fi

    # 检查头文件
    if [[ ! -f "${sysroot}/usr/include/pulse/pulseaudio.h" ]]; then
        return 1
    fi

    return 0
}

PULSEAUDIO_SRC_DIR=""
PULSEAUDIO_BUILD_DIR=""

# PulseAudio builtin 模式：下载源码
pulseaudio_builtin_fetch() {
    local version="${PULSEAUDIO_BUILTIN_VERSION}"
    local url="${PULSEAUDIO_BUILTIN_URL}"
    local dl_dir="${THIRD_PARTY_DL_DIR}"
    local src_dir="${THIRD_PARTY_SYSROOT}/src"
    local archive_file="${dl_dir}/pulseaudio-${version}.tar.xz"
    local extract_dir="${src_dir}/pulseaudio-${version}"

    if [[ -d "${extract_dir}" && -f "${extract_dir}/meson.build" ]]; then
        log_info "PulseAudio source already extracted: ${extract_dir}"
        PULSEAUDIO_SRC_DIR="${extract_dir}"
        return 0
    fi

    log_info "Downloading PulseAudio source (${version})..."
    if ! download_file "${url}" "${archive_file}"; then
        log_error "Failed to download PulseAudio source"
        return 1
    fi

    mkdir -p "${src_dir}"

    log_info "Extracting PulseAudio source..."
    if ! extract_archive "${archive_file}" "${src_dir}"; then
        log_error "Failed to extract PulseAudio source"
        return 1
    fi

    if [[ ! -d "${extract_dir}" ]]; then
        log_error "Source directory not found: ${extract_dir}"
        return 1
    fi

    if [[ ! -f "${extract_dir}/meson.build" ]]; then
        log_error "meson.build not found in: ${extract_dir}"
        return 1
    fi

    log_ok "PulseAudio source fetched: ${extract_dir}"
    PULSEAUDIO_SRC_DIR="${extract_dir}"
    PULSEAUDIO_BUILD_DIR="${extract_dir}/build"
    return 0
}

# PulseAudio builtin 模式：配置交叉编译（meson）
pulseaudio_builtin_configure() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"

    # 加载工具链配置
    source "${PROJECT_ROOT}/config/toolchain.conf"

    # 自动检测工具链 bin 目录
    local toolchain_bin="${TOOLCHAIN_BIN_DIR}"
    if [[ -z "${toolchain_bin}" ]]; then
        if [[ -n "${TOOLCHAIN_ROOT}" ]]; then
            toolchain_bin=$(auto_detect_toolchain_bin "${TOOLCHAIN_ROOT}" "${TOOLCHAIN_PREFIX}")
        else
            log_error "Neither TOOLCHAIN_BIN_DIR nor TOOLCHAIN_ROOT is set"
            return 1
        fi
    fi

    # 验证工具链
    local gcc_cmd="${toolchain_bin}/${TOOLCHAIN_PREFIX}gcc"
    if [[ ! -f "${gcc_cmd}" ]]; then
        log_error "Toolchain gcc not found: ${gcc_cmd}"
        return 1
    fi

    log_info "Using toolchain: ${gcc_cmd}"
    log_info "Build log: ${PULSEAUDIO_BUILD_LOG}"

    # 创建meson cross file
    local cross_file="${WORK_DIR}/pulseaudio-cross-${TARGET_ARCH:-armhf}.txt"
    cat > "$cross_file" <<EOF
[binaries]
c = '${gcc_cmd}'
cpp = '${toolchain_bin}/${TOOLCHAIN_PREFIX}g++'
ar = '${toolchain_bin}/${TOOLCHAIN_PREFIX}ar'
strip = '${toolchain_bin}/${TOOLCHAIN_PREFIX}strip'
nm = '${toolchain_bin}/${TOOLCHAIN_PREFIX}nm'
pkg-config = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'arm'
endian = 'little'

[built-in options]
prefix = '/usr'
libdir = 'lib'
sysconfdir = '/etc'
localstatedir = '/var'

[properties]
sys_root = '${THIRD_PARTY_SYSROOT}'
pkg_config_libdir = '${THIRD_PARTY_SYSROOT}/lib/pkgconfig'
EOF

    log_info "Meson cross file: ${cross_file}"

    # 创建构建目录
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    cd "${src_dir}" || return 1

    # Meson 配置选项（嵌入式精简）
    local meson_opts=(
        --prefix=/usr
        --cross-file="$cross_file"
        --libdir=lib
        --buildtype=release
        -Dstrip=true
    )

    # 禁用不需要的功能
    meson_opts+=(
        # Boolean类型选项 (true/false)
        -Ddaemon=false                  # 不编译daemon
        -Dclient=true                   # 编译客户端库
        -Ddoxygen=false                 # 不生成文档
        -Dman=false                     # 不生成man pages
        -Dtests=false                   # 不编译测试
        -Dgcov=false                    # 不生成代码覆盖
        -Dlegacy-database-entry-format=false
        -Datomic-arm-linux-helpers=false
        -Datomic-arm-memory-barrier=true
        -Dipv6=true                     # 启用IPv6
        -Dadrian-aec=false              # 禁用Adrian回声消除
        -Dbluez5-native-headset=false
        -Dbluez5-ofono-headset=false
        -Dhal-compat=false              # HAL兼容
        # Feature类型选项 (enabled/disabled/auto)
        -Dalsa=disabled                 # 禁用PulseAudio的ALSA后端
        -Djack=disabled                 # 禁用JACK
        -Doss-output=disabled           # 禁用OSS
        -Dx11=disabled                  # 禁用X11
        -Dglib=disabled                 # 禁用GLib
        -Dgtk=disabled                  # 禁用GTK
        -Ddbus=disabled                 # 禁用dbus
        -Dsystemd=disabled              # 禁用systemd
        -Dudev=disabled                 # 禁用udev
        -Davahi=disabled                # 禁用avahi
        -Dorc=disabled                  # 禁用orc优化
        -Dwebrtc-aec=disabled           # 禁用WebRTC回声消除
        -Dsamplerate=disabled           # 禁用外部samplerate
        -Dsoxr=disabled                 # 禁用soxr
        -Dbluez5=disabled               # 禁用BlueZ
        -Dfftw=disabled
        -Dopenssl=disabled
        -Dlirc=disabled
        -Dspeex=auto                    # speex resampler (自动检测)
        -Dasyncns=disabled
        -Dconsolekit=disabled
        -Delogind=disabled
        -Dgsettings=disabled
        -Dgstreamer=disabled
        -Dtcpwrap=disabled
        -Dvalgrind=disabled
        # 数据库
        -Ddatabase=simple
    )

    log_info "Configuring PulseAudio with meson..."

    if meson setup build "${meson_opts[@]}" >> "${PULSEAUDIO_BUILD_LOG}" 2>&1; then
        log_ok "PulseAudio configured successfully"
        return 0
    else
        log_error "PulseAudio configure failed - see ${PULSEAUDIO_BUILD_LOG}"
        tail -40 "${PULSEAUDIO_BUILD_LOG}" >&2
        return 1
    fi
}

# PulseAudio builtin 模式：编译（meson）
pulseaudio_builtin_build() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"
    local jobs="${PARALLEL_JOBS:-$(nproc)}"

    log_info "Building PulseAudio with meson (jobs: ${jobs})..."

    cd "${build_dir}" || return 1

    if ninja -j"${jobs}" >> "${PULSEAUDIO_BUILD_LOG}" 2>&1; then
        log_ok "PulseAudio built successfully"
        return 0
    else
        log_error "PulseAudio build failed"
        tail -40 "${PULSEAUDIO_BUILD_LOG}" >&2
        return 1
    fi
}

# PulseAudio builtin 模式：安装到 sysroot（meson）
pulseaudio_builtin_do_install() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Installing PulseAudio to sysroot..."

    cd "${build_dir}" || return 1

    # 使用DESTDIR安装
    if DESTDIR="${sysroot}" ninja install >> "${PULSEAUDIO_BUILD_LOG}" 2>&1; then
        log_ok "PulseAudio installed successfully"
        return 0
    else
        log_error "PulseAudio install failed"
        tail -30 "${PULSEAUDIO_BUILD_LOG}" >&2
        return 1
    fi
}

# PulseAudio builtin 模式：生成配置文件
pulseaudio_builtin_config() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Generating PulseAudio configuration..."

    local actual_lib_path=""
    local actual_lib_file=""

    for lib_dir in \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/armhf-linux-gnueabihf" \
        "${sysroot}/usr/lib/armhf-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu" \
        "${sysroot}/usr/lib"
    do
        if [[ -f "${lib_dir}/libpulse.so.0" ]] || [[ -f "${lib_dir}/libpulse.so" ]]; then
            actual_lib_path="${lib_dir}"
            actual_lib_file="${lib_dir}/libpulse.so"
            break
        fi
    done

    if [[ -z "$actual_lib_path" ]]; then
        log_warn "PulseAudio library not found"
        return 1
    fi

    log_info "PulseAudio library at: ${actual_lib_path}"

    # 生成CMake配置
    local cmake_dir="${sysroot}/lib/cmake/PulseAudio"
    mkdir -p "$cmake_dir"

    cat > "${cmake_dir}/PulseAudioConfig.cmake" <<EOF
# PulseAudio CMake configuration
# Auto-generated by third_party/pulseaudio/builtin.sh

set(PULSEAUDIO_LIBRARY "${actual_lib_file}")
set(PULSEAUDIO_INCLUDE_DIR "${sysroot}/usr/include")
set(PULSEAUDIO_LIBDIR "${actual_lib_path}")

if(NOT TARGET PulseAudio::pulse)
    add_library(PulseAudio::pulse SHARED IMPORTED)
    set_target_properties(PulseAudio::pulse PROPERTIES
        IMPORTED_LOCATION "${actual_lib_file}"
        INTERFACE_INCLUDE_DIRECTORIES "\${PULSEAUDIO_INCLUDE_DIR}"
    )
endif()

set(PulseAudio_FOUND TRUE)
EOF

    # 生成pkg-config
    local pkgconfig_dir="${sysroot}/lib/pkgconfig"
    mkdir -p "$pkgconfig_dir"

    cat > "${pkgconfig_dir}/libpulse.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libpulse
Description: PulseAudio Client Interface
Version: ${PULSEAUDIO_BUILTIN_VERSION}
Libs: -L\${libdir} -lpulse
Cflags: -I\${includedir}
EOF

    log_ok "PulseAudio configuration generated"
    return 0
}

# PulseAudio builtin 模式：安装（主流程）
pulseaudio_builtin_install() {
    pulseaudio_builtin_init_log
    log_info "PulseAudio build log: ${PULSEAUDIO_BUILD_LOG}"

    if pulseaudio_builtin_check; then
        log_info "PulseAudio already installed, skipping..."
        return 0
    fi

    log_info "Installing PulseAudio..."

    if ! pulseaudio_builtin_fetch; then
        log_error "Failed to fetch PulseAudio source"
        return 1
    fi

    if ! pulseaudio_builtin_configure "$PULSEAUDIO_SRC_DIR"; then
        log_error "Failed to configure PulseAudio"
        return 1
    fi

    if ! pulseaudio_builtin_build "$PULSEAUDIO_SRC_DIR"; then
        log_error "Failed to build PulseAudio"
        return 1
    fi

    if ! pulseaudio_builtin_do_install "$PULSEAUDIO_SRC_DIR"; then
        log_error "Failed to install PulseAudio"
        return 1
    fi

    if ! pulseaudio_builtin_config; then
        log_warn "Failed to generate config (non-critical)"
    fi

    log_ok "PulseAudio installation completed"
    return 0
}

# PulseAudio builtin 模式：清理
pulseaudio_builtin_clean() {
    local sysroot="${THIRD_PARTY_SYSROOT}"
    local deb_arch="${TARGET_ARCH:-armhf}"

    log_info "Cleaning PulseAudio..."

    rm -rf "${sysroot}/usr/include/pulse"
    rm -f "${sysroot}/usr/lib/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnueabihf/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnu/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/${deb_arch}-linux-gnueabihf/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/${deb_arch}-linux-gnu/"libpulse*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libpulse*.so*
    rm -rf "${sysroot}/lib/cmake/PulseAudio"
    rm -f "${sysroot}/lib/pkgconfig/libpulse*.pc"

    rm -rf "${sysroot}/src/pulseaudio-"*
    rm -f "${WORK_DIR}/pulseaudio-cross-"*.txt

    log_ok "PulseAudio cleaned"
}

#!/usr/bin/env bash
# libsndfile/builtin.sh - libsndfile builtin 模式实现
# 从源码交叉编译 libsndfile 库（PulseAudio依赖）

# ================================================================
# libsndfile builtin 模式实现
# ================================================================

# 创建日志目录并初始化日志文件
libsndfile_builtin_init_log() {
    local log_dir="${WORK_DIR}/log"
    mkdir -p "${log_dir}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    SNDFILE_BUILD_LOG="${log_dir}/libsndfile_build_${timestamp}.log"

    export SNDFILE_BUILD_LOG
}

# libsndfile builtin 模式：检查是否已安装
libsndfile_builtin_check() {
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
        if [[ -f "${lib_dir}/libsndfile.so" ]]; then
            found_lib=1
            break
        fi
    done

    if [[ $found_lib -eq 0 ]]; then
        return 1
    fi

    # 检查头文件
    if [[ ! -f "${sysroot}/usr/include/sndfile.h" ]]; then
        return 1
    fi

    return 0
}

SNDFILE_SRC_DIR=""

# libsndfile builtin 模式：下载源码
libsndfile_builtin_fetch() {
    local version="${SNDFILE_BUILTIN_VERSION}"
    local url="${SNDFILE_BUILTIN_URL}"
    local dl_dir="${THIRD_PARTY_DL_DIR}"
    local src_dir="${THIRD_PARTY_SYSROOT}/src"
    local archive_file="${dl_dir}/libsndfile-${version}.tar.xz"
    local extract_dir="${src_dir}/libsndfile-${version}"

    if [[ -d "${extract_dir}" && -f "${extract_dir}/configure" ]]; then
        log_info "libsndfile source already extracted: ${extract_dir}"
        SNDFILE_SRC_DIR="${extract_dir}"
        return 0
    fi

    log_info "Downloading libsndfile source (${version})..."
    if ! download_file "${url}" "${archive_file}"; then
        log_error "Failed to download libsndfile source"
        return 1
    fi

    mkdir -p "${src_dir}"

    log_info "Extracting libsndfile source..."
    if ! extract_archive "${archive_file}" "${src_dir}"; then
        log_error "Failed to extract libsndfile source"
        return 1
    fi

    if [[ ! -d "${extract_dir}" ]]; then
        log_error "Source directory not found: ${extract_dir}"
        return 1
    fi

    if [[ ! -f "${extract_dir}/configure" ]]; then
        log_error "Configure script not found in: ${extract_dir}"
        return 1
    fi

    log_ok "libsndfile source fetched: ${extract_dir}"
    SNDFILE_SRC_DIR="${extract_dir}"
    return 0
}

# libsndfile builtin 模式：配置交叉编译
libsndfile_builtin_configure() {
    local src_dir="$1"

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
    log_info "Build log: ${SNDFILE_BUILD_LOG}"

    # 准备 --host 参数
    local hostTriple="${TOOLCHAIN_PREFIX%-}"

    # 准备环境变量
    export CC="${gcc_cmd}"
    export CXX="${toolchain_bin}/${TOOLCHAIN_PREFIX}g++"
    export AR="${toolchain_bin}/${TOOLCHAIN_PREFIX}ar"
    export STRIP="${toolchain_bin}/${TOOLCHAIN_PREFIX}strip"
    export RANLIB="${toolchain_bin}/${TOOLCHAIN_PREFIX}ranlib"
    export NM="${toolchain_bin}/${TOOLCHAIN_PREFIX}nm"

    # 设置C标准（避免C23关键字冲突）
    export CFLAGS="-std=c99 ${CFLAGS:-}"
    export CPPFLAGS="-D_GNU_SOURCE ${CPPFLAGS:-}"

    # 设置 PKG_CONFIG 环境变量
    export PKG_CONFIG_PATH=""
    export PKG_CONFIG_LIBDIR="${THIRD_PARTY_SYSROOT}/usr/lib/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR="${THIRD_PARTY_SYSROOT}"

    # libsndfile configure 参数
    local configure_opts=(
        --host="${hostTriple}"
        --prefix=/usr
        --disable-static
        --enable-shared
        --disable-sqlite
        --disable-external-libs
        --disable-mpeg
        --disable-full-suite
    )

    log_info "Configuring libsndfile with cross-compilation..."

    cd "${src_dir}" || return 1

    if ./configure "${configure_opts[@]}" >> "${SNDFILE_BUILD_LOG}" 2>&1; then
        log_ok "libsndfile configured successfully"
        return 0
    else
        log_error "libsndfile configure failed - see ${SNDFILE_BUILD_LOG}"
        tail -40 "${SNDFILE_BUILD_LOG}" >&2
        return 1
    fi
}

# libsndfile builtin 模式：编译
libsndfile_builtin_build() {
    local src_dir="$1"
    local jobs="${PARALLEL_JOBS:-$(nproc)}"

    log_info "Building libsndfile (jobs: ${jobs})..."

    cd "${src_dir}" || return 1

    if make -j"${jobs}" >> "${SNDFILE_BUILD_LOG}" 2>&1; then
        log_ok "libsndfile built successfully"
        return 0
    else
        log_error "libsndfile build failed"
        tail -40 "${SNDFILE_BUILD_LOG}" >&2
        return 1
    fi
}

# libsndfile builtin 模式：安装到 sysroot
libsndfile_builtin_do_install() {
    local src_dir="$1"
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Installing libsndfile to sysroot..."

    cd "${src_dir}" || return 1

    if make install DESTDIR="${sysroot}" >> "${SNDFILE_BUILD_LOG}" 2>&1; then
        log_ok "libsndfile installed successfully"
        return 0
    else
        log_error "libsndfile install failed"
        tail -30 "${SNDFILE_BUILD_LOG}" >&2
        return 1
    fi
}

# libsndfile builtin 模式：生成配置文件
libsndfile_builtin_config() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Generating libsndfile configuration..."

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
        if [[ -f "${lib_dir}/libsndfile.so" ]]; then
            actual_lib_path="${lib_dir}"
            actual_lib_file="${lib_dir}/libsndfile.so"
            break
        fi
    done

    if [[ -z "$actual_lib_path" ]]; then
        log_warn "libsndfile library not found"
        return 1
    fi

    log_info "libsndfile library at: ${actual_lib_path}"

    # 生成pkg-config
    local pkgconfig_dir="${sysroot}/lib/pkgconfig"
    mkdir -p "$pkgconfig_dir"

    cat > "${pkgconfig_dir}/sndfile.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: sndfile
Description: A C library for reading and writing sound files
Version: ${SNDFILE_BUILTIN_VERSION}
Libs: -L\${libdir} -lsndfile
Cflags: -I\${includedir}
EOF

    log_ok "libsndfile configuration generated"
    return 0
}

# libsndfile builtin 模式：安装（主流程）
libsndfile_builtin_install() {
    libsndfile_builtin_init_log
    log_info "libsndfile build log: ${SNDFILE_BUILD_LOG}"

    if libsndfile_builtin_check; then
        log_info "libsndfile already installed, skipping..."
        return 0
    fi

    log_info "Installing libsndfile..."

    if ! libsndfile_builtin_fetch; then
        log_error "Failed to fetch libsndfile source"
        return 1
    fi

    if ! libsndfile_builtin_configure "$SNDFILE_SRC_DIR"; then
        log_error "Failed to configure libsndfile"
        return 1
    fi

    if ! libsndfile_builtin_build "$SNDFILE_SRC_DIR"; then
        log_error "Failed to build libsndfile"
        return 1
    fi

    if ! libsndfile_builtin_do_install "$SNDFILE_SRC_DIR"; then
        log_error "Failed to install libsndfile"
        return 1
    fi

    if ! libsndfile_builtin_config; then
        log_warn "Failed to generate config (non-critical)"
    fi

    log_ok "libsndfile installation completed"
    return 0
}

# libsndfile builtin 模式：清理
libsndfile_builtin_clean() {
    local sysroot="${THIRD_PARTY_SYSROOT}"
    local deb_arch="${TARGET_ARCH:-armhf}"

    log_info "Cleaning libsndfile..."

    rm -f "${sysroot}/usr/include/sndfile.hh"
    rm -f "${sysroot}/usr/include/sndfile.h"
    rm -f "${sysroot}/usr/lib/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/"libsndfile*.la
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnueabihf/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnu/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/${deb_arch}-linux-gnueabihf/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/${deb_arch}-linux-gnu/"libsndfile*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libsndfile*.so*
    rm -f "${sysroot}/lib/pkgconfig/sndfile.pc"

    rm -rf "${sysroot}/src/libsndfile-"*

    log_ok "libsndfile cleaned"
}

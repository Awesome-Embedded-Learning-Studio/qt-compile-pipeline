#!/usr/bin/env bash
# tslib/builtin.sh - tslib builtin 模式实现
# 从源码交叉编译 tslib 库（触摸屏校准库）

# ================================================================
# tslib builtin 模式实现
# ================================================================

# 创建日志目录并初始化日志文件
tslib_builtin_init_log() {
    local log_dir="${WORK_DIR}/log"
    mkdir -p "${log_dir}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    TSLIB_BUILD_LOG="${log_dir}/tslib_build_${timestamp}.log"

    export TSLIB_BUILD_LOG
}

# tslib builtin 模式：检查是否已安装
tslib_builtin_check() {
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
        if [[ -f "${lib_dir}/libts.so" ]] || [[ -f "${lib_dir}/libts.so.0" ]]; then
            found_lib=1
            break
        fi
    done

    if [[ $found_lib -eq 0 ]]; then
        return 1
    fi

    # 检查头文件
    if [[ ! -f "${sysroot}/usr/include/tslib/libts.h" ]]; then
        return 1
    fi

    # 检查 pkg-config
    if [[ ! -f "${sysroot}/usr/lib/pkgconfig/tslib.pc" ]]; then
        return 1
    fi

    return 0
}

TSLIB_SRC_DIR=""

# tslib builtin 模式：下载源码
tslib_builtin_fetch() {
    local version="${TSLIB_BUILTIN_VERSION}"
    local url="${TSLIB_BUILTIN_URL}"
    local dl_dir="${THIRD_PARTY_DL_DIR}"
    local src_dir="${THIRD_PARTY_SYSROOT}/src"
    local archive_file="${dl_dir}/tslib-${version}.tar.xz"
    local extract_dir="${src_dir}/tslib-${version}"

    # 检查是否已解压
    if [[ -d "${extract_dir}" && -f "${extract_dir}/configure" ]]; then
        log_info "tslib source already extracted: ${extract_dir}"
        TSLIB_SRC_DIR="${extract_dir}"
        return 0
    fi

    # 下载源码包
    log_info "Downloading tslib source (${version})..."
    if ! download_file "${url}" "${archive_file}"; then
        log_error "Failed to download tslib source"
        return 1
    fi

    # 创建源码目录
    mkdir -p "${src_dir}"

    # 解压源码
    log_info "Extracting tslib source..."
    if ! extract_archive "${archive_file}" "${src_dir}"; then
        log_error "Failed to extract tslib source"
        return 1
    fi

    # 验证解压结果
    if [[ ! -d "${extract_dir}" ]]; then
        log_error "Source directory not found after extraction: ${extract_dir}"
        return 1
    fi

    if [[ ! -f "${extract_dir}/configure" ]]; then
        log_error "Configure script not found in: ${extract_dir}"
        return 1
    fi

    log_ok "tslib source fetched successfully: ${extract_dir}"
    TSLIB_SRC_DIR="${extract_dir}"
    return 0
}

# tslib builtin 模式：配置交叉编译（autotools）
tslib_builtin_configure() {
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
    log_info "Build log: ${TSLIB_BUILD_LOG}"

    # 准备交叉编译前缀
    local cross_prefix="${toolchain_bin}/${TOOLCHAIN_PREFIX}"
    local host_arch="${TOOLCHAIN_PREFIX%-}"

    # tsbis configure 参数
    local configure_opts=(
        "--host=${host_arch}"
        "--prefix=/usr"
        "--enable-shared=yes"
        "--enable-static=no"
    )

    # 设置环境变量
    export CC="${cross_prefix}gcc"
    export CXX="${cross_prefix}g++"
    export AR="${cross_prefix}ar"
    export STRIP="${cross_prefix}strip"
    export RANLIB="${cross_prefix}ranlib"
    export PKG_CONFIG_PATH=""
    export PKG_CONFIG_LIBDIR=""

    log_info "Configuring tslib with autotools..."

    cd "${src_dir}" || return 1

    # 执行 configure
    if ./configure "${configure_opts[@]}" >> "${TSLIB_BUILD_LOG}" 2>&1; then
        log_ok "tslib configured successfully"
        return 0
    else
        log_error "tslib configure failed - see ${TSLIB_BUILD_LOG} for details"
        tail -30 "${TSLIB_BUILD_LOG}" >&2
        return 1
    fi
}

# tslib builtin 模式：编译
tslib_builtin_build() {
    local src_dir="$1"
    local jobs="${PARALLEL_JOBS:-$(nproc)}"

    log_info "Building tslib (jobs: ${jobs})..."

    cd "${src_dir}" || return 1

    if make -j"${jobs}" >> "${TSLIB_BUILD_LOG}" 2>&1; then
        log_ok "tslib built successfully"
        return 0
    else
        log_error "tslib build failed - see ${TSLIB_BUILD_LOG} for details"
        tail -40 "${TSLIB_BUILD_LOG}" >&2
        return 1
    fi
}

# tslib builtin 模式：安装到 sysroot
tslib_builtin_do_install() {
    local src_dir="$1"
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Installing tslib to sysroot..."

    cd "${src_dir}" || return 1

    # 使用 DESTDIR 安装到 sysroot
    if make install DESTDIR="${sysroot}" >> "${TSLIB_BUILD_LOG}" 2>&1; then
        log_ok "tslib installed successfully"
        return 0
    else
        log_error "tslib install failed"
        tail -20 "${TSLIB_BUILD_LOG}" >&2
        return 1
    fi
}

# tslib builtin 模式：生成配置文件
tslib_builtin_config() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Generating tslib configuration..."

    # 查找库路径
    local lib_dir=""
    local lib_ts=""

    for dir in \
        "${sysroot}/usr/lib" \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu"
    do
        if [[ -f "${dir}/libts.so" ]] || [[ -f "${dir}/libts.so.0" ]]; then
            lib_dir="${dir}"
            lib_ts="${dir}/libts.so"
            break
        fi
    done

    if [[ -z "$lib_dir" ]]; then
        log_warn "tslib libraries not found"
        return 1
    fi

    log_info "tslib library at: ${lib_dir}"

    # 生成 CMake 配置
    local cmake_dir="${sysroot}/lib/cmake/tslib"
    mkdir -p "$cmake_dir"

    cat > "${cmake_dir}/tslibConfig.cmake" <<'EOF'
# tslib CMake configuration
# Auto-generated by third_party/tslib/builtin.sh

if(NOT DEFINED TSLIB_FOUND)
    set(TSLIB_FOUND TRUE)
    set(TSLIB_VERSION "@TSLIB_VERSION@")
endif()

# 设置库路径
set(TSLIB_LIBRARY @TSLIB_LIB@)
set(TSLIB_LIBRARIES ${TSLIB_LIBRARY})
set(TSLIB_INCLUDE_DIR @TSLIB_INCLUDE_DIR@)

# 创建导入目标
if(NOT TARGET tslib::tslib)
    add_library(tslib::tslib SHARED IMPORTED)
    set_target_properties(tslib::tslib PROPERTIES
        IMPORTED_LOCATION "${TSLIB_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${TSLIB_INCLUDE_DIR}"
    )
endif()
EOF

    # 替换占位符
    sed -i "s|@TSLIB_LIB@|${lib_ts}|g" "${cmake_dir}/tslibConfig.cmake"
    sed -i "s|@TSLIB_INCLUDE_DIR@|${sysroot}/usr/include|g" "${cmake_dir}/tslibConfig.cmake"
    sed -i "s|@TSLIB_VERSION@|${TSLIB_BUILTIN_VERSION}|g" "${cmake_dir}/tslibConfig.cmake"

    log_ok "tslib configuration generated"
    return 0
}

# tslib builtin 模式：安装（主流程）
tslib_builtin_install() {
    tslib_builtin_init_log
    log_info "tslib build log: ${TSLIB_BUILD_LOG}"

    # 使用统一的标记文件检查（由 manager.sh 管理）
    if third_party_is_installed "tslib"; then
        log_info "tslib already installed, skipping..."
        return 0
    fi

    log_info "Installing tslib..."

    if ! tslib_builtin_fetch; then
        log_error "Failed to fetch tslib source"
        return 1
    fi

    if ! tslib_builtin_configure "$TSLIB_SRC_DIR"; then
        log_error "Failed to configure tslib"
        return 1
    fi

    if ! tslib_builtin_build "$TSLIB_SRC_DIR"; then
        log_error "Failed to build tslib"
        return 1
    fi

    if ! tslib_builtin_do_install "$TSLIB_SRC_DIR"; then
        log_error "Failed to install tslib"
        return 1
    fi

    if ! tslib_builtin_config; then
        log_warn "Failed to generate config (non-critical)"
    fi

    log_ok "tslib installation completed"
    log_info "Full build log: ${TSLIB_BUILD_LOG}"
    return 0
}

# tslib builtin 模式：清理
tslib_builtin_clean() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Cleaning tslib..."

    rm -rf "${sysroot}/usr/include/tslib"
    rm -f "${sysroot}/usr/lib/"libts*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libts*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libts*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnueabihf/"libts*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnu/"libts*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libts*.so*
    rm -f "${sysroot}/usr/lib/pkgconfig/tslib.pc"
    rm -rf "${sysroot}/lib/cmake/tslib"

    rm -rf "${sysroot}/src/tslib-"*
    rm -f "${sysroot}/.tslib-installed"

    log_ok "tslib cleaned"
}

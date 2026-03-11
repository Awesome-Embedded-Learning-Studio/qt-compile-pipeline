#!/usr/bin/env bash
# openssl/builtin.sh - OpenSSL builtin 模式实现
# 从源码交叉编译 OpenSSL 库（Qt Network HTTPS 支持需要）

# ================================================================
# OpenSSL builtin 模式实现
# ================================================================

# 创建日志目录并初始化日志文件
openssl_builtin_init_log() {
    local log_dir="${WORK_DIR}/log"
    mkdir -p "${log_dir}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    OPENSSL_BUILD_LOG="${log_dir}/openssl_build_${timestamp}.log"

    export OPENSSL_BUILD_LOG
}

# OpenSSL builtin 模式：检查是否已安装
openssl_builtin_check() {
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
        if [[ -f "${lib_dir}/libssl.so" ]] || [[ -f "${lib_dir}/libssl.so.3" ]]; then
            found_lib=1
            break
        fi
    done

    if [[ $found_lib -eq 0 ]]; then
        return 1
    fi

    # 检查头文件
    if [[ ! -f "${sysroot}/usr/include/openssl/ssl.h" ]]; then
        return 1
    fi

    return 0
}

OPENSSL_SRC_DIR=""

# OpenSSL builtin 模式：下载源码
openssl_builtin_fetch() {
    local version="${OPENSSL_BUILTIN_VERSION}"
    local url="${OPENSSL_BUILTIN_URL}"
    local dl_dir="${THIRD_PARTY_DL_DIR}"
    local src_dir="${THIRD_PARTY_SYSROOT}/src"
    local archive_file="${dl_dir}/openssl-${version}.tar.gz"
    local extract_dir="${src_dir}/openssl-${version}"

    # 检查是否已解压
    if [[ -d "${extract_dir}" && -f "${extract_dir}/Configure" ]]; then
        log_info "OpenSSL source already extracted: ${extract_dir}"
        OPENSSL_SRC_DIR="${extract_dir}"
        return 0
    fi

    # 下载源码包
    log_info "Downloading OpenSSL source (${version})..."
    if ! download_file "${url}" "${archive_file}"; then
        log_error "Failed to download OpenSSL source"
        return 1
    fi

    # 创建源码目录
    mkdir -p "${src_dir}"

    # 解压源码
    log_info "Extracting OpenSSL source..."
    if ! extract_archive "${archive_file}" "${src_dir}"; then
        log_error "Failed to extract OpenSSL source"
        return 1
    fi

    # 验证解压结果
    if [[ ! -d "${extract_dir}" ]]; then
        log_error "Source directory not found after extraction: ${extract_dir}"
        return 1
    fi

    if [[ ! -f "${extract_dir}/Configure" ]]; then
        log_error "Configure script not found in: ${extract_dir}"
        return 1
    fi

    log_ok "OpenSSL source fetched successfully: ${extract_dir}"
    OPENSSL_SRC_DIR="${extract_dir}"
    return 0
}

# 检测 OpenSSL 目标平台
openssl_detect_target() {
    local prefix="${TOOLCHAIN_PREFIX}"

    # 去掉末尾的连字符
    prefix="${prefix%-}"

    case "$prefix" in
        arm-linux-gnueabihf|armv7hl-linux-gnueabihf)
            # ARMv7-A hard float (i.MX6ULL, Raspberry Pi 等)
            # linux-armv4 是 OpenSSL 的通用 ARM 目标
            # 通过 CFLAGS 优化为 ARMv7-A
            echo "linux-armv4"
            ;;
        arm-linux-gnueabi|arm-linux-gnu)
            echo "linux-armv4"
            ;;
        aarch64-linux-gnu|aarch64-linux-gnu)
            echo "linux-aarch64"
            ;;
        x86_64-linux-gnu)
            echo "linux-x86_64"
            ;;
        *)
            # 默认使用 linux-armv4
            echo "linux-armv4"
            ;;
    esac
}

# 检测 OpenSSL 编译优化标志（针对具体 SoC）
openssl_detect_cflags() {
    local prefix="${TOOLCHAIN_PREFIX}"
    prefix="${prefix%-}"

    case "$prefix" in
        arm-linux-gnueabihf)
            # i.MX6ULL 是 Cortex-A7 (ARMv7-A, VFPv4)
            # 使用 neon 可加速加密算法
            echo "-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
            ;;
        arm-linux-gnueabi)
            echo "-march=armv7-a"
            ;;
        aarch64-linux-gnu)
            echo "-march=armv8-a"
            ;;
        *)
            echo ""
            ;;
    esac
}

# OpenSSL builtin 模式：配置交叉编译
openssl_builtin_configure() {
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
    log_info "Build log: ${OPENSSL_BUILD_LOG}"

    # 检测 OpenSSL 目标平台和优化标志
    local openssl_target="${OPENSSL_TARGET:-$(openssl_detect_target)}"
    local openssl_cflags="$(openssl_detect_cflags)"

    log_info "OpenSSL target: ${openssl_target}"
    if [[ -n "$openssl_cflags" ]]; then
        log_info "OpenSSL CFLAGS: ${openssl_cflags}"
    fi

    cd "${src_dir}" || return 1

    # 设置交叉编译环境
    export CC="${toolchain_bin}/${TOOLCHAIN_PREFIX}gcc"
    export CXX="${toolchain_bin}/${TOOLCHAIN_PREFIX}g++"
    export AR="${toolchain_bin}/${TOOLCHAIN_PREFIX}ar"
    export RANLIB="${toolchain_bin}/${TOOLCHAIN_PREFIX}ranlib"
    export NM="${toolchain_bin}/${TOOLCHAIN_PREFIX}nm"
    export STRIP="${toolchain_bin}/${TOOLCHAIN_PREFIX}strip"

    # 设置架构优化标志（i.MX6ULL = ARM Cortex-A7）
    if [[ -n "$openssl_cflags" ]]; then
        export CFLAGS="${openssl_cflags} -O2"
        export CXXFLAGS="${openssl_cflags} -O2"
    else
        export CFLAGS="-O2"
        export CXXFLAGS="-O2"
    fi

    # OpenSSL Configure 参数
    # 注意：使用 Configure (Perl) 而非 config
    # 注意：交叉编译通过环境变量 CC/CXX/AR 等设置，不使用 --cross-compile-prefix
    local configure_opts=(
        "${openssl_target}"
        "--prefix=/usr"
        "--openssldir=/etc/ssl"
        # 共享库（Qt 需要动态链接）
        "shared"
        # 精简配置（嵌入式）
        "no-tests"
        "no-docs"
        "no-apps"
        # 禁用不需要的功能
        "no-asm"
        "no-afalgeng"
        "no-ec_nistp_64_gcc_128"
        "no-md2"
        "no-rc5"
        "no-sctp"
        "no-ssl3"
        "no-ssl3-method"
        "no-weak-ssl-ciphers"
        "no-zlib"
        "no-zlib-dynamic"
        "no-engine"
        "no-ui-console"
        "no-stdio"
    )

    log_info "Configuring OpenSSL..."

    # 执行 Configure（Configure 是 Perl 脚本，可直接执行）
    if "${src_dir}/Configure" "${configure_opts[@]}" \
        >> "${OPENSSL_BUILD_LOG}" 2>&1; then
        log_ok "OpenSSL configured successfully"
        return 0
    else
        log_error "OpenSSL configure failed - see ${OPENSSL_BUILD_LOG} for details"
        tail -30 "${OPENSSL_BUILD_LOG}" >&2
        return 1
    fi
}

# OpenSSL builtin 模式：编译
openssl_builtin_build() {
    local src_dir="$1"
    local jobs="${PARALLEL_JOBS:-$(nproc)}"

    log_info "Building OpenSSL (jobs: ${jobs})..."

    cd "${src_dir}" || return 1

    # 使用 make 构建
    if make -j"${jobs}" >> "${OPENSSL_BUILD_LOG}" 2>&1; then
        log_ok "OpenSSL built successfully"
        return 0
    else
        log_error "OpenSSL build failed - see ${OPENSSL_BUILD_LOG} for details"
        tail -40 "${OPENSSL_BUILD_LOG}" >&2
        return 1
    fi
}

# OpenSSL builtin 模式：安装到 sysroot
openssl_builtin_do_install() {
    local src_dir="$1"
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Installing OpenSSL to sysroot..."

    cd "${src_dir}" || return 1

    # 使用 DESTDIR 安装到 sysroot
    if make install DESTDIR="${sysroot}" >> "${OPENSSL_BUILD_LOG}" 2>&1; then
        log_ok "OpenSSL installed successfully"

        # 查找库目录并创建符号链接
        # OpenSSL 3.x 安装 libssl.so.3 和 libcrypto.so.3
        # Qt 需要不带版本号的符号链接 (libssl.so, libcrypto.so)
        local lib_dir=""
        for dir in \
            "${sysroot}/usr/lib" \
            "${sysroot}/usr/lib/arm-linux-gnueabihf" \
            "${sysroot}/usr/lib/aarch64-linux-gnu"
        do
            if [[ -d "${dir}" ]] && ls "${dir}"/libssl.so* >/dev/null 2>&1; then
                lib_dir="${dir}"
                break
            fi
        done

        if [[ -n "$lib_dir" ]]; then
            log_info "OpenSSL libraries at: ${lib_dir}"

            # 查找实际的共享库并创建符号链接
            local ssl_lib=$(find "${lib_dir}" -maxdepth 1 -name "libssl.so.[0-9]*" -type f 2>/dev/null | head -1)
            local crypto_lib=$(find "${lib_dir}" -maxdepth 1 -name "libcrypto.so.[0-9]*" -type f 2>/dev/null | head -1)

            if [[ -n "$ssl_lib" ]]; then
                local ssl_basename=$(basename "$ssl_lib")
                ln -sf "$ssl_basename" "${lib_dir}/libssl.so"
                log_info "Created symlink: libssl.so -> ${ssl_basename}"
            fi

            if [[ -n "$crypto_lib" ]]; then
                local crypto_basename=$(basename "$crypto_lib")
                ln -sf "$crypto_basename" "${lib_dir}/libcrypto.so"
                log_info "Created symlink: libcrypto.so -> ${crypto_basename}"
            fi
        fi

        return 0
    else
        log_error "OpenSSL install failed"
        tail -20 "${OPENSSL_BUILD_LOG}" >&2
        return 1
    fi
}

# OpenSSL builtin 模式：生成配置文件
openssl_builtin_config() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Generating OpenSSL configuration..."

    # 查找库路径
    local lib_dir=""
    local lib_ssl=""
    local lib_crypto=""

    for dir in \
        "${sysroot}/usr/lib" \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu"
    do
        if [[ -f "${dir}/libssl.so" ]] || [[ -f "${dir}/libssl.so.3" ]]; then
            lib_dir="${dir}"
            lib_ssl="${dir}/libssl.so"
            lib_crypto="${dir}/libcrypto.so"
            break
        fi
    done

    if [[ -z "$lib_dir" ]]; then
        log_warn "OpenSSL libraries not found"
        return 1
    fi

    log_info "OpenSSL library at: ${lib_dir}"

    # 生成 CMake 配置
    local cmake_dir="${sysroot}/lib/cmake/OpenSSL"
    mkdir -p "$cmake_dir"

    cat > "${cmake_dir}/OpenSSLConfig.cmake" <<'EOF'
# OpenSSL CMake configuration
# Auto-generated by third_party/openssl/builtin.sh

if(NOT DEFINED OPENSSL_FOUND)
    set(OPENSSL_FOUND TRUE)
    set(OPENSSL_VERSION "@OPENSSL_VERSION@")
endif()

# 设置库路径
set(OPENSSL_SSL_LIBRARY @OPENSSL_SSL_LIB@)
set(OPENSSL_CRYPTO_LIBRARY @OPENSSL_CRYPTO_LIB@)
set(OPENSSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARY})
set(OPENSSL_INCLUDE_DIR @OPENSSL_INCLUDE_DIR@)

# 创建导入目标
if(NOT TARGET OpenSSL::SSL)
    add_library(OpenSSL::SSL STATIC IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_LOCATION "${OPENSSL_SSL_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    )
endif()

if(NOT TARGET OpenSSL::Crypto)
    add_library(OpenSSL::Crypto STATIC IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
    )
endif()

if(NOT TARGET OpenSSL::OpenSSL)
    add_library(OpenSSL::OpenSSL INTERFACE IMPORTED)
    set_property(TARGET OpenSSL::OpenSSL PROPERTY
        INTERFACE_LINK_LIBRARIES OpenSSL::SSL
    )
endif()
EOF

    # 替换占位符
    sed -i "s|@OPENSSL_SSL_LIB@|${lib_ssl}|g" "${cmake_dir}/OpenSSLConfig.cmake"
    sed -i "s|@OPENSSL_CRYPTO_LIB@|${lib_crypto}|g" "${cmake_dir}/OpenSSLConfig.cmake"
    sed -i "s|@OPENSSL_INCLUDE_DIR@|${sysroot}/usr/include|g" "${cmake_dir}/OpenSSLConfig.cmake"
    sed -i "s|@OPENSSL_VERSION@|${OPENSSL_BUILTIN_VERSION}|g" "${cmake_dir}/OpenSSLConfig.cmake"

    # 生成 pkg-config
    local pkgconfig_dir="${sysroot}/lib/pkgconfig"
    mkdir -p "$pkgconfig_dir"

    cat > "${pkgconfig_dir}/openssl.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${lib_dir#$sysroot}
includedir=\${prefix}/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries and tools
Version: ${OPENSSL_BUILTIN_VERSION}
Libs: -L\${libdir} -lssl -lcrypto
Libs.private: -ldl -lpthread
Cflags: -I\${includedir}
EOF

    cat > "${pkgconfig_dir}/libssl.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${lib_dir#$sysroot}
includedir=\${prefix}/include

Name: SSL
Description: Secure Sockets Layer library
Version: ${OPENSSL_BUILTIN_VERSION}
Libs: -L\${libdir} -lssl
Libs.private: -lcrypto
Cflags: -I\${includedir}
EOF

    cat > "${pkgconfig_dir}/libcrypto.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${lib_dir#$sysroot}
includedir=\${prefix}/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: ${OPENSSL_BUILTIN_VERSION}
Libs: -L\${libdir} -lcrypto
Libs.private: -ldl -lpthread
Cflags: -I\${includedir}
EOF

    log_ok "OpenSSL configuration generated"
    return 0
}

# OpenSSL builtin 模式：安装（主流程）
openssl_builtin_install() {
    openssl_builtin_init_log
    log_info "OpenSSL build log: ${OPENSSL_BUILD_LOG}"

    if openssl_builtin_check; then
        log_info "OpenSSL already installed, skipping..."
        return 0
    fi

    log_info "Installing OpenSSL..."

    if ! openssl_builtin_fetch; then
        log_error "Failed to fetch OpenSSL source"
        return 1
    fi

    if ! openssl_builtin_configure "$OPENSSL_SRC_DIR"; then
        log_error "Failed to configure OpenSSL"
        return 1
    fi

    if ! openssl_builtin_build "$OPENSSL_SRC_DIR"; then
        log_error "Failed to build OpenSSL"
        return 1
    fi

    if ! openssl_builtin_do_install "$OPENSSL_SRC_DIR"; then
        log_error "Failed to install OpenSSL"
        return 1
    fi

    if ! openssl_builtin_config; then
        log_warn "Failed to generate config (non-critical)"
    fi

    log_ok "OpenSSL installation completed"
    log_info "Full build log: ${OPENSSL_BUILD_LOG}"
    return 0
}

# OpenSSL builtin 模式：清理
openssl_builtin_clean() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Cleaning OpenSSL..."

    rm -rf "${sysroot}/usr/include/openssl"
    rm -f "${sysroot}/usr/lib/"libssl*.so*
    rm -f "${sysroot}/usr/lib/"libssl*.a
    rm -f "${sysroot}/usr/lib/"libcrypto*.so*
    rm -f "${sysroot}/usr/lib/"libcrypto*.a
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libssl*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libssl*.a
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libcrypto*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libcrypto*.a
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libssl*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libssl*.a
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libcrypto*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libcrypto*.a
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libssl*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libssl*.a
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libcrypto*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libcrypto*.a
    rm -rf "${sysroot}/usr/lib/ssl"
    rm -rf "${sysroot}/lib/cmake/OpenSSL"
    rm -f "${sysroot}/lib/pkgconfig/openssl.pc"
    rm -f "${sysroot}/lib/pkgconfig/libssl.pc"
    rm -f "${sysroot}/lib/pkgconfig/libcrypto.pc"

    rm -rf "${sysroot}/src/openssl-"*

    log_ok "OpenSSL cleaned"
}

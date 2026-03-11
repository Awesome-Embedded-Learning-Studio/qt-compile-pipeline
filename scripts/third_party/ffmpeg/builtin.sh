#!/usr/bin/env bash
# ffmpeg/builtin.sh - FFmpeg builtin 模式实现
# 从源码交叉编译 FFmpeg 库

# ================================================================
# FFmpeg builtin 模式实现
# ================================================================

# 创建日志目录并初始化日志文件
ffmpeg_builtin_init_log() {
    local log_dir="${WORK_DIR}/log"
    mkdir -p "${log_dir}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    FFMPEG_BUILD_LOG="${log_dir}/ffmpeg_build_${timestamp}.log"

    # 导出日志文件路径供其他函数使用
    export FFMPEG_BUILD_LOG
}

# 记录构建日志（同时输出到终端和日志文件）
ffmpeg_build_log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "${FFMPEG_BUILD_LOG}"
}

# 执行命令并记录输出到日志文件
ffmpeg_run_logged() {
    local cmd="$1"
    local desc="$2"

    ffmpeg_build_log "INFO" "Running: $desc"
    ffmpeg_build_log "INFO" "Command: $cmd"

    if eval "$cmd" >> "${FFMPEG_BUILD_LOG}" 2>&1; then
        ffmpeg_build_log "OK" "Success: $desc"
        return 0
    else
        local exit_code=$?
        ffmpeg_build_log "ERROR" "Failed: $desc (exit code: $exit_code)"
        return 1
    fi
}

# FFmpeg builtin 模式：检查是否已安装
ffmpeg_builtin_check() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    # 检查关键库文件（检查avcodec作为代表）
    local found_lib=0
    for lib_dir in \
        "${sysroot}/usr/lib" \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/armhf-linux-gnueabihf" \
        "${sysroot}/usr/lib/armhf-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu"
    do
        if [[ -f "${lib_dir}/libavcodec.so" ]]; then
            found_lib=1
            break
        fi
    done

    if [[ $found_lib -eq 0 ]]; then
        return 1
    fi

    # 检查头文件
    if [[ ! -f "${sysroot}/usr/include/libavcodec/avcodec.h" ]]; then
        return 1
    fi

    return 0
}

# 全局变量：源码目录路径
FFMPEG_SRC_DIR=""

# FFmpeg builtin 模式：下载源码
ffmpeg_builtin_fetch() {
    local version="${FFMPEG_BUILTIN_VERSION}"
    local url="${FFMPEG_BUILTIN_URL}"
    local dl_dir="${THIRD_PARTY_DL_DIR}"
    local src_dir="${THIRD_PARTY_SYSROOT}/src"
    local archive_file="${dl_dir}/ffmpeg-${version}.tar.xz"
    local extract_dir="${src_dir}/ffmpeg-${version}"

    # 检查是否已解压
    if [[ -d "${extract_dir}" && -f "${extract_dir}/configure" ]]; then
        log_info "FFmpeg source already extracted: ${extract_dir}"
        FFMPEG_SRC_DIR="${extract_dir}"
        return 0
    fi

    # 下载源码包
    log_info "Downloading FFmpeg source (${version})..."
    if ! download_file "${url}" "${archive_file}"; then
        log_error "Failed to download FFmpeg source"
        return 1
    fi

    # 创建源码目录
    mkdir -p "${src_dir}"

    # 解压源码
    log_info "Extracting FFmpeg source..."
    if ! extract_archive "${archive_file}" "${src_dir}"; then
        log_error "Failed to extract FFmpeg source"
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

    log_ok "FFmpeg source fetched successfully: ${extract_dir}"
    FFMPEG_SRC_DIR="${extract_dir}"
    return 0
}

# FFmpeg builtin 模式：配置交叉编译
ffmpeg_builtin_configure() {
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

    # 验证工具链存在
    local gcc_cmd="${toolchain_bin}/${TOOLCHAIN_PREFIX}gcc"
    if [[ ! -f "${gcc_cmd}" ]]; then
        log_error "Toolchain gcc not found: ${gcc_cmd}"
        return 1
    fi

    log_info "Using toolchain: ${gcc_cmd}"
    log_info "Build log: ${FFMPEG_BUILD_LOG}"

    # 准备交叉编译前缀
    local cross_prefix="${toolchain_bin}/${TOOLCHAIN_PREFIX}"

    # FFmpeg configure 参数
    # 基础配置
    local configure_opts=(
        --enable-cross-compile
        --cross-prefix="${cross_prefix}"
        --arch=arm
        --target-os=linux
        --prefix=/usr
        --enable-gpl
        --enable-version3
        --enable-shared
        --disable-static
        --disable-doc
        --disable-debug
        --enable-small
    )

    # 标准配置：常用解码器
    configure_opts+=(
        --enable-decoder=h264
        --enable-decoder=hevc
        --enable-decoder=mpeg4
        --enable-decoder=mjpeg
        --enable-decoder=aac
        --enable-decoder=mp3
        --enable-decoder=opus
        --enable-decoder=vorbis
        --enable-decoder=flac
        --enable-decoder=pcm_s16le
        --enable-decoder=pcm_u8le
    )

    # 标准配置：常用编码器
    configure_opts+=(
        --enable-encoder=aac
        --enable-encoder=mp3
        --enable-encoder=mjpeg
        --enable-encoder=png
        --enable-encoder=libopus
    )

    # 标准配置：常用封装格式
    configure_opts+=(
        --enable-muxer=mp4
        --enable-muxer=mov
        --enable-muxer=avi
        --enable-muxer=matroska
        --enable-muxer=ogg
    )

    # 标准配置：常用解封装格式
    configure_opts+=(
        --enable-demuxer=mp4
        --enable-demuxer=mov
        --enable-demuxer=avi
        --enable-demuxer=flv
        --enable-demuxer=matroska
        --enable-demuxer=ogg
        --enable-demuxer=aac
        --enable-demuxer=mp3
        --enable-demuxer=h264
    )

    # 解析器和协议
    configure_opts+=(
        --enable-parser=h264
        --enable-parser=hevc
        --enable-parser=aac
        --enable-parser=mp3
        --enable-network
        --enable-protocol=http
        --enable-protocol=file
        --enable-protocol=rtmp
        --enable-protocol=tcp
        --enable-protocol=udp
    )

    # 滤镜
    configure_opts+=(
        --enable-filter=scale
        --enable-filter=crop
        --enable-filter=overlay
        --enable-filter=resample
        --enable-filter=aresample
        --enable-filter=fps
        --enable-filter=format
    )

    # 组件启用/禁用
    configure_opts+=(
        --disable-programs
        --disable-avdevice
        --enable-swresample
        --enable-swscale
        --enable-postproc
        --enable-avfilter
    )

    # 禁用不需要的组件以减小体积
    configure_opts+=(
        --disable-encoder=vpx        # 不需要VPX编码
        --disable-decoder=vpx        # 不需要VPX解码
        --disable-x86asm
        # ARM优化
        --enable-armv6
        --enable-armv6t2
        --enable-vfp
        --enable-neon
        --enable-fast-unaligned
    )

    log_info "Configuring FFmpeg with cross-compilation..."

    cd "${src_dir}" || return 1

    # 执行 configure
    if ./configure "${configure_opts[@]}" >> "${FFMPEG_BUILD_LOG}" 2>&1; then
        log_ok "FFmpeg configured successfully"
        return 0
    else
        log_error "FFmpeg configure failed - see ${FFMPEG_BUILD_LOG} for details"
        # 显示最后几行日志帮助调试
        tail -30 "${FFMPEG_BUILD_LOG}" >&2
        return 1
    fi
}

# FFmpeg builtin 模式：编译
ffmpeg_builtin_build() {
    local src_dir="$1"
    local jobs="${PARALLEL_JOBS:-$(nproc)}"

    log_info "Building FFmpeg (jobs: ${jobs})..."

    cd "${src_dir}" || return 1

    if make -j"${jobs}" >> "${FFMPEG_BUILD_LOG}" 2>&1; then
        log_ok "FFmpeg built successfully"
        return 0
    else
        log_error "FFmpeg build failed - see ${FFMPEG_BUILD_LOG} for details"
        # 显示最后几行日志帮助调试
        tail -40 "${FFMPEG_BUILD_LOG}" >&2
        return 1
    fi
}

# FFmpeg builtin 模式：安装到 sysroot
ffmpeg_builtin_do_install() {
    local src_dir="$1"
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Installing FFmpeg to sysroot..."

    cd "${src_dir}" || return 1

    # 使用 DESTDIR 安装到 sysroot
    if make install DESTDIR="${sysroot}" >> "${FFMPEG_BUILD_LOG}" 2>&1; then
        log_ok "FFmpeg installed successfully"
        return 0
    else
        log_error "FFmpeg install failed"
        tail -20 "${FFMPEG_BUILD_LOG}" >&2
        return 1
    fi
}

# FFmpeg builtin 模式：生成配置文件
ffmpeg_builtin_config() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Generating FFmpeg configuration..."

    # 查找实际的库文件位置
    local actual_lib_path=""
    local actual_lib_dir=""

    for lib_dir in \
        "${sysroot}/usr/lib/arm-linux-gnueabihf" \
        "${sysroot}/usr/lib/arm-linux-gnu" \
        "${sysroot}/usr/lib/armhf-linux-gnueabihf" \
        "${sysroot}/usr/lib/armhf-linux-gnu" \
        "${sysroot}/usr/lib/aarch64-linux-gnu" \
        "${sysroot}/usr/lib"
    do
        if [[ -f "${lib_dir}/libavcodec.so" ]]; then
            actual_lib_path="${lib_dir}"
            actual_lib_dir="${lib_dir}"
            break
        fi
    done

    if [[ -z "$actual_lib_path" ]]; then
        log_warn "FFmpeg library files not found in sysroot"
        return 1
    fi

    log_info "FFmpeg library found at: ${actual_lib_path}"

    # FFmpeg 的主要库
    local ffmpeg_libs=("avcodec" "avformat" "avutil" "swscale" "swresample")
    local lib_version="${FFMPEG_BUILTIN_VERSION}"

    # 生成 FFmpeg::FFmpeg 统一 CMake 配置
    local cmake_dir="${sysroot}/lib/cmake/FFmpeg"
    mkdir -p "$cmake_dir"

    cat > "${cmake_dir}/FFmpegConfig.cmake" <<EOF
# FFmpeg CMake configuration
# Auto-generated by third_party/ffmpeg/builtin.sh

if(NOT TARGET FFmpeg::avcodec)
    # 创建导入的库目标
    foreach(lib avcodec avformat avutil swscale swresample)
        add_library(FFmpeg::\${lib} SHARED IMPORTED)
        set_target_properties(FFmpeg::\${lib} PROPERTIES
            IMPORTED_LOCATION "${actual_lib_dir}/lib\${lib}.so"
            INTERFACE_INCLUDE_DIRECTORIES "${sysroot}/usr/include"
        )
    endforeach()

    # 创建别名目标
    add_library(FFmpeg::FFmpeg ALIAS FFmpeg::avcodec)
endif()
EOF

    cat > "${cmake_dir}/FFmpegConfigVersion.cmake" <<EOF
# FFmpeg CMake Version Configuration
# Auto-generated by third_party/ffmpeg/builtin.sh

set(PACKAGE_VERSION "${lib_version}")

if(PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
endif()
EOF

    # 生成每个库的 pkg-config 文件
    local pkgconfig_dir="${sysroot}/lib/pkgconfig"
    mkdir -p "$pkgconfig_dir"

    # libavcodec.pc
    cat > "${pkgconfig_dir}/libavcodec.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libavcodec
Description: FFmpeg codec library (builtin)
Version: ${lib_version}
Requires: libavutil = ${lib_version}
Libs: -L\${libdir} -lavcodec
Libs.private: -lm -lz -lpthread
Cflags: -I\${includedir}
EOF

    # libavformat.pc
    cat > "${pkgconfig_dir}/libavformat.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libavformat
Description: FFmpeg format library (builtin)
Version: ${lib_version}
Requires: libavcodec = ${lib_version}, libavutil = ${lib_version}
Libs: -L\${libdir} -lavformat
Libs.private: -lm -lz
Cflags: -I\${includedir}
EOF

    # libavutil.pc
    cat > "${pkgconfig_dir}/libavutil.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libavutil
Description: FFmpeg utility library (builtin)
Version: ${lib_version}
Libs: -L\${libdir} -lavutil
Libs.private: -lm -lpthread
Cflags: -I\${includedir}
EOF

    # libswscale.pc
    cat > "${pkgconfig_dir}/libswscale.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libswscale
Description: FFmpeg image scaling library (builtin)
Version: ${lib_version}
Requires: libavutil = ${lib_version}
Libs: -L\${libdir} -lswscale
Libs.private: -lm
Cflags: -I\${includedir}
EOF

    # libswresample.pc
    cat > "${pkgconfig_dir}/libswresample.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${actual_lib_path#$sysroot}
includedir=\${prefix}/include

Name: libswresample
Description: FFmpeg audio resampling library (builtin)
Version: ${lib_version}
Requires: libavutil = ${lib_version}
Libs: -L\${libdir} -lswresample
Libs.private: -lm
Cflags: -I\${includedir}
EOF

    log_ok "FFmpeg configuration generated"
    return 0
}

# FFmpeg builtin 模式：安装（主流程）
ffmpeg_builtin_install() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    # 初始化日志
    ffmpeg_builtin_init_log
    log_info "FFmpeg build log: ${FFMPEG_BUILD_LOG}"

    # 检查是否已安装
    if ffmpeg_builtin_check; then
        log_info "FFmpeg already installed (builtin mode), skipping..."
        return 0
    fi

    log_info "Installing FFmpeg (builtin mode)..."

    # 1. 下载源码（使用全局变量 FFMPEG_SRC_DIR）
    if ! ffmpeg_builtin_fetch; then
        log_error "Failed to fetch FFmpeg source"
        return 1
    fi

    # 2. 配置交叉编译
    if ! ffmpeg_builtin_configure "$FFMPEG_SRC_DIR"; then
        log_error "Failed to configure FFmpeg"
        return 1
    fi

    # 3. 编译
    if ! ffmpeg_builtin_build "$FFMPEG_SRC_DIR"; then
        log_error "Failed to build FFmpeg"
        return 1
    fi

    # 4. 安装到 sysroot
    if ! ffmpeg_builtin_do_install "$FFMPEG_SRC_DIR"; then
        log_error "Failed to install FFmpeg"
        return 1
    fi

    # 5. 生成配置文件
    if ! ffmpeg_builtin_config; then
        log_warn "Failed to generate FFmpeg configuration (non-critical)"
    fi

    log_ok "FFmpeg (builtin mode) installation completed"
    log_info "Full build log: ${FFMPEG_BUILD_LOG}"
    return 0
}

# FFmpeg builtin 模式：清理
ffmpeg_builtin_clean() {
    local sysroot="${THIRD_PARTY_SYSROOT}"

    log_info "Cleaning FFmpeg (builtin mode)..."

    # 删除安装的文件
    rm -rf "${sysroot}/usr/include/libavcodec"
    rm -rf "${sysroot}/usr/include/libavformat"
    rm -rf "${sysroot}/usr/include/libavutil"
    rm -rf "${sysroot}/usr/include/libswscale"
    rm -rf "${sysroot}/usr/include/libswresample"
    rm -rf "${sysroot}/usr/include/libpostproc"
    rm -rf "${sysroot}/usr/include/libavfilter"

    # 删除库文件
    rm -f "${sysroot}/usr/lib/"libav*.so*
    rm -f "${sysroot}/usr/lib/"libsw*.so*
    rm -f "${sysroot}/usr/lib/"libpostproc*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libav*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libsw*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnueabihf/"libpostproc*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libav*.so*
    rm -f "${sysroot}/usr/lib/arm-linux-gnu/"libsw*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnueabihf/"libav*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnueabihf/"libsw*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnu/"libav*.so*
    rm -f "${sysroot}/usr/lib/armhf-linux-gnu/"libsw*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libav*.so*
    rm -f "${sysroot}/usr/lib/aarch64-linux-gnu/"libsw*.so*

    # 删除配置文件
    rm -rf "${sysroot}/lib/cmake/FFmpeg"
    rm -f "${sysroot}/lib/pkgconfig/libav*.pc"
    rm -f "${sysroot}/lib/pkgconfig/libsw*.pc"
    rm -f "${sysroot}/lib/pkgconfig/libpostproc*.pc"
    rm -f "${sysroot}/.ffmpeg-installed"

    # 删除源码目录
    rm -rf "${sysroot}/src/ffmpeg-"*

    log_ok "FFmpeg cleaned"
}

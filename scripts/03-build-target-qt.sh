#!/usr/bin/env bash
# 03-build-target-qt.sh - Target Qt 交叉编译脚本
# 阶段 4：交叉编译并安装 Target Qt
# 使用 Qt 官方推荐的 ./configure 方式进行编译

set -euo pipefail

# ================================================================
# 加载公共库和配置
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/../config/qt.conf"
source "${SCRIPT_DIR}/../config/host.conf"
source "${SCRIPT_DIR}/../config/target.conf"
source "${SCRIPT_DIR}/../config/toolchain.conf"

# ================================================================
# 前置检查
# ================================================================
# 如果不编译 Target Qt，直接跳过
if [[ "${BUILD_TARGET_QT}" != "true" ]]; then
    log_info "BUILD_TARGET_QT is false, skipping Target Qt build"
    exit 0
fi

# 检查必需命令
require_cmd cmake ninja perl

# 检查源码目录是否存在
SRC_DIR="${WORK_DIR}/src/${QT_SRC_DIR}"
if [[ ! -d "$SRC_DIR" ]]; then
    die "Qt source not found: ${SRC_DIR}"$'\n'\
         "Please run: bash scripts/00-fetch-qt-src.sh"
fi

# 检查 Host Qt 是否已安装（交叉编译必须依赖）
HOST_QT_DIR="${HOST_INSTALL_PREFIX}"
if [[ ! -d "${HOST_QT_DIR}" ]]; then
    die "Host Qt not found: ${HOST_QT_DIR}"$'\n'\
         "Target Qt requires Host Qt to be built first."$'\n'\
         "Please run: bash scripts/02-build-host-qt.sh"
fi

# ================================================================
# 解析工具链 bin 目录
# ================================================================
if [[ -z "${TOOLCHAIN_BIN_DIR:-}" ]]; then
    TOOLCHAIN_BIN_DIR="$(auto_detect_toolchain_bin "${TOOLCHAIN_ROOT}" "${TOOLCHAIN_PREFIX}")"
    log_info "Auto-detected TOOLCHAIN_BIN_DIR: ${TOOLCHAIN_BIN_DIR}"
fi

# 验证工具链可执行文件
GCC_PATH="${TOOLCHAIN_BIN_DIR}/${TOOLCHAIN_PREFIX}gcc"
if [[ ! -x "$GCC_PATH" ]]; then
    die "Toolchain gcc not found or not executable: ${GCC_PATH}"
fi

log_info "Toolchain gcc verified: ${GCC_PATH}"
log_info "Toolchain version:"
"$GCC_PATH" --version | head -n 1

# ================================================================
# 路径定义
# ================================================================
BUILD_DIR="${WORK_DIR}/build-target"
INSTALL_PREFIX="${TARGET_INSTALL_PREFIX}"
TOOLCHAIN_FILE="${WORK_DIR}/cross-toolchain.cmake"
CONFIGURE_SCRIPT="${SRC_DIR}/configure"

# 设备上的安装路径（通常固定）
# 这将在目标设备上作为 Qt 的实际路径
DEVICE_PREFIX="${TARGET_DEVICE_PREFIX:-/usr/local/qt6}"

# ================================================================
# 生成 CMake 工具链文件
# ================================================================
stage "Stage 4: Build Target Qt (Cross-Compilation with ./configure)"

log_info "Configuration:"
log_info "  Qt Version: ${QT_VERSION}"
log_info "  Source: ${SRC_DIR}"
log_info "  Build: ${BUILD_DIR}"
log_info "  Install (staging): ${INSTALL_PREFIX}"
log_info "  Install (on device): ${DEVICE_PREFIX}"
log_info "  Modules: ${QT_MODULES}"
log_info "  Platform: ${QT_TARGET_PLATFORM}"
log_info "  Host Qt: ${HOST_QT_DIR}"

# ---------------------------------------------------------------
# 检查是否已经编译过
# ---------------------------------------------------------------
if [[ -f "${INSTALL_PREFIX}/bin/qmake" ]]; then
    log_ok "Target Qt already installed: ${INSTALL_PREFIX}"
    log_info "Skipping build"
    exit 0
fi

# ---------------------------------------------------------------
# 检查 configure 脚本是否存在
# ---------------------------------------------------------------
if [[ ! -x "$CONFIGURE_SCRIPT" ]]; then
    # 如果不可执行，尝试添加执行权限
    if [[ -f "$CONFIGURE_SCRIPT" ]]; then
        log_info "Making configure script executable..."
        chmod +x "$CONFIGURE_SCRIPT"
    else
        die "Configure script not found: ${CONFIGURE_SCRIPT}"
    fi
fi

# ---------------------------------------------------------------
# 生成 CMake 工具链文件
# ---------------------------------------------------------------
log_info "Generating CMake toolchain file: ${TOOLCHAIN_FILE}"

# 使用 sed 替换模板中的占位符
# 注意：@SET_SYSROOT@ 占位符会在后续根据 TOOLCHAIN_SYSROOT 状态处理
sed -e "s|@TARGET_OS@|${TARGET_OS}|g" \
    -e "s|@TARGET_ARCH@|${TARGET_ARCH}|g" \
    -e "s|@TOOLCHAIN_BIN_DIR@|${TOOLCHAIN_BIN_DIR}|g" \
    -e "s|@TOOLCHAIN_PREFIX@|${TOOLCHAIN_PREFIX}|g" \
    "${SCRIPT_DIR}/../cmake/cross-toolchain.cmake.in" > "${TOOLCHAIN_FILE}"

# 处理 sysroot 设置
THIRD_PARTY_SYSROOT="${WORK_DIR}/third-party-sysroot"
if [[ -n "${TOOLCHAIN_SYSROOT:-}" ]]; then
    # 有 sysroot，设置 CMAKE_SYSROOT 和 CMAKE_FIND_ROOT_PATH
    sed -i "s|@SET_SYSROOT@|set(CMAKE_SYSROOT ${TOOLCHAIN_SYSROOT})|g" "${TOOLCHAIN_FILE}"
    # 同时包含工具链 sysroot 和第三方库 sysroot
    sed -i "s|@SET_FIND_ROOT_PATH@|set(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN_SYSROOT} ${THIRD_PARTY_SYSROOT})|g" "${TOOLCHAIN_FILE}"
elif [[ -d "${THIRD_PARTY_SYSROOT}" ]]; then
    # 无工具链 sysroot 但有第三方 sysroot，至少设置第三方库路径
    sed -i 's|@SET_SYSROOT@|# CMAKE_SYSROOT not set|g' "${TOOLCHAIN_FILE}"
    sed -i "s|@SET_FIND_ROOT_PATH@|set(CMAKE_FIND_ROOT_PATH ${THIRD_PARTY_SYSROOT})|g" "${TOOLCHAIN_FILE}"
else
    # 无 sysroot，注释掉
    sed -i 's|@SET_SYSROOT@|# CMAKE_SYSROOT not set|g' "${TOOLCHAIN_FILE}"
    sed -i 's|@SET_FIND_ROOT_PATH@|# CMAKE_FIND_ROOT_PATH not set|g' "${TOOLCHAIN_FILE}"
fi

# 添加优先使用 Config 文件的设置
echo "" >> "${TOOLCHAIN_FILE}"
echo "# 优先使用 Config 文件而不是 Find 模块" >> "${TOOLCHAIN_FILE}"
echo "set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)" >> "${TOOLCHAIN_FILE}"

# ---------------------------------------------------------------
# 添加第三方库配置（使用 third_party 模块）
# ---------------------------------------------------------------
# 加载 third_party 配置
if [[ -f "${SCRIPT_DIR}/../config/third_party.conf" ]]; then
    source "${SCRIPT_DIR}/../config/third_party.conf"
fi

# 使用 manager.sh 获取 CMake 配置片段
cmake_fragment=$("${SCRIPT_DIR}/third_party/manager.sh" generate-cmake 2>/dev/null) || true

if [[ -n "$cmake_fragment" ]]; then
    log_info "Adding third-party CMake configuration..."
    echo "" >> "${TOOLCHAIN_FILE}"
    echo "$cmake_fragment" >> "${TOOLCHAIN_FILE}"
    log_ok "Third-party configuration added to toolchain file"
fi

# 获取 PulseAudio 库路径（用于后续检查）
PULSEAUDIO_LIB_PATH=$("${SCRIPT_DIR}/third_party/manager.sh" get-lib-path pulseaudio 2>/dev/null) || true
if [[ -n "$PULSEAUDIO_LIB_PATH" && -f "${PULSEAUDIO_LIB_PATH}/libpulse.so" ]]; then
    log_info "PulseAudio library path: ${PULSEAUDIO_LIB_PATH}"
fi

# 获取 FFmpeg 库路径（用于后续检查）
FFMPEG_LIB_PATH=$("${SCRIPT_DIR}/third_party/manager.sh" get-lib-path ffmpeg 2>/dev/null) || true
if [[ -n "$FFMPEG_LIB_PATH" && -f "${FFMPEG_LIB_PATH}/libavcodec.so" ]]; then
    log_info "FFmpeg library path: ${FFMPEG_LIB_PATH}"
fi

log_ok "Toolchain file generated"

# ---------------------------------------------------------------
# 准备构建目录
# ---------------------------------------------------------------
log_info "Preparing build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ---------------------------------------------------------------
# 配置 Qt 使用 ./configure（交叉编译模式）
# ---------------------------------------------------------------
log_info "Configuring Qt with ./configure (cross-compilation)..."

# 构建 configure 命令数组
# Qt 6 交叉编译 configure 推荐参数格式
CONFIGURE_ARGS=(
    "-release"                          # Release 构建
    "-qt-host-path" "${HOST_QT_DIR}"    # Host Qt 路径（必需）
    "-extprefix" "${INSTALL_PREFIX}"    # 本地 staging 安装路径
    "-prefix" "${DEVICE_PREFIX}"        # 目标设备上的安装路径
    "-nomake" "examples"                # 不编译示例
    "-nomake" "tests"                   # 不编译测试
)

# 添加模块列表（如果指定了）
if [[ -n "${QT_MODULES:-}" ]]; then
    # configure 使用逗号分隔模块
    MODULES_LIST="${QT_MODULES// /,}"
    CONFIGURE_ARGS+=("-submodules" "${MODULES_LIST}")
    log_info "Submodules: ${MODULES_LIST}"
fi

# 添加平台配置（可选）
# 注意：configure 会自动检测平台，这里可以不显式指定
# 如果需要指定，可以使用 -device 参数（需要对应的 mkspec）

# OpenGL 配置（根据目标平台）
if [[ "${TARGET_USE_OPENGL:-false}" == "true" ]]; then
    if [[ "${TARGET_OPENGL_TYPE:-desktop}" == "es2" ]]; then
        CONFIGURE_ARGS+=("-opengl" "es2")
    else
        CONFIGURE_ARGS+=("-opengl" "desktop")
    fi
fi

# 添加用户自定义参数（configure 风格）
eval "set -- ${TARGET_CONFIGURE_EXTRA:-}"
CONFIGURE_ARGS+=("$@")

# 准备 CMake 透传参数（在 -- 之后）
CMAKE_PASS_ARGS=(
    "-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}"
)

# 添加渲染后端配置（CMake 参数）
eval "set -- ${TARGET_RENDER_BACKENDS:-}"
CMAKE_PASS_ARGS+=("$@")

# 添加额外的 CMake 参数（如编译器标志等）
eval "set -- ${TARGET_CMAKE_EXTRA:-}"
CMAKE_PASS_ARGS+=("$@")

# PulseAudio 特殊处理：如果 sysroot 存在，显式启用
# (PulseAudioConfig.cmake 已在 sysroot 中，CMAKE_FIND_ROOT_PATH 让 CMake 能找到它)
if [[ -n "$PULSEAUDIO_LIB_PATH" ]]; then
    CMAKE_PASS_ARGS+=("-DFEATURE_pulseaudio=ON")
    log_info "PulseAudio enabled (FEATURE_pulseaudio=ON)"
fi

# FFmpeg 特殊处理：如果 sysroot 存在 且 PulseAudio 也存在，显式启用 FFmpeg
# Qt 6 qtmultimedia在Linux上要求PulseAudio才能使用FFmpeg backend
if [[ -n "$FFMPEG_LIB_PATH" && -n "$PULSEAUDIO_LIB_PATH" ]]; then
    CMAKE_PASS_ARGS+=("-DFEATURE_ffmpeg=ON")  # PulseAudio存在时才启用FFmpeg
    log_info "FFmpeg enabled (FEATURE_ffmpeg=ON) with PulseAudio support"
elif [[ -n "$FFMPEG_LIB_PATH" ]]; then
    log_info "FFmpeg found but NOT enabled on Linux (requires PulseAudio)"
fi

# OpenSSL 特殊处理：如果 sysroot 存在，获取库路径
OPENSSL_LIB_PATH=$("${SCRIPT_DIR}/third_party/manager.sh" get-lib-path openssl 2>/dev/null) || true
if [[ -n "$OPENSSL_LIB_PATH" ]]; then
    if [[ -f "${OPENSSL_LIB_PATH}/libssl.so" ]] || [[ -f "${OPENSSL_LIB_PATH}/libssl.so.3" ]]; then
        log_info "OpenSSL library path: ${OPENSSL_LIB_PATH}"
        # OpenSSL 配置已在 TARGET_CONFIGURE_EXTRA 中通过 FEATURE_openssl=ON 启用
        # 这里只需确认库路径
    fi
fi

# 打印完整 configure 命令（便于调试）
log_info "Full configure command (run from build directory):"
echo "${CONFIGURE_SCRIPT} \\"
for arg in "${CONFIGURE_ARGS[@]}"; do
    echo "  ${arg}"
done
echo "  -- \\"
for arg in "${CMAKE_PASS_ARGS[@]}"; do
    echo "  ${arg}"
done
echo ""

# 切换到构建目录并运行 configure
cd "${BUILD_DIR}" || die "Failed to enter build directory: ${BUILD_DIR}"

# 设置环境变量，防止 pkg-config 查找主机系统库
# PKG_CONFIG_LIBDIR: 覆盖默认的 pkg-config 搜索路径，指向 sysroot
export PKG_CONFIG_LIBDIR="${THIRD_PARTY_SYSROOT}/usr/lib/pkgconfig"
# PKG_CONFIG_SYSROOT_DIR: 设置 pkg-config 的 sysroot
export PKG_CONFIG_SYSROOT_DIR="${THIRD_PARTY_SYSROOT}"
# ACLOCAL_PATH: 防止 aclocal 查找主机宏
unset ACLOCAL_PATH

# 执行 configure 脚本
# 使用 -- 分隔 configure 参数和 CMake 参数
"${CONFIGURE_SCRIPT}" "${CONFIGURE_ARGS[@]}" -- "${CMAKE_PASS_ARGS[@]}" \
    || die "Configure failed"

# ---------------------------------------------------------------
# 编译
# ---------------------------------------------------------------
log_info "Building Qt..."
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"
log_info "Parallel jobs: ${PARALLEL_JOBS}"

# Qt 官方推荐使用 cmake --build
cmake --build . --parallel "${PARALLEL_JOBS}" \
    || die "Build failed"

# ---------------------------------------------------------------
# 安装
# ---------------------------------------------------------------
log_info "Installing Qt to: ${INSTALL_PREFIX}"
cmake --install . \
    || die "Install failed"

# ---------------------------------------------------------------
# 验证安装
# ---------------------------------------------------------------
log_info "Verifying installation..."
if [[ ! -f "${INSTALL_PREFIX}/bin/qmake" ]]; then
    die "qmake not found after installation"
fi

log_ok "Target Qt installed successfully"
log_info "Installation summary:"
log_info "  Staging Prefix: ${INSTALL_PREFIX}"
log_info "  Device Prefix: ${DEVICE_PREFIX}"
log_info "  Bin: ${INSTALL_PREFIX}/bin"
log_info "  Lib: ${INSTALL_PREFIX}/lib"
log_info "  Plugins: ${INSTALL_PREFIX}/plugins"

log_info ""
log_info "To deploy to target device, copy contents of ${INSTALL_PREFIX} to ${DEVICE_PREFIX}"
log_info "Or use the qt-cmake script in ${INSTALL_PREFIX}/bin to build applications"

#!/usr/bin/env bash
# install-host-deps.sh - Install host system dependencies for Qt 6 build
# Usage: sudo bash scripts/install-host-deps.sh

set -euo pipefail

echo "=============================================================================="
echo "  Installing Qt 6 Host Build Dependencies"
echo "=============================================================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

apt update

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
    ccache

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

echo ""
echo "Installing X11, XCB and Wayland dependencies..."
apt install -y \
    libx11-dev \
    libxext-dev \
    libxfixes-dev \
    libxrender-dev \
    libxi-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxcb1-dev \
    libxcb-util-dev \
    libxcb-glx0-dev \
    libxcb-keysyms1-dev \
    libxcb-image0-dev \
    libxcb-shm0-dev \
    libxcb-icccm4-dev \
    libxcb-sync-dev \
    libxcb-xfixes0-dev \
    libxcb-shape0-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-xinerama0-dev \
    libxcb-xkb-dev \
    libxcb-xinput-dev \
    libxcb-cursor0

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

echo ""
echo "Installing input, ICU and text rendering dependencies..."
apt install -y \
    libinput-dev \
    libts-dev \
    libicu-dev \
    libpcre2-dev \
    libsqlite3-dev

echo ""
echo "Installing network and security dependencies..."
apt install -y \
    libssl-dev \
    libglib2.0-dev \
    libdbus-1-dev

echo ""
echo "Installing additional dependencies for Qt modules..."
apt install -y \
    libsm-dev \
    libice-dev \
    libxcomposite-dev \
    libxcursor-dev \
    libxdamage-dev \
    libxft-dev \
    libxinerama-dev \
    libxv-dev \
    libxi-dev

echo ""
echo "=============================================================================="
echo "  Dependencies installed successfully!"
echo "=============================================================================="
#!/bin/bash

# This script builds mpv with inputstream.adaptive support on Windows using MSYS2.

set -e

# --- Dependencies ---

# Update package database
pacman -Syu --noconfirm

# Install mpv dependencies
pacman -S --noconfirm --needed     git     python     pkg-config     meson     ninja     mingw-w64-x86_64-toolchain     mingw-w64-x86_64-ffmpeg     mingw-w64-x86_64-libjpeg-turbo     mingw-w64-x86_64-libplacebo     mingw-w64-x86_64-luajit     mingw-w64-x86_64-vulkan-headers

# Install inputstream.adaptive dependencies
pacman -S --noconfirm --needed     mingw-w64-x86_64-cmake     mingw-w64-x86_64-pugixml     mingw-w64-x86_64-nlohmann-json mingw-w64-x86_64-dlfcn

# --- Build Bento4 from source ---
echo "Cloning Bento4..."
rm -rf Bento4
git clone https://github.com/axiomatic-systems/Bento4.git
cd Bento4
echo "Current directory: $(pwd)"
echo "Building Bento4..."
mkdir -p cmakebuild
cd cmakebuild
echo "Current directory: $(pwd)"
echo "Running cmake..."
cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PWD}/../../bento4_install
echo "Running make..."
mingw32-make > make.log 2>&1
echo "make finished. See make.log for details."
echo "Running make install..."
mingw32-make install > make_install.log 2>&1
echo "make install finished. See make_install.log for details."
cd ../..
echo "Current directory: $(pwd)"

# --- Create Kodi headers ---
mkdir -p kodi_headers/kodi/c-api/addon-instance/inputstream

cat <<'EOF' > kodi_headers/kodi/AddonBase.h
/*
 *  Copyright (C) 2005-2020 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#pragma once

#include "c-api/addon_base.h"
#include "versions.h"

#include <assert.h> /* assert */
#include <stdarg.h> /* va_list, va_start, va_arg, va_end */
EOF

cat <<'EOF' > kodi_headers/kodi/c-api/addon_base.h
/*
 *  Copyright (C) 2005-2019 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#ifndef C_API_ADDON_BASE_H
#define C_API_ADDON_BASE_H

#if !defined(NOMINMAX)
#define NOMINMAX
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#endif
EOF

# --- Build inputstream.adaptive ---

echo "Cloning inputstream.adaptive..."
rm -rf inputstream.adaptive
git clone https://github.com/purplescorpion1/inputstream.adaptive.git
cd inputstream.adaptive

# ... (patching and mock cmake files)

echo "Building inputstream.adaptive..."
mkdir -p build
cd build
cmake .. -G "MinGW Makefiles" \
    -DCMAKE_PREFIX_PATH=${PWD}/.. \
    -DADDONS_TO_BUILD=inputstream.adaptive \
    -DCMAKE_INSTALL_PREFIX=/mingw64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBENTO4_INCLUDE_DIR=${PWD}/../../bento4_install/include \
    -DBENTO4_LIBRARY=${PWD}/../../bento4_install/lib/libap4.a \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_FLAGS="-I${PWD}/../../kodi_headers"
make
make install

cd ../..

# --- Build mpv ---

echo "Building mpv..."
meson setup build
meson compile -C build

# --- Get Widevine CDM ---

mkdir -p cdm
echo "Please download the Widevine CDM from a Chrome or ChromeOS recovery image and place it in the 'cdm' directory."
echo "The file should be named 'widevinecdm.dll'."
echo "Press enter to continue..."
read

# --- Create distribution package ---

echo "Creating distribution package..."
mkdir -p dist
cp build/mpv.exe dist/
cp /mingw64/bin/inputstream.adaptive.dll dist/

if [ -f "cdm/widevinecdm.dll" ]; then
    cp cdm/widevinecdm.dll dist/
else
    echo "WARNING: widevinecdm.dll not found. Widevine protected streams will not work."
fi

# TODO: Copy other necessary DLLs to dist/
# This includes:
# - MinGW runtime DLLs (libgcc_s_seh-1.dll, libstdc++-6.dll, libwinpthread-1.dll)
# - Dependencies of inputstream.adaptive (pugixml, nlohmann-json)
# - Dependencies of mpv (ffmpeg, libplacebo, etc.)

echo "Build finished. The 'dist' directory contains the binaries."

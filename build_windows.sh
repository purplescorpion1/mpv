#!/bin/bash

# This script builds mpv with inputstream.adaptive support on Windows using MSYS2.

set -e

# --- Dependencies ---

# Update package database
pacman -Syu --noconfirm

# Install mpv dependencies
pacman -S --noconfirm --needed \
    git \
    python \
    pkg-config \
    meson \
    ninja \
    mingw-w64-x86_64-toolchain \
    mingw-w64-x86_64-ffmpeg \
    mingw-w64-x86_64-libjpeg-turbo \
    mingw-w64-x86_64-libplacebo \
    mingw-w64-x86_64-luajit \
    mingw-w64-x86_64-vulkan-headers

# Install inputstream.adaptive dependencies
pacman -S --noconfirm --needed \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-pugixml \
    mingw-w64-x86_64-nlohmann-json \
    mingw-w64-x86_64-dlfcn

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
mkdir -p kodi_headers/kodi/c-api

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

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

  typedef void* KODI_ADDON_HDL;
  typedef void* KODI_ADDON_BACKEND_HDL;
  typedef void* KODI_ADDON_INSTANCE_HDL;
  typedef void* KODI_ADDON_INSTANCE_BACKEND_HDL;

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* !C_API_ADDON_BASE_H */
EOF

# --- Build inputstream.adaptive ---

echo "Cloning inputstream.adaptive..."
rm -rf inputstream.adaptive
git clone https://github.com/xbmc/inputstream.adaptive.git
cd inputstream.adaptive

# Create a patch to fix compilation errors
cat <<'EOF' > inputstream_adaptive_win.patch
--- a/lib/cdm/cdm/base/native_library_win.cc
+++ b/lib/cdm/cdm/base/native_library_win.cc
@@ -53,7 +53,7 @@
	if (res)
	{
	  plugin_path.assign(lp.c_str(),res);
-	  plugin_value.assign(++res, wcsrchr(res,0));
+	  plugin_value.assign(res + 1);
	}
	else
	  plugin_value = lp;
@@ -121,7 +121,7 @@
 // static
 void* GetFunctionPointerFromNativeLibrary(NativeLibrary library,
                                           const char* name) {
-  return GetProcAddress(library, name);
+  return (void*)GetProcAddress(library, name);
 }

 // static
EOF

# Create a patch to add Bento4 and Kodi include directories
cat <<'EOF' > inputstream_adaptive_cmake.patch
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -62,8 +62,9 @@

 include_directories(${INCLUDES}
                     ${KODI_INCLUDE_DIR}/.. # Hack way with "/..", need bigger Kodi cmake rework to match right include ways (becomes done in future)
-                    ${NLOHMANNJSON_INCLUDE_DIRS}
-                    src/
+                    ${BENTO4_INCLUDE_DIRS}
+                    ${KODI_INCLUDE_DIR}
+                    ${NLOHMANNJSON_INCLUDE_DIRS} src/
 )

 if(WIN32)
EOF

echo "Patching inputstream.adaptive..."
patch -p1 < inputstream_adaptive_win.patch
patch -p1 < inputstream_adaptive_cmake.patch

# Create a mock KodiConfig.cmake file
mkdir -p cmake
cat <<'EOF' > cmake/KodiConfig.cmake
set(APP_NAME "Kodi")
set(APP_NAME_LC "kodi")
set(APP_NAME_UC "KODI")
set(APP_PACKAGE "kodi")
set(APP_VERSION_MAJOR "21")
set(APP_VERSION_MINOR "0")
set(APP_VERSION_CODE "2100")
set(KODI_PREFIX "/mingw64")
set(KODI_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../../kodi_headers")
set(KODI_LIB_DIR "/mingw64/lib")
set(KODI_DATA_DIR "/mingw64/share/kodi")
set(APP_RENDER_SYSTEM "gl")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}" "/mingw64/lib" "/mingw64/share/kodi/cmake")
add_definitions(-DBUILD_KODI_ADDON)
set(CORE_SYSTEM_NAME "windows")
set(PLATFORM "windows")
set(PLATFORM_TAG "windows")
set(CMAKE_CXX_STANDARD "17")
set(CMAKE_CXX_STANDARD_REQUIRED "ON")
set(CMAKE_CXX_EXTENSIONS "OFF")
include(AddonHelpers)
EOF

# Create AddonHelpers.cmake with the corrected regex
cat <<'EOF' > cmake/AddonHelpers.cmake
macro (addon_version dir prefix)
  if(EXISTS ${PROJECT_SOURCE_DIR}/${dir}/addon.xml.in)
    file(READ ${PROJECT_SOURCE_DIR}/${dir}/addon.xml.in ADDONXML)
  else()
    file(READ ${dir}/addon.xml ADDONXML)
  endif()

  string(REGEX MATCH "<addon[^>]*version.?=.?[\"']([0-9\\.]+)" VERSION_STRING ${ADDONXML})
  string(REGEX REPLACE ".*version=.[\"']([0-9\\.]+).*" "\\1" ${prefix}_VERSION ${VERSION_STRING})
  message(STATUS ${prefix}_VERSION=${${prefix}_VERSION})
endmacro()

function(source_group_by_folder target)
  if(NOT TARGET ${target})
    message(FATAL_ERROR "There is no target named '${target}'")
  endif()

  set(SOURCE_GROUP_DELIMITER "/")

  cmake_parse_arguments(arg "" "RELATIVE" "" ${ARGN})
  if(arg_RELATIVE)
    set(relative_dir ${arg_RELATIVE})
  else()
    set(relative_dir ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  get_property(files TARGET ${target} PROPERTY SOURCES)
  if(files)
    list(SORT files)

    if(CMAKE_GENERATOR STREQUAL Xcode)
      set_target_properties(${target} PROPERTIES SOURCES "${files}")
    endif()
  endif()
  foreach(file ${files})
    if(NOT IS_ABSOLUTE ${file})
      set(file ${CMAKE_CURRENT_SOURCE_DIR}/${file})
    endif()
    file(RELATIVE_PATH relative_file ${relative_dir} ${file})
    get_filename_component(dir "${relative_file}" DIRECTORY)
    if(NOT dir STREQUAL "${last_dir}")
      if(files)
        source_group("${last_dir}" FILES ${files})
      endif()
      set(files "")
    endif()
    set(files ${files} ${file})
    set(last_dir "${dir}")
  endforeach(file)
  if(files)
    source_group("${last_dir}" FILES ${files})
  endif()
endfunction()

macro (build_addon target prefix libs)
  addon_version(${target} ${prefix})

  if(${prefix}_SOURCES)
    add_library(${target} SHARED ${${prefix}_SOURCES} ${${prefix}_HEADERS})
    source_group_by_folder(${target})
    target_link_libraries(${target} ${${libs}})
    set_target_properties(${target} PROPERTIES VERSION ${${prefix}_VERSION}
                                               SOVERSION ${APP_VERSION_MAJOR}.${APP_VERSION_MINOR}
                                               PREFIX ""
                                               POSITION_INDEPENDENT_CODE 1)
    if(OS STREQUAL "android")
      set_target_properties(${target} PROPERTIES PREFIX "lib")
    endif()
  elseif(${prefix}_CUSTOM_BINARY)
    add_custom_target(${target} ALL)
  endif()
endmacro()
EOF

echo "Building inputstream.adaptive..."
mkdir -p build
cd build
cmake .. -G "MinGW Makefiles" \
    -DCMAKE_MODULE_PATH=${PWD}/../cmake \
    -DADDONS_TO_BUILD=inputstream.adaptive \
    -DCMAKE_INSTALL_PREFIX=/mingw64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBENTO4_INCLUDE_DIR=${PWD}/../../bento4_install/include \
    -DBENTO4_LIBRARY=${PWD}/../../bento4_install/lib/libap4.a \
    -DBUILD_TESTING=OFF
echo "Running make..."
mingw32-make > make.log 2>&1
echo "make finished. See make.log for details."
echo "Running make install..."
mingw32-make install > make_install.log 2>&1
echo "make install finished. See make_install.log for details."
cd ../..

# --- Build mpv ---
echo "Configuring mpv..."
meson setup build --default-library=static --prefer-static -Dlibmpv=true -Dgl=enabled
echo "Compiling mpv..."
meson compile -C build

# --- Create distribution package ---
echo "Creating distribution package..."
mkdir -p dist
cp build/mpv.exe dist/
cp /mingw64/bin/inputstream.adaptive.dll dist/

echo "Please provide the Widevine CDM library."
echo "The file should be named 'widevinecdm.dll' on Windows."
echo "Place it in the 'dist' directory."
echo "You can often find this file in your Google Chrome installation directory."

echo "Build finished. The 'dist' directory contains the binaries."
echo "Remember to copy all necessary DLLs to the 'dist' directory for a portable build."

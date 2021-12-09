#!/bin/bash
set -e
set +h

# Export
export MAKEFLAGS="-j8"
export CFLAGS="-march=native -O3 -pipe"
export CXXFLAGS=${CFLAGS}

# firefox-9
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/firefox-9*/)
cat > /blfs/${LFS_PKG_DIR}/mozconfig << "EOF"
ac_add_options --disable-necko-wifi
ac_add_options --with-system-libevent
ac_add_options --with-system-webp
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
ac_add_options --with-system-icu
ac_add_options --disable-debug-symbols
ac_add_options --disable-elf-hack
ac_add_options --prefix=/usr
ac_add_options --enable-application=browser
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-tests
ac_add_options --enable-system-ffi
ac_add_options --enable-system-pixman
ac_add_options --with-system-jpeg
ac_add_options --with-system-png
ac_add_options --with-system-zlib
ac_add_options --enable-default-toolkit=cairo-gtk3-wayland
ac_add_options --enable-optimize=-O4
unset MOZ_TELEMETRY_REPORTING
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/firefox-build-dir
EOF
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}esr-glibc234-1.patch
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}esr-disable_rust_test-1.patch
mountpoint -q /dev/shm || mount -t tmpfs devshm /dev/shm
(
  cd /blfs/${LFS_PKG_DIR}
  export CC=gcc CXX=g++
  export MACH_USE_SYSTEM_PYTHON=1 
  export MOZBUILD_STATE_PATH=${PWD}/mozbuild
  ./mach configure
  ./mach build
  MACH_USE_SYSTEM_PYTHON=1 ./mach install
  unset CC CXX MACH_USE_SYSTEM_PYTHON MOZBUILD_STATE_PATH
)

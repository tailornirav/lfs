#!/bin/bash
set -e
set +h

# Export
export LFS=/mnt/lfs
export PATH=/usr/bin
export PATH=$LFS/tools/bin:$PATH
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export CONFIG_SITE=$LFS/usr/share/config.site
export MAKEFLAGS="-j8"
export CFLAGS="-march=native -O3 -pipe"
export CXXFLAGS="-march=native -O3 -pipe"

# Binutils
export LFS_PKG_DIR=$(basename -- ${LFS}/sources/binutils*/)
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../configure --prefix=$LFS/tools          \
  --with-sysroot=$LFS                       \
  --target=$LFS_TGT                         \
  --disable-nls                             \
  --disable-werror
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make -C ${LFS}/sources/${LFS_PKG_DIR}/build install

# GCC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/gcc*/)
export LFS_MPC_DIR=$(basename -- ${LFS}/sources/mpc*/)
export LFS_GMP_DIR=$(basename -- ${LFS}/sources/gmp*/)
export LFS_MPFR_DIR=$(basename -- ${LFS}/sources/mpfr*/)
export LFS_MPC_TAR=$(basename -- ${LFS}/sources/mpc*tar.gz)
export LFS_GMP_TAR=$(basename -- ${LFS}/sources/gmp**tar.xz)
export LFS_MPFR_TAR=$(basename -- ${LFS}/sources/mpfr*tar.xz)
tar -xf ${LFS}/sources/${LFS_MPFR_TAR} -C ${LFS}/sources/${LFS_PKG_DIR}
mv -v ${LFS}/sources/${LFS_PKG_DIR}/${LFS_MPFR_DIR} ${LFS}/sources/${LFS_PKG_DIR}/mpfr
tar -xf ${LFS}/sources/${LFS_GMP_TAR} -C ${LFS}/sources/${LFS_PKG_DIR}
mv -v ${LFS}/sources/${LFS_PKG_DIR}/${LFS_GMP_DIR} ${LFS}/sources/${LFS_PKG_DIR}/gmp
tar -xf ${LFS}/sources/${LFS_MPC_TAR} -C ${LFS}/sources/${LFS_PKG_DIR}
mv -v ${LFS}/sources/${LFS_PKG_DIR}/${LFS_MPC_DIR} ${LFS}/sources/${LFS_PKG_DIR}/mpc
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
sed -e '/m64=/s/lib64/lib/' -i.orig ${LFS}/sources/${LFS_PKG_DIR}/gcc/config/i386/t-linux64
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../configure              \
  --target=$LFS_TGT         \
  --prefix=$LFS/tools       \
  --with-glibc-version=2.11 \
  --with-sysroot=$LFS       \
  --with-newlib             \
  --without-headers         \
  --enable-initfini-array   \
  --disable-nls             \
  --disable-shared          \
  --disable-multilib        \
  --disable-decimal-float   \
  --disable-threads         \
  --disable-libatomic       \
  --disable-libgomp         \
  --disable-libquadmath     \
  --disable-libssp          \
  --disable-libvtv          \
  --disable-libstdcxx       \
  --enable-languages=c,c++
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make -C ${LFS}/sources/${LFS_PKG_DIR}/build install
cat ${LFS}/sources/${LFS_PKG_DIR}/gcc/limitx.h ${LFS}/sources/${LFS_PKG_DIR}/gcc/glimits.h ${LFS}/sources/${LFS_PKG_DIR}/gcc/limity.h > \
  `dirname $(${LFS_TGT}-gcc -print-libgcc-file-name)`/install-tools/include/limits.h

# Linux API Headers
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/linux*/)
make -C ${LFS}/sources/${LFS_PKG_DIR} mrproper
make -C ${LFS}/sources/${LFS_PKG_DIR} headers
find ${LFS}/sources/${LFS_PKG_DIR}/usr/include -name '.*' -delete
rm ${LFS}/sources/${LFS_PKG_DIR}/usr/include/Makefile
cp -rv ${LFS}/sources/${LFS_PKG_DIR}/usr/include $LFS/usr

# GLIBC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/glibc*/)
export GCC_VERSION_CUT=$(basename -- ${LFS}/sources/gcc*/ | cut -f2 -d'-')
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
patch -d ${LFS}/sources/${LFS_PKG_DIR} -Np1 -i ${LFS}/sources/${LFS_PKG_DIR}-fhs-1.patch
echo "rootsbindir=/usr/sbin" > ${LFS}/sources/${LFS_PKG_DIR}/configparms
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../configure                              \
  --prefix=/usr                             \
  --host=$LFS_TGT                           \
  --build=$(../scripts/config.guess)        \
  --enable-kernel=3.2                       \
  --with-headers=$LFS/usr/include           \
  libc_cv_slibdir=/usr/lib
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make DESTDIR=$LFS -C ${LFS}/sources/${LFS_PKG_DIR}/build install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
$LFS/tools/libexec/gcc/$LFS_TGT/${GCC_VERSION_CUT}/install-tools/mkheaders

# Libstdc++
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/gcc*/)
export GCC_VERSION_CUT=$(basename -- ${LFS}/sources/gcc*/ | cut -f2 -d'-')
rm -rfv ${LFS}/sources/${LFS_PKG_DIR}/build
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../libstdc++-v3/configure                 \
  --host=$LFS_TGT                           \
  --build=$(../config.guess)                \
  --prefix=/usr                             \
  --disable-multilib                        \
  --disable-nls                             \
  --disable-libstdcxx-pch                   \
  --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/${GCC_VERSION_CUT}
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make DESTDIR=$LFS -C ${LFS}/sources/${LFS_PKG_DIR}/build install

# M4
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/m4*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr             \
  --host=$LFS_TGT                       \
  --build=$(build-aux/config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/
make DESTDIR=$LFS -C ${LFS}/sources/${LFS_PKG_DIR} install

# Ncurses
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/ncurses*/)
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
sed -i s/mawk// ${LFS}/sources/${LFS_PKG_DIR}/configure
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  pushd ${LFS}/sources/${LFS_PKG_DIR}/build
    ../configure
    make -C include
    make -C progs tic
  popd
  ./configure --prefix=/usr    \
  --host=$LFS_TGT              \
  --build=$(./config.guess)    \
  --mandir=/usr/share/man      \
  --with-manpage-format=normal \
  --with-shared                \
  --without-debug              \
  --without-ada                \
  --without-normal             \
  --enable-widec
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make -C ${LFS}/sources/${LFS_PKG_DIR} DESTDIR=$LFS TIC_PATH=${LFS}/sources/${LFS_PKG_DIR}/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so

# Bash
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/bash*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --build=$(support/config.guess)     \
  --host=$LFS_TGT                     \
  --without-bash-malloc
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install
ln -sv bash $LFS/bin/sh

# Coreutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/coreutils*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)   \
  --enable-install-program=hostname   \
  --enable-no-install-program=kill,uptime
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8

# Diffutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/diffutils*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --host=$LFS_TGT
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# File
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/file*/)
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  pushd build
    ../configure --disable-bzlib      \
    --disable-libseccomp              \
    --disable-xzlib                   \
    --disable-zlib
    make
  popd
  ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR} FILE_COMPILE=${LFS}/sources/${LFS_PKG_DIR}/build/src/file
make -C ${LFS}/sources/${LFS_PKG_DIR} DESTDIR=${LFS} install

# Findutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/findutils*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --localstatedir=/var/lib/locate     \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Gawk
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/gawk*/)
sed -i 's/extras//' ${LFS}/sources/${LFS_PKG_DIR}/Makefile.in
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --host=$LFS_TGT                     \
  --build=$(./config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Grep
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/grep*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --host=$LFS_TGT
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Gzip
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/gzip*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --host=$LFS_TGT
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# make
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/make*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --without-guile                     \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Patch
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/patch*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Sed
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/sed*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --host=$LFS_TGT
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Tar
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/tar*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# XZ 
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/xz*/)
(
  cd ${LFS}/sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr           \
  --host=$LFS_TGT                     \
  --build=$(build-aux/config.guess)   \
  --disable-static                    \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C ${LFS}/sources/${LFS_PKG_DIR}
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR} install

# Binutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/binutils*/)
rm -rfv ${LFS}/sources/${LFS_PKG_DIR}/build
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../configure                              \
  --prefix=/usr                             \
  --build=$(../config.guess)                \
  --host=$LFS_TGT                           \
  --disable-nls                             \
  --enable-shared                           \
  --disable-werror                          \
  --enable-64-bit-bfd
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR}/build install
install -vm755 ${LFS}/sources/${LFS_PKG_DIR}/build/libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib

# GCC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- ${LFS}/sources/gcc*/)
rm -rfv ${LFS}/sources/${LFS_PKG_DIR}/build
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build
mkdir -pv ${LFS}/sources/${LFS_PKG_DIR}/build/$LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h ${LFS}/sources/${LFS_PKG_DIR}/build/$LFS_TGT/libgcc/gthr-default.h
(
  cd ${LFS}/sources/${LFS_PKG_DIR}/build
  ../configure                              \
  --build=$(../config.guess)                \
  --host=$LFS_TGT                           \
  --prefix=/usr                             \
  CC_FOR_TARGET=$LFS_TGT-gcc                \
  --with-build-sysroot=$LFS                 \
  --enable-initfini-array                   \
  --disable-nls                             \
  --disable-multilib                        \
  --disable-decimal-float                   \
  --disable-libatomic                       \
  --disable-libgomp                         \
  --disable-libquadmath                     \
  --disable-libssp                          \
  --disable-libvtv                          \
  --disable-libstdcxx                       \
  --enable-languages=c,c++
)
make -C ${LFS}/sources/${LFS_PKG_DIR}/build
make DESTDIR=${LFS} -C ${LFS}/sources/${LFS_PKG_DIR}/build install
ln -sv gcc $LFS/usr/bin/cc

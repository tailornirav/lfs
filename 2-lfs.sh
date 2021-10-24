#!/bin/bash
set -e
set +h

# Export
export MAKEFLAGS="-j8"
export CFLAGS="-march=native -O3 -pipe"
export CXXFLAGS=${CFLAGS}

# Creating remaining directories
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

# Essential files and symlinks
## Mtab
ln -sv /proc/self/mounts /etc/mtab
## Hosts
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
## Passwd
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
## Group
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
## Log files
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Libstdc++
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gcc*/)
rm -rfv /sources/${LFS_PKG_DIR}/build
mkdir -pv /sources/${LFS_PKG_DIR}/build
ln -s gthr-posix.h /sources/${LFS_PKG_DIR}/libgcc/gthr-default.h
(
  cd /sources/${LFS_PKG_DIR}/build
  ../libstdc++-v3/configure                 \
  CXXFLAGS="${CXXFLAGS} -g -D_GNU_SOURCE"   \
  --prefix=/usr                             \
  --disable-multilib                        \
  --disable-nls                             \
  --host=$(uname -m)-lfs-linux-gnu          \
  --disable-libstdcxx-pch
)
make -C /sources/${LFS_PKG_DIR}/build
make -C /sources/${LFS_PKG_DIR}/build install

# Gettext
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gettext*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --disable-shared
)
make -C /sources/${LFS_PKG_DIR}
cp -v /sources/${LFS_PKG_DIR}/gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

# Bison
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/bison*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Perl
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/perl*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1-2 -d'.')
export LFS_PKG_DIR_BASE_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1 -d'.')
(
  cd /sources/${LFS_PKG_DIR}
  sh Configure -des                                                               \
  -Dprefix=/usr                                                                   \
  -Dvendorprefix=/usr                                                             \
  -Dprivlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/core_perl     \
  -Darchlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/core_perl     \
  -Dsitelib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/site_perl     \
  -Dsitearch=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/site_perl    \
  -Dvendorlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/vendor_perl \
  -Dvendorarch=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/vendor_perl
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Python
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/Python*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr     \
  --enable-shared               \
  --without-ensurepip
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Texinfo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/texinfo*/)
sed -e 's/__attribute_nonnull__/__nonnull/' -i /sources/${LFS_PKG_DIR}/gnulib/lib/malloc/dynarray-skeleton.c
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Util-linux
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/util-linux*/)
mkdir -pv /var/lib/hwclock
(
  cd /sources/${LFS_PKG_DIR}
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
  --libdir=/usr/lib                                   \
  --docdir=/usr/share/doc/util-linux-2.37.2           \
  --disable-chfn-chsh                                 \
  --disable-login                                     \
  --disable-nologin                                   \
  --disable-su                                        \
  --disable-setpriv                                   \
  --disable-runuser                                   \
  --disable-pylibmount                                \
  --disable-static                                    \
  --without-python                                    \
  runstatedir=/run
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Stripping
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools

# Package re-calibration.
rm -rf  /sources/$(basename -- /sources/binutils*/) && tar -xf /sources/$(basename -- /sources/binutils-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/glibc*/) && tar -xf /sources/$(basename -- /sources/glibc-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/ncurses*/) && tar -xf /sources/$(basename -- /sources/ncurses-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/gcc*/) && tar -xf /sources/$(basename -- /sources/gcc-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/m4*/) && tar -xf /sources/$(basename -- /sources/m4-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/bash*/) && tar -xf /sources/$(basename -- /sources/bash-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/coreutils*/) && tar -xf /sources/$(basename -- /sources/coreutils-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/findutils*/) && tar -xf /sources/$(basename -- /sources/findutils-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/file*/) && tar -xf /sources/$(basename -- /sources/file-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/gawk*/) && tar -xf /sources/$(basename -- /sources/gawk-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/grep*/) && tar -xf /sources/$(basename -- /sources/grep-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/gzip*/) && tar -xf /sources/$(basename -- /sources/gzip-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/patch*/) && tar -xf /sources/$(basename -- /sources/patch-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/tar*/) && tar -xf /sources/$(basename -- /sources/tar-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/make*/) && tar -xf /sources/$(basename -- /sources/make-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/sed*/) && tar -xf /sources/$(basename -- /sources/sed-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/xz*/) && tar -xf /sources/$(basename -- /sources/xz-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/gettext*/) && tar -xf /sources/$(basename -- /sources/gettext-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/perl*/) && tar -xf /sources/$(basename -- /sources/perl-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/texinfo*/) && tar -xf /sources/$(basename -- /sources/texinfo-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/bison*/) && tar -xf /sources/$(basename -- /sources/bison-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/Python*/) && tar -xf /sources/$(basename -- /sources/Python-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/util-linux*/) && tar -xf /sources/$(basename -- /sources/util-linux-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/linux*/) && tar -xf /sources/$(basename -- /sources/linux-*tar*) -C /sources
rm -rf  /sources/$(basename -- /sources/diffutils*/) && tar -xf /sources/$(basename -- /sources/diffutils-*tar*) -C /sources

# Man Pages
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/man-pages*/)
make prefix=/usr -C /sources/${LFS_PKG_DIR} install

# Iana ETC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/iana-etc*/)
cp -rv /sources/${LFS_PKG_DIR}/services /sources/${LFS_PKG_DIR}/protocols /etc

# Glibc
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/glibc*/)
mkdir -pv /sources/${LFS_PKG_DIR}/build
sed -e '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' -i /sources/${LFS_PKG_DIR}/sysdeps/unix/sysv/linux/mq_notify.c
patch -d /sources/${LFS_PKG_DIR} -Np1 -i /sources/${LFS_PKG_DIR}-fhs-1.patch
echo "rootsbindir=/usr/sbin" > /sources/${LFS_PKG_DIR}/build/configparms
(
  cd /sources/${LFS_PKG_DIR}/build
  ../configure --prefix=/usr               \
  --disable-werror                         \
  --enable-kernel=3.2                      \
  --enable-stack-protector=strong          \
  --with-headers=/usr/include              \
  libc_cv_slibdir=/usr/lib
)
make -C /sources/${LFS_PKG_DIR}/build
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i /sources/${LFS_PKG_DIR}/Makefile
make -C /sources/${LFS_PKG_DIR}/build install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
cp -v /sources/${LFS_PKG_DIR}/nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
cat << EOF > /etc/nsswitch.conf 
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
# End /etc/nsswitch.conf
EOF
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in /sources/etcetera /sources/southamerica /sources/northamerica /sources/europe /sources/africa /sources/antarctica /sources/asia /sources/australasia /sources/backward; do
  zic -L /dev/null   -d $ZONEINFO       ${tz}
  zic -L /dev/null   -d $ZONEINFO/posix ${tz}
  zic -L /sources/leapseconds -d $ZONEINFO/right ${tz}
done
cp -v /sources/zone.tab /sources/zone1970.tab /sources/iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/UTC /etc/localtime
cat << EOF > /etc/ld.so.conf
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
cat << EOF >> /etc/ld.so.conf
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
mkdir -pv /etc/ld.so.conf.d

# Zlib
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/zlib*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
rm -fv /usr/lib/libz.a

# Bzip2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/bzip2*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /sources/bzip2*/ | cut -f2 -d'-')
patch -d /sources/${LFS_PKG_DIR} -Np1 -i /sources/${LFS_PKG_DIR}-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' /sources/${LFS_PKG_DIR}/Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" /sources/${LFS_PKG_DIR}/Makefile
make -C /sources/${LFS_PKG_DIR} -f Makefile-libbz2_so
make -C /sources/${LFS_PKG_DIR} clean
make -C /sources/${LFS_PKG_DIR}
make PREFIX=/usr -C /sources/${LFS_PKG_DIR} install
cp -av /sources/${LFS_PKG_DIR}/libbz2.so.* /usr/lib
ln -sv /sources/${LFS_PKG_DIR}/libbz2.so.${LFS_PKG_DIR_VER} /usr/lib/libbz2.so
cp -v /sources/${LFS_PKG_DIR}/bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a

# Xz
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/xz*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Zstd
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/zstd*/)
make -C /sources/${LFS_PKG_DIR}
make prefix=/usr -C /sources/${LFS_PKG_DIR} install
rm -v /usr/lib/libzstd.a

# File
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/file*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Readline
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/readline*/)
sed -i '/MV.*old/d' /sources/${LFS_PKG_DIR}/Makefile.in
sed -i '/{OLDSUFF}/c:' /sources/${LFS_PKG_DIR}/support/shlib-install
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --with-curses
)
make SHLIB_LIBS="-lncursesw" -C /sources/${LFS_PKG_DIR}
make SHLIB_LIBS="-lncursesw" -C /sources/${LFS_PKG_DIR} install

# M4
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/m4*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# BC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/bc*/)
(
  cd /sources/${LFS_PKG_DIR}
  CC=gcc ./configure --prefix=/usr -G -O3
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Flex
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/flex*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --docdir=/usr/share/doc/${LFS_PKG_DIR} --disable-static
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
ln -sv flex /usr/bin/lex

# Binutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/binutils*/)
mkdir -pv /sources/${LFS_PKG_DIR}/build
patch -d /sources/${LFS_PKG_DIR}/ -Np1 -i /sources/${LFS_PKG_DIR}-upstream_fix-1.patch
sed -i '63d' /sources/${LFS_PKG_DIR}/etc/texi2pod.pl
find /sources/${LFS_PKG_DIR} -name \*.1 -delete
(
  cd /sources/${LFS_PKG_DIR}/build
  ../configure --prefix=/usr  \
  --enable-ld=default         \
  --enable-plugins            \
  --enable-shared             \
  --disable-werror            \
  --enable-64-bit-bfd         \
  --with-system-zlib
)
make -C /sources/${LFS_PKG_DIR}/build tooldir=/usr
make -C /sources/${LFS_PKG_DIR}/build tooldir=/usr install
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a

# GMP
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gmp*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --enable-cxx                \
  --disable-static            \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} html
make -C /sources/${LFS_PKG_DIR} install
make -C /sources/${LFS_PKG_DIR} install-html

# MPFR
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/mpfr*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --enable-thread-safe      \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} html
make -C /sources/${LFS_PKG_DIR} install
make -C /sources/${LFS_PKG_DIR} install-html

# MPC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/mpc*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} html
make -C /sources/${LFS_PKG_DIR} install
make -C /sources/${LFS_PKG_DIR} install-html

# Attr
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/attr*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --sysconfdir=/etc         \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Acl
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/acl*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Lipcap
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/libcap*/)
sed -i '/install -m.*STA/d' /sources/${LFS_PKG_DIR}/libcap/Makefile
make -C /sources/${LFS_PKG_DIR} prefix=/usr lib=lib
make -C /sources/${LFS_PKG_DIR} prefix=/usr lib=lib install
chmod -v 755 /usr/lib/lib{cap,psx}.so.2.53

# Shadow
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/shadow*/)
sed -i 's/groups$(EXEEXT) //' /sources/${LFS_PKG_DIR}/src/Makefile.in
find /sources/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find /sources/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find /sources/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
-e 's:/var/spool/mail:/var/mail:'                     \
-e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                    \
-i /sources/${LFS_PKG_DIR}/etc/login.defs
sed -e "224s/rounds/min_rounds/" -i /sources/${LFS_PKG_DIR}/libmisc/salt.c
touch /usr/bin/passwd
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --sysconfdir=/etc --with-group-name-max-length=32
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} exec_prefix=/usr install
make -C /sources/${LFS_PKG_DIR}/man install-man
mkdir -p /etc/default
useradd -D --gid 999
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd

# GCC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gcc*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /sources/gcc*/ | cut -f2 -d'-')
mkdir -pv /sources/${LFS_PKG_DIR}/build
sed -e '/static.*SIGSTKSZ/d' -e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
-i /sources/${LFS_PKG_DIR}/libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp
sed -e '/m64=/s/lib64/lib/' -i.orig /sources/${LFS_PKG_DIR}/gcc/config/i386/t-linux64
(
  cd /sources/${LFS_PKG_DIR}/build
  ../configure --prefix=/usr  \
  LD=ld                       \
  --enable-languages=c,c++    \
  --disable-multilib          \
  --disable-bootstrap         \
  --with-system-zlib
)
make -C /sources/${LFS_PKG_DIR}/build
make -C /sources/${LFS_PKG_DIR}/build install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/${LFS_PKG_DIR_VER}/include-fixed/bits/
ln -svr /usr/bin/cpp /usr/lib
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/${LFS_PKG_DIR_VER}/liblto_plugin.so /usr/lib/bfd-plugins/
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

# Pkg-config
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/pkg-config*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr  \
  --with-internal-glib       \
  --disable-host-tool        \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Ncurses
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/ncurses*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --mandir=/usr/share/man     \
  --with-shared               \
  --without-debug             \
  --without-normal            \
  --enable-pc-files           \
  --enable-widec
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
for lib in ncurses form panel menu ; do
  rm -vf /usr/lib/lib${lib}.so
  echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
  ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
rm -vf /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so /usr/lib/libcurses.so
rm -fv /usr/lib/libncurses++w.a

# Sed
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/sed*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} html
make -C /sources/${LFS_PKG_DIR} install
install -d -m755 /usr/share/doc/${LFS_PKG_DIR}
install -m644 /sources/${LFS_PKG_DIR}/doc/sed.html /usr/share/doc/${LFS_PKG_DIR}

# Psmisc
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/psmisc*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Gettext
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gettext*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
chmod -v 0755 /usr/lib/preloadable_libintl.so

# Bison
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/bison*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Grep
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/grep*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Bash
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/bash*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr               \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}  \
  --without-bash-malloc                   \
  --with-installed-readline
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Libtool
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/libtool*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
rm -fv /usr/lib/libltdl.a

# GDBM
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gdbm*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --enable-libgdbm-compat
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Gperf
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gperf*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Expat
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/expat*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Inetutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/inetutils*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr         \
  --bindir=/usr/bin                 \
  --localstatedir=/var              \
  --disable-logger                  \
  --disable-whois                   \
  --disable-rcp                     \
  --disable-rexec                   \
  --disable-rlogin                  \
  --disable-rsh                     \
  --disable-servers
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
mv -v /usr/{,s}bin/ifconfig

# Less
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/less*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --sysconfdir=/etc
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Perl
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/perl*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1-2 -d'.')
export LFS_PKG_DIR_BASE_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1 -d'.')
patch -d /sources/${LFS_PKG_DIR} -Np1 -i /sources/${LFS_PKG_DIR}-upstream_fixes-1.patch
export BUILD_ZLIB=False
export BUILD_BZIP2=0
(
  cd /sources/${LFS_PKG_DIR}
  sh Configure -des                                                                 \
  -Dprefix=/usr                                                                     \
  -Dvendorprefix=/usr                                                               \
  -Dprivlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/core_perl       \
  -Darchlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/core_perl       \
  -Dsitelib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/site_perl       \
  -Dsitearch=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/site_perl      \
  -Dvendorlib=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/vendor_perl   \
  -Dvendorarch=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/vendor_perl  \
  -Dman1dir=/usr/share/man/man1                                                     \
  -Dman3dir=/usr/share/man/man3                                                     \
  -Dpager="/usr/bin/less -isR"                                                      \
  -Duseshrplib                                                                      \
  -Dusethreads
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
unset BUILD_ZLIB BUILD_BZIP2

# XML::Parser
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/XML-Parser*/)
(
  cd /sources/${LFS_PKG_DIR}
  perl Makefile.PL
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Intltool
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/intltool*/)
sed -i 's:\\\${:\\\$\\{:' /sources/${LFS_PKG_DIR}/intltool-update.in
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
install -v -Dm644 /sources/${LFS_PKG_DIR}/doc/I18N-HOWTO /usr/share/doc/${LFS_PKG_DIR}/I18N-HOWTO

# Autoconf
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/autoconf*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Automake
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/automake*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Kmod
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/kmod*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --sysconfdir=/etc         \
  --with-xz                 \
  --with-zstd               \
  --with-zlib
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done
ln -sfv kmod /usr/bin/lsmod

# Elfutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/elfutils*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-debuginfod      \
  --enable-libdebuginfod=dummy
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR}/libelf install
install -vm644 /sources/${LFS_PKG_DIR}/config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

# Libffi
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/libffi*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --with-gcc-arch=native    \
  --disable-exec-static-tramp
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# OpenSSL
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/openssl*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./config --prefix=/usr  \
  --openssldir=/etc/ssl   \
  --libdir=lib            \
  shared                  \
  zlib-dynamic
)
make -C /sources/${LFS_PKG_DIR}
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' /sources/${LFS_PKG_DIR}/Makefile
make -C /sources/${LFS_PKG_DIR} MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/${LFS_PKG_DIR}

# Python
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/Python*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --enable-shared           \
  --with-system-expat       \
  --with-system-ffi         \
  --with-ensurepip=yes      \
  --enable-optimizations
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Ninja
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/ninja*/)
(
  cd /sources/${LFS_PKG_DIR}
  python3 configure.py --bootstrap
)
install -vm755 /sources/${LFS_PKG_DIR}/ninja /usr/bin/
install -vDm644 /sources/${LFS_PKG_DIR}/misc/bash-completion /usr/share/bash-completion/completions/ninja

# Meson
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/meson*/)
(
  cd /sources/${LFS_PKG_DIR}
  python3 setup.py build
  python3 setup.py install --root=dest
)
cp -rv /sources/${LFS_PKG_DIR}/dest/* /
install -vDm644 /sources/${LFS_PKG_DIR}/data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson

# Coreutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/coreutils*/)
patch -d /sources/${LFS_PKG_DIR} -Np1 -i /sources/${LFS_PKG_DIR}-i18n-1.patch
(
  cd /sources/${LFS_PKG_DIR}
  autoreconf -fiv
  FORCE_UNSAFE_CONFIGURE=1  \
  ./configure               \
  --prefix=/usr             \
  --enable-no-install-program=kill,uptime
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

# Check
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/check*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} docdir=/usr/share/doc/${LFS_PKG_DIR} install

# Diffutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/diffutils*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# GAWK
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gawk*/)
sed -i 's/extras//' /sources/${LFS_PKG_DIR}/Makefile.in
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Findutils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/findutils*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --localstatedir=/var/lib/locate
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Groff
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/groff*/)
(
  cd /sources/${LFS_PKG_DIR}
  PAGE=A4 ./configure --prefix=/usr
)
make -j1 -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# GZip
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/gzip*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# IP Route 2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/iproute2*/)
sed -i /ARPD/d /sources/${LFS_PKG_DIR}/Makefile
rm -fv /sources/${LFS_PKG_DIR}/man/man8/arpd.8
sed -i 's/.m_ipt.o//' /sources/${LFS_PKG_DIR}/tc/Makefile
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} SBINDIR=/usr/sbin install

# KBD
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/kbd*/)
patch -d /sources/${LFS_PKG_DIR} -Np1 -i /sources/${LFS_PKG_DIR}-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' /sources/${LFS_PKG_DIR}/configure
sed -i 's/resizecons.8 //' /sources/${LFS_PKG_DIR}/docs/man/man8/Makefile.in
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-vlock
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Libpipeline
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/libpipeline*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# make
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/make*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Patch
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/patch*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Tar
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/tar*/)
(
  cd /sources/${LFS_PKG_DIR}
  FORCE_UNSAFE_CONFIGURE=1  \
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
make -C /sources/${LFS_PKG_DIR}/doc install-html docdir=/usr/share/doc/${LFS_PKG_DIR}

# Texinfo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/texinfo*/)
sed -e 's/__attribute_nonnull__/__nonnull/' -i /sources/${LFS_PKG_DIR}/gnulib/lib/malloc/dynarray-skeleton.c
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install
make -C /sources/${LFS_PKG_DIR} TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd

# Eudev
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/eudev*/)
export LFS_UDEV_DIR=$(basename -- /sources/udev-lfs*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --bindir=/usr/sbin        \
  --sysconfdir=/etc         \
  --enable-manpages         \
  --disable-static
)
make -C /sources/${LFS_PKG_DIR}
mkdir -pv /usr/lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make -C /sources/${LFS_PKG_DIR} install
mv /sources/${LFS_UDEV_DIR} /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} -f /sources/${LFS_PKG_DIR}/${LFS_UDEV_DIR}/Makefile.lfs install
udevadm hwdb --update

# Man DB
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/man-db*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr               \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}  \
  --sysconfdir=/etc                       \
  --disable-setuid                        \
  --enable-cache-owner=bin                \
  --with-browser=/usr/bin/lynx            \
  --with-vgrind=/usr/bin/vgrind           \
  --with-grap=/usr/bin/grap               \
  --with-systemdtmpfilesdir=              \
  --with-systemdsystemunitdir=
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Pcocps NG
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/procps*/)
(
  cd /sources/${LFS_PKG_DIR}
  ./configure --prefix=/usr                 \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}    \
  --disable-static                          \
  --disable-kill
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Util Linux
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/util-linux*/)
(
  cd /sources/${LFS_PKG_DIR}/
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
  --libdir=/usr/lib                                   \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}              \
  --disable-chfn-chsh                                 \
  --disable-login                                     \
  --disable-nologin                                   \
  --disable-su                                        \
  --disable-setpriv                                   \
  --disable-runuser                                   \
  --disable-pylibmount                                \
  --disable-static                                    \
  --without-python                                    \
  --without-systemd                                   \
  --without-systemdsystemunitdir                      \
  runstatedir=/run
)
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Sysklogd
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/sysklogd*/)
sed -i '/Error loading kernel symbols/{n;n;d}' /sources/${LFS_PKG_DIR}/ksym_mod.c
sed -i 's/union wait/int/' /sources/${LFS_PKG_DIR}/syslogd.c
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf
auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *
# End /etc/syslog.conf
EOF

# Sysvinit
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/sysvinit*/)
patch -d /sources/${LFS_PKG_DIR} -Np1 -i ../${LFS_PKG_DIR}-consolidated-1.patch
make -C /sources/${LFS_PKG_DIR}
make -C /sources/${LFS_PKG_DIR} install

# Bootscripts
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/lfs-bootscripts*/)
make -C /sources/${LFS_PKG_DIR} install

# Linux Kernel
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /sources/linux*/)
make -C /sources/${LFS_PKG_DIR} mrproper
cp /sources/lfs/static/config /sources/${LFS_PKG_DIR}/.config
cp -rv /sources/lfs/static/firmware /usr/lib
make -C /sources/${LFS_PKG_DIR} olddefconfig
make -C /sources/${LFS_PKG_DIR}
cp -v /sources/${LFS_PKG_DIR}/arch/x86_64/boot/bzImage /boot/vmlinuz-linux

# Disable Debugging Symbols
set +e
save_usrlib="$(cd /usr/lib; ls ld-linux*) libc.so.6 libthread_db.so.1 libquadmath.so.0.0.0 libstdc++.so.6.0.29 libitm.so.1.0.0  libatomic.so.1.2.0" 
(
  cd /usr/lib
  for LIB in $save_usrlib; do
    objcopy --only-keep-debug $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
  done
  online_usrbin="bash find strip"
  online_usrlib="libbfd-2.37.so libhistory.so.8.1 libncursesw.so.6.2 libm.so.6 libreadline.so.8.1 libz.so.1.2.11 $(cd /usr/lib; find libnss*.so* -type f)"
  for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-unneeded /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
  done
  for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-unneeded /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
  done
  for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) $(find /usr/lib -type f -name \*.a) $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
      *$(basename $i)* ) 
      ;;
      * ) strip --strip-unneeded $i 
      ;;
    esac
  done
)
unset BIN LIB save_usrlib online_usrbin online_usrlib
set -e

# Cleaning up
rm -rf /tmp/*
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf

# Network Settings
cat > /etc/sysconfig/ifconfig.enp4s0 << "EOF"
ONBOOT=yes
IFACE=enp4s0
SERVICE=ipv4-static
IP=192.168.1.100
GATEWAY=192.168.1.1
PREFIX=24
BROADCAST=192.168.1.255
EOF
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf
domain quietness.xyz
nameserver 208.67.222.222
nameserver 208.67.220.220
# End /etc/resolv.conf
EOF
echo "quiet" > /etc/hostname
cat > /etc/hosts << "EOF"
# Begin /etc/hosts
127.0.0.1     localhost.localdomain localhost
127.0.1.1     quiet.quietness.xyz quiet
192.168.1.100 quiet.quietness.xyz quiet
# End /etc/hosts
EOF

# System Settings
cat > /etc/inittab << "EOF"
# Begin /etc/inittab
id:3:initdefault:
si::sysinit:/etc/rc.d/init.d/rc S
l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now
su:S016:once:/sbin/sulogin
1:2345:respawn:/sbin/agetty --autologin quiet --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600
# End /etc/inittab
EOF
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock
UTC=1
# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=
# End /etc/sysconfig/clock
EOF
cat > /etc/sysconfig/console << "EOF"
# Begin /etc/sysconfig/console
KEYMAP="dvorak-programmer"
FONT="lat1-16 -m 8859-1"
UNICODE="1"
LOGLEVEL="1"
# End /etc/sysconfig/console
EOF
cat > /etc/sysconfig/rc.site << "EOF"
DISTRO="QUIET LINUX"
DISTRO_CONTACT="quiet@quietness.xyz"
DISTRO_MINI="QUIET"
BRACKET="\\033[1;34m"
FAILURE="\\033[1;31m"
INFO="\\033[1;36m"
NORMAL="\\033[0;39m"
SUCCESS="\\033[1;32m"
WARNING="\\033[1;33m"
BMPREFIX="      "
SUCCESS_PREFIX="${SUCCESS}  *  ${NORMAL} "
FAILURE_PREFIX="${FAILURE}*****${NORMAL} "
WARNING_PREFIX="${WARNING} *** ${NORMAL} "
COLUMNS=120
FASTBOOT=yes
VERBOSE_FSCK=no
OMIT_UDEV_SETTLE=y
OMIT_UDEV_RETRY_SETTLE=yes
SKIPTMPCLEAN=no
UTC=1
CLOCKPARAMS=
LOGLEVEL=1
HOSTNAME=quiet
KILLDELAY=1
SYSKLOGD_PARMS="-m 0"
KEYMAP="dvorak-programmer"
FONT="lat1-16 -m 8859-1"
UNICODE=1
EOF
cat > /etc/profile << "EOF"
# Begin /etc/profile
export LANG=en_US.utf8 UTF8
# End /etc/profile
EOF
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
# End /etc/inputrc
EOF
cat > /etc/shells << "EOF"
# Begin /etc/shells
/bin/sh
/bin/bash
# End /etc/shells
EOF

cat > /etc/fstab << "EOF"
# Begin /etc/fstab
# system        mount-point                   type          options             dump  fsck
/dev/sda1       /boot                         vfat          noauto,defaults     0     0
/dev/sda2       /                             xfs           defaults            1     1
proc            /proc                         proc          nosuid,noexec,nodev 0     0
sysfs           /sys                          sysfs         nosuid,noexec,nodev 0     0
devpts          /dev/pts                      devpts        gid=5,mode=620      0     0
tmpfs           /run                          tmpfs         defaults            0     0
devtmpfs        /dev                          devtmpfs      mode=0755,nosuid    0     0
efivarfs       /sys/firmware/efi/efivars      efivarfs      defaults            0     1
# End /etc/fstab
EOF

#!/bin/bash
set -e 
set +h

# Export
export LFS=/mnt/lfs
export LFS_TGT_DRV=/dev/sda

# Creating partitions
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${LFS_TGT_DRV}
  g 
  n
  1

  +32M
  n
  2


  t
  1
  uefi
  t
  2
  linux
  w
EOF

# Formatting
mkfs -t fat ${LFS_TGT_DRV}1
mkfs -t xfs -f -L root ${LFS_TGT_DRV}2

# Mounting
mkdir -p -v ${LFS}
mount ${LFS_TGT_DRV}2 ${LFS}
mkdir -p -v ${LFS}/boot
mount -v -t vfat ${LFS_TGT_DRV}1 ${LFS}/boot

# Sources Directory
mkdir -pv ${LFS}/sources ${LFS}/blfs
chmod -v a+wt ${LFS}/sources ${LFS}/blfs
cp -r ../lfs ${LFS}/sources/
cp -r ../lfs ${LFS}/blfs/

# Getting required packages
## Downloading  
cat ${LFS}/sources/lfs/static/lfs-list | xargs -n 1 -P 8 wget -c --quiet -P ${LFS}/sources
cat ${LFS}/sources/lfs/static/blfs-list | xargs -n 1 -P 8 wget -c --quiet -P ${LFS}/blfs

## Xorg Libs
cat > ${LFS}/blfs/lib-7.md5 << "EOF"
ce2fb8100c6647ee81451ebe388b17ad  xtrans-1.4.0.tar.bz2
a9a24be62503d5e34df6b28204956a7b  libX11-1.7.2.tar.bz2
f5b48bb76ba327cd2a8dc7a383532a95  libXext-1.3.4.tar.bz2
4e1196275aa743d6ebd3d3d5ec1dff9c  libFS-1.0.8.tar.bz2
76d77499ee7120a56566891ca2c0dbcf  libICE-1.0.10.tar.bz2
87c7fad1c1813517979184c8ccd76628  libSM-1.2.3.tar.bz2
b122ff9a7ec70c94dbbfd814899fffa5  libXt-1.2.1.tar.bz2
ac774cff8b493f566088a255dbf91201  libXmu-1.1.3.tar.bz2
6f0ecf8d103d528cfc803aa475137afa  libXpm-3.5.13.tar.bz2
c1ce21c296bbf3da3e30cf651649563e  libXaw-1.0.14.tar.bz2
86f182f487f4f54684ef6b142096bb0f  libXfixes-6.0.0.tar.bz2
3fa0841ea89024719b20cd702a9b54e0  libXcomposite-0.4.5.tar.bz2
802179a76bded0b658f4e9ec5e1830a4  libXrender-0.9.10.tar.bz2
9b9be0e289130fb820aedf67705fc549  libXcursor-1.2.0.tar.bz2
e3f554267a7a04b042dc1f6352bd6d99  libXdamage-1.1.5.tar.bz2
6447db6a689fb530c218f0f8328c3abc  libfontenc-1.1.4.tar.bz2
bdf528f1d337603c7431043824408668  libXfont2-2.0.5.tar.bz2
5004d8e21cdddfe53266b7293c1dfb1b  libXft-2.3.4.tar.bz2
62c4af0839072024b4b1c8cbe84216c7  libXi-1.7.10.tar.bz2
0d5f826a197dae74da67af4a9ef35885  libXinerama-1.1.4.tar.bz2
18f3b20d522f45e4dadd34afb5bea048  libXrandr-1.5.2.tar.bz2
e142ef0ed0366ae89c771c27cfc2ccd1  libXres-1.2.1.tar.bz2
ef8c2c1d16a00bd95b9fdcef63b8a2ca  libXtst-1.2.3.tar.bz2
210b6ef30dda2256d54763136faa37b9  libXv-1.0.11.tar.bz2
3569ff7f3e26864d986d6a21147eaa58  libXvMC-1.0.12.tar.bz2
0ddeafc13b33086357cfa96fae41ee8e  libXxf86dga-1.1.5.tar.bz2
298b8fff82df17304dfdb5fe4066fe3a  libXxf86vm-1.1.4.tar.bz2
d2f1f0ec68ac3932dd7f1d9aa0a7a11c  libdmx-1.1.4.tar.bz2
b34e2cbdd6aa8f9cc3fa613fd401a6d6  libpciaccess-0.16.tar.bz2
dd7e1e946def674e78c0efbc5c7d5b3b  libxkbfile-1.1.0.tar.bz2
42dda8016943dc12aff2c03a036e0937  libxshmfence-1.3.tar.bz2
EOF
mkdir -pv ${LFS}/blfs/lib
grep -v '^#' ${LFS}/blfs/lib-7.md5 | awk '{print $2}' | wget -i- -c -B https://www.x.org/pub/individual/lib/ -P ${LFS}/blfs/lib

## Extracting
for f in ${LFS}/sources/*.tar.gz; do tar -xf "$f" -C ${LFS}/sources/; done
for f in ${LFS}/sources/*.tar.bz2; do tar -xf "$f" -C ${LFS}/sources/; done
for f in ${LFS}/sources/*.tar.xz; do tar -xf "$f" -C ${LFS}/sources/; done
for f in ${LFS}/blfs/*.tar.gz; do tar -xf "$f" -C ${LFS}/blfs/; done
for f in ${LFS}/blfs/*.tar.bz2; do tar -xf "$f" -C ${LFS}/blfs/; done
for f in ${LFS}/blfs/*.tar.xz; do tar -xf "$f" -C ${LFS}/blfs/; done
for f in ${LFS}/blfs/*.tgz; do tar -xf "$f" -C ${LFS}/blfs/; done

## Resolving potential future error
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- dbus-glib*/)
mkdir -pv ${LFS}/blfs/d-bus-glib
mv ${LFS}/blfs/${LFS_PKG_DIR}/* ${LFS}/blfs/d-bus-glib
rm -rf ${LFS}/blfs/${LFS_PKG_DIR}
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- wayland-protocols*/)
mkdir -pv ${LFS}/blfs/waylandprotocols
mv ${LFS}/blfs/${LFS_PKG_DIR}/* ${LFS}/blfs/waylandprotocols
rm -rf ${LFS}/blfs/${LFS_PKG_DIR}
sync

# Creating limited directory layout
mkdir -pv ${LFS}/{etc,var} ${LFS}/usr/{bin,lib,sbin} ${LFS}/lib64 ${LFS}/tools

for i in bin lib sbin; do
  ln -sv usr/$i ${LFS}/$i
done

# LFS user
## Adding
getent group lfs || groupadd lfs
id -u lfs &>/dev/null || useradd -s /bin/bash -g lfs -m -k /dev/null lfs

## Permissions
chown -v lfs ${LFS}/{usr{,/*},lib,var,etc,bin,sbin,tools}
chown -v lfs ${LFS}/lib64
chown -R lfs:lfs ${LFS}/sources

# bash.bashrc removal
[ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE

# Point to the next script
sudo -u lfs ${LFS}/sources/lfs/1-cross-toolchain.sh

# Changing Ownership
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools,sources}
chown -R root:root $LFS/lib64

# Creating needed directories
mkdir -pv $LFS/{dev,proc,sys,run}

# Initial device nodes
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3

# Mounting
mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

# Mounting /dev/shm
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# Chrooting
chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin /bin/bash --login +h << "EOF"
sh /sources/lfs/2-lfs.sh && sh /blfs/lfs/3-blfs.sh
EOF

#!/bin/bash
set -e 
set +h

# Export
export LFS=/mnt/lfs
export LFS_TGT_DRV=/dev/sdb

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

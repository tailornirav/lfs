#!/bin/bash
set -e
set +h

# Export
export MAKEFLAGS="-j8"
export CFLAGS="-march=native -O3 -pipe"
export CXXFLAGS=${CFLAGS}

# User Add
/sbin/useradd -m -G wheel,input,audio,video -s /bin/bash quiet

# remove-la-files
cat > /usr/sbin/remove-la-files.sh << "EOF"
#!/bin/bash
# /usr/sbin/remove-la-files.sh
# Make sure we are running with root privs
if test "${EUID}" -ne 0; then
    echo "Error: $(basename ${0}) must be run as the root user! Exiting..."
    exit 1
fi

# Make sure PKG_CONFIG_PATH is set if discarded by sudo
source /etc/profile

OLD_LA_DIR=/var/local/la-files

mkdir -p $OLD_LA_DIR

# Only search directories in /opt, but not symlinks to directories
OPTDIRS=$(find /opt -mindepth 1 -maxdepth 1 -type d)

# Move any found .la files to a directory out of the way
find /usr/lib $OPTDIRS -name "*.la" ! -path "/usr/lib/ImageMagick*" \
  -exec mv -fv {} $OLD_LA_DIR \;
###############

# Fix any .pc files that may have .la references

STD_PC_PATH='/usr/lib/pkgconfig 
             /usr/share/pkgconfig 
             /usr/local/lib/pkgconfig 
             /usr/local/share/pkgconfig'

# For each directory that can have .pc files
for d in $(echo $PKG_CONFIG_PATH | tr : ' ') $STD_PC_PATH; do

  # For each pc file
  for pc in $d/*.pc ; do
    if [ $pc == "$d/*.pc" ]; then continue; fi

    # Check each word in a line with a .la reference
    for word in $(grep '\.la' $pc); do
      if $(echo $word | grep -q '.la$' ); then
        mkdir -p $d/la-backup
        cp -fv  $pc $d/la-backup

        basename=$(basename $word )
        libref=$(echo $basename|sed -e 's/^lib/-l/' -e 's/\.la$//')
           
        # Fix the .pc file
        sed -i "s:$word:$libref:" $pc
      fi
    done
  done
done
EOF
chmod +x /usr/sbin/remove-la-files.sh
set +e
sh /usr/sbin/remove-la-files.sh
set -e

# Bash startup files
## Profile
cat > /etc/profile << "EOF"
pathremove () {
        local IFS=':'
        local NEWPATH
        local DIR
        local PATHVARIABLE=${2:-PATH}
        for DIR in ${!PATHVARIABLE} ; do
                if [ "$DIR" != "$1" ] ; then
                  NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
                fi
        done
        export $PATHVARIABLE="$NEWPATH"
}

pathprepend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="$1${!PATHVARIABLE:+:${!PATHVARIABLE}}"
}

pathappend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="${!PATHVARIABLE:+${!PATHVARIABLE}:}$1"
}

export -f pathremove pathprepend pathappend

# Set the initial path
export PATH=/usr/bin

# Attempt to provide backward compatibility with LFS earlier than 11
if [ ! -L /bin ]; then
        pathappend /bin
fi

if [ $EUID -eq 0 ] ; then
        pathappend /usr/sbin
        if [ ! -L /sbin ]; then
                pathappend /sbin
        fi
        unset HISTFILE
fi

# Setup some environment variables.
export HISTSIZE=1000
export HISTIGNORE="&:[bf]g:exit"

# Set some defaults for graphical systems
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/share/}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-/etc/xdg/}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$USER}

# Setup a red prompt for root and a green one for users.
NORMAL="\[\e[0m\]"
RED="\[\e[1;31m\]"
GREEN="\[\e[1;32m\]"
if [[ $EUID == 0 ]] ; then
  PS1="$RED\u [ $NORMAL\w$RED ]# $NORMAL"
else
  PS1="$GREEN\u [ $NORMAL\w$GREEN ]\$ $NORMAL"
fi

for script in /etc/profile.d/*.sh ; do
        if [ -r $script ] ; then
                . $script
        fi
done
unset script RED GREEN NORMAL
# End /etc/profile
EOF

## Profile Directory
install --directory --mode=0755 --owner=root --group=root /etc/profile.d

## Bash completions
cat > /etc/profile.d/bash_completion.sh << "EOF"
# Begin /etc/profile.d/bash_completion.sh
if [ -f /usr/share/bash-completion/bash_completion ]; then
  if [ -n "${BASH_VERSION-}" -a -n "${PS1-}" -a -z "${BASH_COMPLETION_VERSINFO-}" ]; then
    if [ ${BASH_VERSINFO[0]} -gt 4 ] || \
       [ ${BASH_VERSINFO[0]} -eq 4 -a ${BASH_VERSINFO[1]} -ge 1 ]; then
       [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion" ] && \
            . "${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion"
       if shopt -q progcomp && [ -r /usr/share/bash-completion/bash_completion ]; then
          . /usr/share/bash-completion/bash_completion
       fi
    fi
  fi
else
  if shopt -q progcomp; then
    for script in /etc/bash_completion.d/* ; do
      if [ -r $script ] ; then
        . $script
      fi
    done
  fi
fi
# End /etc/profile.d/bash_completion.sh
EOF
install --directory --mode=0755 --owner=root --group=root /etc/bash_completion.d

## Dircolors
cat > /etc/profile.d/dircolors.sh << "EOF"
# Setup for /bin/ls and /bin/grep to support color, the alias is in /etc/bashrc.
if [ -f "/etc/dircolors" ] ; then
        eval $(dircolors -b /etc/dircolors)
fi

if [ -f "$HOME/.dircolors" ] ; then
        eval $(dircolors -b $HOME/.dircolors)
fi

alias ls='ls --color=always'
alias grep='grep --color=always'
EOF

## Extra Path
cat > /etc/profile.d/extrapaths.sh << "EOF"
if [ -d /usr/local/lib/pkgconfig ] ; then
        pathappend /usr/local/lib/pkgconfig PKG_CONFIG_PATH
fi
if [ -d /usr/local/bin ]; then
        pathprepend /usr/local/bin
fi
if [ -d /usr/local/sbin -a $EUID -eq 0 ]; then
        pathprepend /usr/local/sbin
fi

# Set some defaults before other applications add to these paths.
pathappend /usr/share/man  MANPATH
pathappend /usr/share/info INFOPATH
EOF

## Readline
cat > /etc/profile.d/readline.sh << "EOF"
# Setup the INPUTRC environment variable.
if [ -z "$INPUTRC" -a ! -f "$HOME/.inputrc" ] ; then
        INPUTRC=/etc/inputrc
fi
export INPUTRC
EOF

## Umask
cat > /etc/profile.d/umask.sh << "EOF"
# By default, the umask should be set.
if [ "$(id -gn)" = "$(id -un)" -a $EUID -gt 99 ] ; then
  umask 002
else
  umask 022
fi
EOF

## Lang
cat > /etc/profile.d/i18n.sh << "EOF"
# Set up i18n variables
export LANG=en_US.utf8 UTF8
EOF

## Bashrc
cat > /etc/bashrc << "EOF"
# Begin /etc/bashrc

alias ls='ls --color=always'
alias grep='grep --color=auto'

NORMAL="\[\e[0m\]"
RED="\[\e[1;31m\]"
GREEN="\[\e[1;32m\]"
if [[ $EUID == 0 ]] ; then
  PS1="$RED\u [ $NORMAL\w$RED ]# $NORMAL"
else
  PS1="$GREEN\u [ $NORMAL\w$GREEN ]\$ $NORMAL"
fi

unset RED GREEN NORMAL

# End /etc/bashrc
EOF

## Bash Profile
cat > ~/.bash_profile << "EOF"
# Begin ~/.bash_profile

if [ -f "$HOME/.bashrc" ] ; then
  source $HOME/.bashrc
fi

if [ -d "$HOME/bin" ] ; then
  pathprepend $HOME/bin
fi

# End ~/.bash_profile
EOF

## Dircolors
dircolors -p > /etc/dircolors

# Random Number Generator
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/blfs-bootscripts*/)
make -C /blfs/${LFS_PKG_DIR} install-random

# UnZip
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/unzip*/)
export LFS_UNZIP_PATCH=$(basename -- /blfs/unzip-*.patch)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_UNZIP_PATCH}
make -C /blfs/${LFS_PKG_DIR} -f unix/Makefile generic
make -C /blfs/${LFS_PKG_DIR} prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install

# Zip
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/zip*/)
make -C /blfs/${LFS_PKG_DIR} -f unix/Makefile generic_gcc
make -C /blfs/${LFS_PKG_DIR} prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install

# SGML Common
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/sgml-common*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-manpage-1.patch
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf -f -i
  ./configure --prefix=/usr --sysconfdir=/etc
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} docdir=/usr/share/doc install

# ICU
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/icu*/)
(
  cd /blfs/${LFS_PKG_DIR}/source
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}/source
make -C /blfs/${LFS_PKG_DIR}/source install

# libxml2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libxml2*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --with-history              \
  --with-python=/usr/bin/python3 
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# docbook-xml
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /blfs/docbook-xml*.zip | cut -f3 -d'-' | cut -f1-2 -d'.')
mkdir -pv /blfs/temp-docbook-xml
unzip -d /blfs/temp-docbook-xml /blfs/$(basename -- /blfs/docbook-xml*.zip)
install -v -d -m755 /usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}
install -v -d -m755 /etc/xml
chown -R root:root /blfs/temp-docbook-xml
cp -v -af /blfs/temp-docbook-xml/docbook.cat /blfs/temp-docbook-xml/*.dtd /blfs/temp-docbook-xml/ent/ /blfs/temp-docbook-xml/*.mod /usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}
if [ ! -e /etc/xml/docbook ]; then
  xmlcatalog --noout --create /etc/xml/docbook
fi &&
xmlcatalog --noout --add "public" \
 "-//OASIS//DTD DocBook XML V${LFS_PKG_DIR_VER}//EN" \
  "http://www.oasis-open.org/docbook/xml/${LFS_PKG_DIR_VER}/docbookx.dtd" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//DTD DocBook XML CALS Table Model V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/calstblx.dtd" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//DTD XML Exchange Table Model 19990315//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/soextblx.dtd" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ELEMENTS DocBook XML Information Pool V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/dbpoolx.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/dbhierx.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ELEMENTS DocBook XML HTML Tables V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/htmltblx.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ENTITIES DocBook XML Notations V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/dbnotnx.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ENTITIES DocBook XML Character Entities V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/dbcentx.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "public" \
  "-//OASIS//ENTITIES DocBook XML Additional General Entities V${LFS_PKG_DIR_VER}//EN" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}/dbgenent.mod" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "rewriteSystem" \
  "http://www.oasis-open.org/docbook/xml/${LFS_PKG_DIR_VER}" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}" \
  /etc/xml/docbook &&
xmlcatalog --noout --add "rewriteURI" \
  "http://www.oasis-open.org/docbook/xml/${LFS_PKG_DIR_VER}" \
  "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}" \
  /etc/xml/docbook
if [ ! -e /etc/xml/catalog ]; then
    xmlcatalog --noout --create /etc/xml/catalog
fi &&
xmlcatalog --noout --add "delegatePublic" \
  "-//OASIS//ENTITIES DocBook XML" \
  "file:///etc/xml/docbook" \
  /etc/xml/catalog &&
xmlcatalog --noout --add "delegatePublic" \
  "-//OASIS//DTD DocBook XML" \
  "file:///etc/xml/docbook" \
  /etc/xml/catalog &&
xmlcatalog --noout --add "delegateSystem" \
  "http://www.oasis-open.org/docbook/" \
  "file:///etc/xml/docbook" \
  /etc/xml/catalog &&
xmlcatalog --noout --add "delegateURI" \
  "http://www.oasis-open.org/docbook/" \
  "file:///etc/xml/docbook" \
  /etc/xml/catalog
for DTDVERSION in 4.1.2 4.2 4.3 4.4
do
  xmlcatalog --noout --add "public" \
    "-//OASIS//DTD DocBook XML V$DTDVERSION//EN" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/docbookx.dtd" \
    /etc/xml/docbook
  xmlcatalog --noout --add "rewriteSystem" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}" \
    /etc/xml/docbook
  xmlcatalog --noout --add "rewriteURI" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-${LFS_PKG_DIR_VER}" \
    /etc/xml/docbook
  xmlcatalog --noout --add "delegateSystem" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook" \
    /etc/xml/catalog
  xmlcatalog --noout --add "delegateURI" \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook" \
    /etc/xml/catalog
done

# docbook-xsl-nons
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/docbook-xsl-nons*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /blfs/docbook-xsl-nons*/ | cut -f4 -d'-')
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-stack_fix-1.patch
install -v -m755 -d /usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}
cp -v -R /blfs/${LFS_PKG_DIR}/VERSION /blfs/${LFS_PKG_DIR}/assembly /blfs/${LFS_PKG_DIR}/common /blfs/${LFS_PKG_DIR}/eclipse /blfs/${LFS_PKG_DIR}/epub /blfs/${LFS_PKG_DIR}/epub3 /blfs/${LFS_PKG_DIR}/extensions /blfs/${LFS_PKG_DIR}/fo /blfs/${LFS_PKG_DIR}/highlighting /blfs/${LFS_PKG_DIR}/html /blfs/${LFS_PKG_DIR}/htmlhelp /blfs/${LFS_PKG_DIR}/images /blfs/${LFS_PKG_DIR}/javahelp /blfs/${LFS_PKG_DIR}/lib /blfs/${LFS_PKG_DIR}/manpages /blfs/${LFS_PKG_DIR}/params /blfs/${LFS_PKG_DIR}/profiling /blfs/${LFS_PKG_DIR}/roundtrip /blfs/${LFS_PKG_DIR}/slides /blfs/${LFS_PKG_DIR}/template /blfs/${LFS_PKG_DIR}/tests /blfs/${LFS_PKG_DIR}/tools /blfs/${LFS_PKG_DIR}/webhelp /blfs/${LFS_PKG_DIR}/website /blfs/${LFS_PKG_DIR}/xhtml /blfs/${LFS_PKG_DIR}/xhtml-1_1 /blfs/${LFS_PKG_DIR}/xhtml5 /usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}
ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}/VERSION.xsl
install -v -m644 -D /blfs/${LFS_PKG_DIR}/README /usr/share/doc/docbook-xsl-nons-${LFS_PKG_DIR_VER}/README.txt
install -v -m644    /blfs/${LFS_PKG_DIR}/RELEASE-NOTES* /blfs/${LFS_PKG_DIR}/NEWS* /usr/share/doc/docbook-xsl-nons-${LFS_PKG_DIR_VER}
if [ ! -d /etc/xml ]; then install -v -m755 -d /etc/xml; fi &&
if [ ! -f /etc/xml/catalog ]; then
  xmlcatalog --noout --create /etc/xml/catalog
fi
xmlcatalog --noout --add "rewriteSystem" \
  "https://cdn.docbook.org/release/xsl-nons/${LFS_PKG_DIR_VER}" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog &&
xmlcatalog --noout --add "rewriteURI" \
  "https://cdn.docbook.org/release/xsl-nons/${LFS_PKG_DIR_VER}" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog &&
xmlcatalog --noout --add "rewriteSystem" \
  "https://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog &&
xmlcatalog --noout --add "rewriteURI" \
  "https://cdn.docbook.org/release/xsl-nons/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog &&
xmlcatalog --noout --add "rewriteSystem" \
  "http://docbook.sourceforge.net/release/xsl/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog &&
xmlcatalog --noout --add "rewriteURI" \
  "http://docbook.sourceforge.net/release/xsl/current" \
  "/usr/share/xml/docbook/xsl-stylesheets-nons-${LFS_PKG_DIR_VER}" \
/etc/xml/catalog

# libxslt
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libxslt*/)
sed -i s/3000/5000/ /blfs/${LFS_PKG_DIR}/libxslt/transform.c /blfs/${LFS_PKG_DIR}/doc/xsltproc.{1,xml}
sed -i -r '/max(Parser)?Depth/d' /blfs/${LFS_PKG_DIR}/tests/fuzz/fuzz.c
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --without-python
)
make -C /blfs/${LFS_PKG_DIR}
sed -e 's@http://cdn.docbook.org/release/xsl@https://cdn.docbook.org/release/xsl-nons@' \
  -e 's@\$Date\$@31 October 2019@' -i /blfs/${LFS_PKG_DIR}/doc/xsltproc.xml
/blfs/${LFS_PKG_DIR}/xsltproc/xsltproc --nonet /blfs/${LFS_PKG_DIR}/doc/xsltproc.xml -o /blfs/${LFS_PKG_DIR}/doc/xsltproc.1
make -C /blfs/${LFS_PKG_DIR} install

# Linux-PAM
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/Linux-PAM*/)
sed -e /service_DATA/d -i /blfs/${LFS_PKG_DIR}/modules/pam_namespace/Makefile.am
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf
  ./configure --prefix=/usr             \
  --sysconfdir=/etc                     \
  --libdir=/usr/lib                     \
  --enable-securedir=/usr/lib/security  \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
install -v -m755 -d /etc/pam.d

cat > /etc/pam.d/other << "EOF"
auth     required       pam_deny.so
account  required       pam_deny.so
password required       pam_deny.so
session  required       pam_deny.so
EOF
rm -fv /etc/pam.d/other
make -C /blfs/${LFS_PKG_DIR} install
chmod -v 4755 /usr/sbin/unix_chkpwd
install -vdm755 /etc/pam.d
cat > /etc/pam.d/system-account << "EOF"
# Begin /etc/pam.d/system-account

account   required    pam_unix.so

# End /etc/pam.d/system-account
EOF
cat > /etc/pam.d/system-auth << "EOF"
# Begin /etc/pam.d/system-auth

auth      required    pam_unix.so

# End /etc/pam.d/system-auth
EOF
cat > /etc/pam.d/system-session << "EOF"
# Begin /etc/pam.d/system-session

session   required    pam_unix.so

# End /etc/pam.d/system-session
EOF
cat > /etc/pam.d/system-password << "EOF"
# Begin /etc/pam.d/system-password

# use sha512 hash for encryption, use shadow, and try to use any previously
# defined authentication token (chosen password) set by any prior module
password  required    pam_unix.so       sha512 shadow try_first_pass

# End /etc/pam.d/system-password
EOF
cat > /etc/pam.d/other << "EOF"
# Begin /etc/pam.d/other

auth        required        pam_warn.so
auth        required        pam_deny.so
account     required        pam_warn.so
account     required        pam_deny.so
password    required        pam_warn.so
password    required        pam_deny.so
session     required        pam_warn.so
session     required        pam_deny.so

# End /etc/pam.d/other
EOF

# Shadow
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/shadow*/)
sed -i 's/groups$(EXEEXT) //' /blfs/${LFS_PKG_DIR}/src/Makefile.in
find /blfs/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find /blfs/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find /blfs/${LFS_PKG_DIR}/man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
  -e 's@/var/spool/mail@/var/mail@'                   \
  -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
  -i /blfs/${LFS_PKG_DIR}/etc/login.defs
sed -i.orig '/$(LIBTCB)/i $(LIBPAM) \\' /blfs/${LFS_PKG_DIR}/libsubid/Makefile.am
sed -i "224s/rounds/min_rounds/" /blfs/${LFS_PKG_DIR}/libmisc/salt.c
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf -fiv
  ./configure --sysconfdir=/etc --with-group-name-max-length=32
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} exec_prefix=/usr install
sed -i 's/yes/no/' /etc/default/useradd
install -v -m644 /etc/login.defs /etc/login.defs.orig
for FUNCTION in FAIL_DELAY               \
                FAILLOG_ENAB             \
                LASTLOG_ENAB             \
                MAIL_CHECK_ENAB          \
                OBSCURE_CHECKS_ENAB      \
                PORTTIME_CHECKS_ENAB     \
                QUOTAS_ENAB              \
                CONSOLE MOTD_FILE        \
                FTMP_FILE NOLOGINS_FILE  \
                ENV_HZ PASS_MIN_LEN      \
                SU_WHEEL_ONLY            \
                CRACKLIB_DICTPATH        \
                PASS_CHANGE_TRIES        \
                PASS_ALWAYS_WARN         \
                CHFN_AUTH ENCRYPT_METHOD \
                ENVIRON_FILE
do
    sed -i "s/^${FUNCTION}/# &/" /etc/login.defs
done
cat > /etc/pam.d/login << "EOF"
# Begin /etc/pam.d/login

auth      optional    pam_faildelay.so  delay=3000000
auth      requisite   pam_nologin.so
#auth      optional    pam_group.so
auth      include     system-auth
account   required    pam_access.so
account   include     system-account
session   required    pam_env.so
session   required    pam_limits.so
session   include     system-session
password  include     system-password

# End /etc/pam.d/login
EOF
cat > /etc/pam.d/passwd << "EOF"
# Begin /etc/pam.d/passwd

password  include     system-password

# End /etc/pam.d/passwd
EOF
cat > /etc/pam.d/su << "EOF"
# Begin /etc/pam.d/su

auth      sufficient  pam_rootok.so
auth      sufficient  pam_wheel.so trust use_uid
auth      include     system-auth
auth      required    pam_wheel.so use_uid
account   include     system-account
session   required    pam_env.so
session   include     system-session

# End /etc/pam.d/su
EOF
cat > /etc/pam.d/chage << "EOF"
# Begin /etc/pam.d/chage

auth      sufficient  pam_rootok.so
auth      include     system-auth
account   include     system-account
session   include     system-session
password  required    pam_permit.so

# End /etc/pam.d/chage
EOF
for PROGRAM in chfn chgpasswd chpasswd chsh groupadd groupdel \
  groupmems groupmod newusers useradd userdel usermod
do
  install -v -m644 /etc/pam.d/chage /etc/pam.d/${PROGRAM}
  sed -i "s/chage/$PROGRAM/" /etc/pam.d/${PROGRAM}
done
[ -f /etc/login.access ] && mv -v /etc/login.access{,.NOUSE}
[ -f /etc/limits ] && mv -v /etc/limits{,.NOUSE}

# SQLite
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/sqlite*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr         \
  --disable-static                  \
  --enable-fts5                     \
  CPPFLAGS="-DSQLITE_ENABLE_FTS3=1  \
  -DSQLITE_ENABLE_FTS4=1            \
  -DSQLITE_ENABLE_COLUMN_METADATA=1 \
  -DSQLITE_ENABLE_UNLOCK_NOTIFY=1   \
  -DSQLITE_ENABLE_DBSTAT_VTAB=1     \
  -DSQLITE_SECURE_DELETE=1          \
  -DSQLITE_ENABLE_FTS3_TOKENIZER=1"
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# NSPR
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/nspr*/)
sed -ri '/^RELEASE/s/^/#/' /blfs/${LFS_PKG_DIR}/nspr/pr/src/misc/Makefile.in
sed -i 's#$(LIBRARY) ##' /blfs/${LFS_PKG_DIR}/nspr/config/rules.mk
(
  cd /blfs/${LFS_PKG_DIR}/nspr
  ./configure --prefix=/usr \
  --with-mozilla            \
  --with-pthreads           \
  $([ $(uname -m) = x86_64 ] && echo --enable-64bit)
)
make -C /blfs/${LFS_PKG_DIR}/nspr
make -C /blfs/${LFS_PKG_DIR}/nspr install

# NSS
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/nss*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-standalone-1.patch
make -C /blfs/${LFS_PKG_DIR}/nss BUILD_OPT=1 NSPR_INCLUDE_DIR=/usr/include/nspr USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz NSS_ENABLE_WERROR=0 $([ $(uname -m) = x86_64 ] && echo USE_64=1) $([ -f /usr/include/sqlite3.h ] && echo NSS_USE_SYSTEM_SQLITE=1)
install -v -m755 /blfs/${LFS_PKG_DIR}/dist/Linux*/lib/*.so /usr/lib
install -v -m644 /blfs/${LFS_PKG_DIR}/dist/Linux*/lib/{*.chk,libcrmf.a} /usr/lib
install -v -m755 -d /usr/include/nss
cp -v -RL /blfs/${LFS_PKG_DIR}/dist/{public,private}/nss/* /usr/include/nss
chmod -v 644 /usr/include/nss/*
install -v -m755 /blfs/${LFS_PKG_DIR}/dist/Linux*/bin/{certutil,nss-config,pk12util} /usr/bin
install -v -m644 /blfs/${LFS_PKG_DIR}/dist/Linux*/lib/pkgconfig/nss.pc /usr/lib/pkgconfig
ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so

# libtasn1
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libtasn1*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# p11-kit
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/p11-kit*/)
sed '20,$ d' -i /blfs/${LFS_PKG_DIR}/trust/trust-extract-compat
cat >> /blfs/${LFS_PKG_DIR}/trust/trust-extract-compat << "EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Generate a new trust store
/usr/sbin/make-ca -f -g
EOF
mkdir /blfs/${LFS_PKG_DIR}/p11-build
(
  cd /blfs/${LFS_PKG_DIR}/p11-build
  meson --prefix=/usr \
  --buildtype=release \
  -Dtrust_paths=/etc/pki/anchors
)
ninja -C /blfs/${LFS_PKG_DIR}/p11-build
ninja -C /blfs/${LFS_PKG_DIR}/p11-build install
ln -sfv /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates

# Wget
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/wget*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --sysconfdir=/etc           \
  --with-ssl=openssl
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# make-ca
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/make-ca*/)
make -C /blfs/${LFS_PKG_DIR} install
install -vdm755 /etc/ssl/local
/usr/sbin/make-ca -g
(
  cd /blfs/${LFS_PKG_DIR}
  wget http://www.cacert.org/certs/root.crt
  wget http://www.cacert.org/certs/class3.crt
  openssl x509 -in root.crt -text -fingerprint -setalias "CAcert Class 1 root" \
    -addtrust serverAuth -addtrust emailProtection -addtrust codeSigning \
    > /etc/ssl/local/CAcert_Class_1_root.pem
  openssl x509 -in class3.crt -text -fingerprint -setalias "CAcert Class 3 root" \
    -addtrust serverAuth -addtrust emailProtection -addtrust codeSigning \
    > /etc/ssl/local/CAcert_Class_3_root.pem
  /usr/sbin/make-ca -r -f
)

# OpenSSH
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/openssh*/)
install -v -m700 -d /var/lib/sshd
chown -v root:sys /var/lib/sshd
groupadd -g 50 sshd
useradd  -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr                \
  --sysconfdir=/etc/ssh                    \
  --with-md5-passwords                     \
  --with-privsep-path=/var/lib/sshd        \
  --with-default-path=/usr/bin             \
  --with-superuser-path=/usr/sbin:/usr/bin \
  --with-pid-dir=/run
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -m755 /blfs/${LFS_PKG_DIR}/contrib/ssh-copy-id /usr/bin
install -v -m644 /blfs/${LFS_PKG_DIR}/contrib/ssh-copy-id.1 /usr/share/man/man1
install -v -m755 -d /usr/share/doc/${LFS_PKG_DIR}
install -v -m644 /blfs/${LFS_PKG_DIR}/INSTALL /blfs/${LFS_PKG_DIR}/LICENCE \
  /blfs/${LFS_PKG_DIR}/OVERVIEW /blfs/${LFS_PKG_DIR}/README* /usr/share/doc/${LFS_PKG_DIR}
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
make -C /blfs/$(basename -- /blfs/blfs-bootscripts*/) install-sshd

# nghttp2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/nghttp2*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --enable-lib-only           \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# cURL
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/curl*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --disable-static            \
  --with-openssl              \
  --enable-threaded-resolver  \
  --with-ca-path=/etc/ssl/certs
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
rm -rf /blfs/${LFS_PKG_DIR}/docs/examples/.deps
find /blfs/${LFS_PKG_DIR}/docs \( -name Makefile\* -o -name \*.1 -o -name \*.3 \) -exec rm {} \;
install -v -d -m755 /usr/share/doc/${LFS_PKG_DIR}
cp -v -R /blfs/${LFS_PKG_DIR}/docs/* /usr/share/doc/${LFS_PKG_DIR}

# PCRE
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/pcre*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr               \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}  \
  --enable-unicode-properties             \
  --enable-pcre16                         \
  --enable-pcre32                         \
  --enable-pcregrep-libz                  \
  --enable-pcregrep-libbz2                \
  --enable-pcretest-libreadline           \
  --enable-jit                            \
  --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Git
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/git*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1-2 -d'.')
export LFS_PKG_DIR_BASE_VER=$(basename -- /sources/perl*/ | cut -f2 -d'-' | cut -f1 -d'.')
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr       \
  --with-gitconfig=/etc/gitconfig \
  --with-python=python3
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} perllibdir=/usr/lib/perl${LFS_PKG_DIR_BASE_VER}/${LFS_PKG_DIR_VER}/site_perl install

# libuv
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libuv*/)
(
  cd /blfs/${LFS_PKG_DIR}
  sh autogen.sh
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libarchive
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libarchive*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# CMake
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/cmake*/)
sed -i '/"lib64"/s/64//' /blfs/${LFS_PKG_DIR}/Modules/GNUInstallDirs.cmake
(
  cd /blfs/${LFS_PKG_DIR}
  ./bootstrap --prefix=/usr   \
  --system-libs               \
  --mandir=/share/man         \
  --no-system-jsoncpp         \
  --no-system-librhash        \
  --docdir=/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# LLVM
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/llvm*/)
export LFS_CLANG_DIR=$(basename -- /blfs/clang*/)
export LFS_COMPILER_RT_DIR=$(basename -- /blfs/compiler-rt*/)
mv /blfs/${LFS_CLANG_DIR} /blfs/${LFS_PKG_DIR}/tools/clang
mv /blfs/${LFS_COMPILER_RT_DIR} /blfs/${LFS_PKG_DIR}/projects/compiler-rt
(
  cd /blfs/${LFS_PKG_DIR}
  grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'
)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  CC=gcc CXX=g++                            \
  cmake -DCMAKE_INSTALL_PREFIX=/usr         \
  -DLLVM_ENABLE_FFI=ON                      \
  -DCMAKE_BUILD_TYPE=Release                \
  -DLLVM_BUILD_LLVM_DYLIB=ON                \
  -DLLVM_LINK_LLVM_DYLIB=ON                 \
  -DLLVM_ENABLE_RTTI=ON                     \
  -DLLVM_TARGETS_TO_BUILD="host;AMDGPU;BPF" \
  -DLLVM_BUILD_TESTS=ON                     \
  -DLLVM_BINUTILS_INCDIR=/usr/include       \
  -Wno-dev -G Ninja ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libssh2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libssh2*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-security_fixes-1.patch
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Rust
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/rust*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /blfs/rust*/ | cut -f1-2 -d'-')
mkdir /opt/${LFS_PKG_DIR_VER}
ln -svfin ${LFS_PKG_DIR_VER} /opt/rustc
cat << EOF > /blfs/${LFS_PKG_DIR}/config.toml
[llvm]
targets = "X86"
link-shared = true
[build]
docs = false
extended = true
[install]
prefix = "/opt/${LFS_PKG_DIR_VER}"
docdir = "share/doc/${LFS_PKG_DIR_VER}"
[rust]
channel = "stable"
rpath = false
codegen-tests = false
[target.x86_64-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
[target.i686-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
EOF
(
  cd /blfs/${LFS_PKG_DIR}
  export CARGO_BUILD_JOBS=8
  export RUSTFLAGS="$RUSTFLAGS -C link-args=-lffi"
  python3 ./x.py build --jobs 8 --exclude src/tools/miri
  export LIBSSH2_SYS_USE_PKG_CONFIG=1
  DESTDIR=/blfs/${LFS_PKG_DIR}/install python3 ./x.py --jobs 8 install
)
cp -a /blfs/${LFS_PKG_DIR}/install/* /
unset LIBSSH2_SYS_USE_PKG_CONFIG
cat >> /etc/ld.so.conf << EOF
# Begin rustc addition

/opt/rustc/lib

# End rustc addition
EOF
ldconfig
cat > /etc/profile.d/rustc.sh << "EOF"
# Begin /etc/profile.d/rustc.sh

pathprepend /opt/rustc/bin           PATH

# End /etc/profile.d/rustc.sh
EOF
source /etc/profile
source /etc/profile.d/rustc.sh

# Autoconf
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/autoconf*/)
unset LFS_PKG_DIR_VER && export LFS_PKG_DIR_VER=$(basename -- /blfs/autoconf*/ | cut -f2 -d'-')
unset LFS_PKG_DIR_VER_BASE && export LFS_PKG_DIR_VER_BASE=$(basename -- /blfs/autoconf*/ | cut -f2 -d'-' | tr -d '.')
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-consolidated_fixes-1.patch
mv -v /blfs/${LFS_PKG_DIR}/autoconf.texi /blfs/${LFS_PKG_DIR}/autoconf${LFS_PKG_DIR_VER_BASE}.texi
rm -v /blfs/${LFS_PKG_DIR}/autoconf.info
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --program-suffix=${LFS_PKG_DIR_VER}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -m644 /blfs/${LFS_PKG_DIR}/autoconf${LFS_PKG_DIR_VER_BASE}.info /usr/share/info
install-info --info-dir=/usr/share/info /blfs/${LFS_PKG_DIR}/autoconf${LFS_PKG_DIR_VER_BASE}.info

# Which
cat > /usr/bin/which << "EOF"
#!/bin/bash
type -pa "$@" | head -n 1 ; exit ${PIPESTATUS[0]}
EOF
chmod -v 755 /usr/bin/which
chown -v root:root /usr/bin/which

# JS
mountpoint -q /dev/shm || mount -t tmpfs devshm /dev/shm
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/firefox-78*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/obj
(
  cd /blfs/${LFS_PKG_DIR}/obj
  CC=gcc CXX=g++ SHELL=/bin/sh        \
  ../js/src/configure --prefix=/usr   \
  --with-intl-api                     \
  --with-system-zlib                  \
  --with-system-icu                   \
  --disable-jemalloc                  \
  --disable-debug-symbols             \
  --enable-readline
)
make -C /blfs/${LFS_PKG_DIR}/obj
make -C /blfs/${LFS_PKG_DIR}/obj install
rm -v /usr/lib/libjs_static.ajs
sed -i '/@NSPR_CFLAGS@/d' /usr/bin/js78-config

# xmlto
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xmlto*/)
(
  cd /blfs/${LFS_PKG_DIR}
  LINKS="/usr/bin/links" \
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# itstool
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/itstool*/)
(
  cd /blfs/${LFS_PKG_DIR}
  PYTHON=/usr/bin/python3 ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Glib
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/glib*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-skip_warnings-1.patch
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dman=true ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
mkdir -p /usr/share/doc/${LFS_PKG_DIR}
cp -r /blfs/${LFS_PKG_DIR}/docs/reference/{NEWS,gio,glib,gobject} /usr/share/doc/${LFS_PKG_DIR}

# Shared Mime Info
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/shared-mime-info*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dupdate-mimedb=true ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Desktop File Utils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/desktop-file-utils*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# gobject-introspection
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/gobject-introspection*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# dbus
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/dbus*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr               \
  --sysconfdir=/etc                       \
  --localstatedir=/var                    \
  --enable-user-session                   \
  --disable-doxygen-docs                  \
  --disable-xml-docs                      \
  --disable-static                        \
  --with-systemduserunitdir=no            \
  --with-systemdsystemunitdir=no          \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}  \
  --with-console-auth-dir=/run/console    \
  --with-system-pid-file=/run/dbus/pid    \
  --with-system-socket=/run/dbus/system_bus_socket
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
dbus-uuidgen --ensure
ln -sv /var/lib/dbus/machine-id /etc
make -C /blfs/$(basename -- blfs-bootscripts*/) install-dbus

# Freetype
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/freetype*/)
sed -ri "s:.*(AUX_MODULES.*valid):\1:" /blfs/${LFS_PKG_DIR}/modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i /blfs/${LFS_PKG_DIR}/include/freetype/config/ftoption.h
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-freetype-config --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Harfbuzz
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/harfbuzz*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dgraphite=disabled -Dbenchmark=disabled
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Freetype
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/freetype*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.xz -C /blfs
sed -ri "s:.*(AUX_MODULES.*valid):\1:" /blfs/${LFS_PKG_DIR}/modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i /blfs/${LFS_PKG_DIR}/include/freetype/config/ftoption.h
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-freetype-config --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Fontconfig
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/fontconfig*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --sysconfdir=/etc           \
  --localstatedir=/var        \
  --disable-docs              \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -dm755 /usr/share/{man/man{1,3,5},doc/${LFS_PKG_DIR}/fontconfig-devel}
install -v -m644 /blfs/${LFS_PKG_DIR}/fc-*/*.1 /usr/share/man/man1
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/*.3 /usr/share/man/man3
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/fonts-conf.5 /usr/share/man/man5
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/fontconfig-devel/* /usr/share/doc/${LFS_PKG_DIR}/fontconfig-devel
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/*.{pdf,sgml,txt,html} /usr/share/doc/${LFS_PKG_DIR}

# XORG
export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
cat > /etc/profile.d/xorg.sh << EOF
XORG_PREFIX="${XORG_PREFIX}"
XORG_CONFIG="--prefix=${XORG_PREFIX} --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
EOF
chmod 644 /etc/profile.d/xorg.sh

# util-macros
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/util-macros*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR} install

# xorgproto
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xorgproto*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=$XORG_PREFIX -Dlegacy=true ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
install -vdm 755 $XORG_PREFIX/share/doc/${LFS_PKG_DIR}
install -vm 644 /blfs/${LFS_PKG_DIR}/[^m]*.txt /blfs/${LFS_PKG_DIR}/PM_spec $XORG_PREFIX/share/doc/${LFS_PKG_DIR}

# libXau
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libXau*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libXdmcp
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libXdmcp*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# xcb-proto
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xcb-proto*/)
(
  cd /blfs/${LFS_PKG_DIR}
  PYTHON=python3 ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR} install

# libxcb
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libxcb*/)
(
  cd /blfs/${LFS_PKG_DIR}
  CFLAGS="${CFLAGS:--O3 -g} -Wno-error=format-extra-args" \
  PYTHON=python3                \
  ./configure $XORG_CONFIG      \
  --without-doxygen \
  --docdir='${datadir}'/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# xcb-util
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xcb-util*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG      \
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Xorg Libs
cat > /blfs/lib-7.md5 << "EOF"
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
mkdir -pv /blfs/lib
grep -v '^#' /blfs/lib-7.md5 | awk '{print $2}' | wget -i- -c -B https://www.x.org/pub/individual/lib/ -P /blfs/lib
for package in $(grep -v '^#' /blfs/lib-7.md5 | awk '{print $2}'); do
  packagedir=${package%.tar.bz2}
  tar -xf /blfs/lib/$package -C /blfs/lib
  pushd /blfs/lib/$packagedir
  docdir="--docdir=$XORG_PREFIX/share/doc/$packagedir"
  case $packagedir in
    libICE* )
      ./configure $XORG_CONFIG $docdir ICE_LIBS=-lpthread
    ;;
    libXfont2-[0-9]* )
      ./configure $XORG_CONFIG $docdir --disable-devel-docs
    ;;
    libXt-[0-9]* )
      ./configure $XORG_CONFIG $docdir --with-appdefaultdir=/etc/X11/app-defaults
    ;;
    * )
      ./configure $XORG_CONFIG $docdir
    ;;
  esac
  make
  make install
  popd
  /sbin/ldconfig
done

# Neovim
mkdir /blfs/neovim
git clone https://github.com/neovim/neovim.git /blfs/neovim
make -C /blfs/neovim CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/usr
make -C /blfs/neovim CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/usr install

# Wayland
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/wayland-*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Ddocumentation=false
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Wayland Protocols
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/waylandprotocols*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libpng
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libpng*/)
gzip -cd /blfs/${LFS_PKG_DIR}-apng.patch.gz | patch -d /blfs/${LFS_PKG_DIR} -p1
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
mkdir -v /usr/share/doc/${LFS_PKG_DIR}
cp -v /blfs/${LFS_PKG_DIR}/README /blfs/${LFS_PKG_DIR}/libpng-manual.txt /usr/share/doc/${LFS_PKG_DIR}

# Pixman
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/pixman*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Cairo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/cairo*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --enable-tee
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Harfbuzz
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/harfbuzz*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.xz -C /blfs
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dgraphite=disabled -Dbenchmark=disabled
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# NASM
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/nasm*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# YASM
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/yasm*/)
sed -i 's#) ytasm.*#)#' /blfs/${LFS_PKG_DIR}/Makefile.in
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libjpeg-turbo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libjpeg-turbo*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  cmake -DCMAKE_INSTALL_PREFIX=/usr                     \
  -DCMAKE_BUILD_TYPE=RELEASE                            \
  -DENABLE_STATIC=FALSE                                 \
  -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/${LFS_PKG_DIR}  \
  -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib ..
)
make -C /blfs/${LFS_PKG_DIR}/build
make -C /blfs/${LFS_PKG_DIR}/build install

# FriBidi
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/fribidi*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Pango
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/pango*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Gdk Pixbuf
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/gdk-pixbuf*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# librsvg
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/librsvg*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --disable-static          \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# SDL
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/SDL-*/)
sed -e '/_XData32/s:register long:register _Xconst long:' -i /blfs/${LFS_PKG_DIR}/src/video/x11/SDL_x11sym.h
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -m755 -d /usr/share/doc/${LFS_PKG_DIR}/html
install -v -m644 /blfs/${LFS_PKG_DIR}/docs/html/*.html /usr/share/doc/${LFS_PKG_DIR}/html

# libwebp
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libwebp*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --enable-libwebpmux       \
  --enable-libwebpdemux     \
  --enable-libwebpdecoder   \
  --enable-libwebpextras    \
  --enable-swap-16bit-csp   \
  --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libtiff
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/tiff*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/libtiff-build
(
  cd /blfs/${LFS_PKG_DIR}/libtiff-build
  cmake -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/${LFS_PKG_DIR} -DCMAKE_INSTALL_PREFIX=/usr -G Ninja ..
)
ninja -C /blfs/${LFS_PKG_DIR}/libtiff-build
ninja -C /blfs/${LFS_PKG_DIR}/libtiff-build install
sed -i /Version/s/\$/$(cat /blfs/${LFS_PKG_DIR}/VERSION)/ /usr/lib/pkgconfig/libtiff-4.pc

# ATK
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/atk*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# hicolor-icon-theme
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/hicolor-icon-theme*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR} install

# GTK-2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/gtk+-2*/)
sed -e 's#l \(gtk-.*\).sgml#& -o \1#' -i /blfs/${LFS_PKG_DIR}/docs/{faq,tutorial}/Makefile.in
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --sysconfdir=/etc
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Cairo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/cairo*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.xz -C /blfs
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --enable-tee
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Harfbuzz
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/harfbuzz*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.xz -C /blfs
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dgraphite=disabled -Dbenchmark=disabled
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Freetype
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/freetype*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.xz -C /blfs
sed -ri "s:.*(AUX_MODULES.*valid):\1:" /blfs/${LFS_PKG_DIR}/modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i /blfs/${LFS_PKG_DIR}/include/freetype/config/ftoption.h
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-freetype-config --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Fontconfig
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/fontconfig*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.bz2 -C /blfs
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr   \
  --sysconfdir=/etc           \
  --localstatedir=/var        \
  --disable-docs              \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -dm755 /usr/share/{man/man{1,3,5},doc/${LFS_PKG_DIR}/fontconfig-devel}
install -v -m644 /blfs/${LFS_PKG_DIR}/fc-*/*.1 /usr/share/man/man1
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/*.3 /usr/share/man/man3
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/fonts-conf.5 /usr/share/man/man5
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/fontconfig-devel/* /usr/share/doc/${LFS_PKG_DIR}/fontconfig-devel
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/*.{pdf,sgml,txt,html} /usr/share/doc/${LFS_PKG_DIR}

# elogind
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/elogind*/)
sed -i '/Disable polkit/,+8 d' /blfs/${LFS_PKG_DIR}/meson.build
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr                  \
  --buildtype=release                  \
  -Dcgroup-controller=elogind          \
  -Ddbuspolicydir=/etc/dbus-1/system.d \
  -Dman=auto ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
ln -sfv  libelogind.pc /usr/lib/pkgconfig/libsystemd.pc
ln -sfvn elogind /usr/include/systemd
cat >> /etc/pam.d/system-session << "EOF" &&
# Begin elogind addition
    
session  required    pam_loginuid.so
session  optional    pam_elogind.so

# End elogind addition
EOF
cat > /etc/pam.d/elogind-user << "EOF"
# Begin /etc/pam.d/elogind-user

account  required    pam_access.so
account  include     system-account

session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_unix.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_elogind.so

auth     required    pam_deny.so
password required    pam_deny.so

# End /etc/pam.d/elogind-user
EOF

# dbus
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/dbus*/)
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.gz -C /blfs
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr               \
  --sysconfdir=/etc                       \
  --localstatedir=/var                    \
  --enable-user-session                   \
  --disable-doxygen-docs                  \
  --disable-xml-docs                      \
  --disable-static                        \
  --with-systemduserunitdir=no            \
  --with-systemdsystemunitdir=no          \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}  \
  --with-console-auth-dir=/run/console    \
  --with-system-pid-file=/run/dbus/pid    \
  --with-system-socket=/run/dbus/system_bus_socket
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Polkit
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/polkit*/)
groupadd -fg 27 polkitd
useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 -g polkitd -s /bin/false polkitd
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-fix_elogind_detection-1.patch
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf -fv
  ./configure --prefix=/usr   \
  --sysconfdir=/etc           \
  --localstatedir=/var        \
  --disable-static            \
  --with-os-type=LFS          \
  --disable-libsystemd-login
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
cat > /etc/pam.d/polkit-1 << "EOF"
# Begin /etc/pam.d/polkit-1

auth     include        system-auth
account  include        system-account
password include        system-password
session  include        system-session

# End /etc/pam.d/polkit-1
EOF

# MarkupSafe
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/MarkupSafe*/)
(
  cd /blfs/${LFS_PKG_DIR}
  python3 setup.py build
  python3 setup.py install --optimize=1
)

# Mako
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/Mako*/)
(
  cd /blfs/${LFS_PKG_DIR}
  python3 setup.py install --optimize=1
)

# libdrm
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libdrm*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=$XORG_PREFIX --buildtype=release -Dudev=true -Dvalgrind=false
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libva
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libva*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Mesa
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/mesa*/)
sed '1s/python/&3/' -i /blfs/${LFS_PKG_DIR}/bin/symbols-check.py
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=$XORG_PREFIX \
  --buildtype=release         \
  -Ddri-drivers=[]            \
  -Dgallium-drivers=radeonsi  \
  -Dgallium-va=enabled        \
  -Dvulkan-drivers=amd        \
  -Dllvm=enabled              \
  -Dplatforms=wayland         \
  -Dgallium-nine=false        \
  -Dvalgrind=false            \
  -Dlibunwind=disabled ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libva
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libva*/)
make -C /blfs/${LFS_PKG_DIR} uninstall
rm -rf /blfs/${LFS_PKG_DIR}
tar -xf /blfs/${LFS_PKG_DIR}.tar.bz2 -C /blfs
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# at-spi2-core
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/at-spi2-core*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Dsystemd_user_dir=/tmp ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
rm /tmp/at-spi-dbus-bus.service

# at-spi2-atk
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/at-spi2-atk*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libepoxy 
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libepoxy*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# adwaita-icon-theme
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/adwaita-icon-theme*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# iso-codes
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/iso-codes*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# xkeyboard-config
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xkeyboard-config*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG --with-xkb-rules-symlink=xorg
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libxkbcommon 
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libxkbcommon*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release -Denable-docs=false -Denable-wayland=true ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# sass
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libsass*/)
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf -fi
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# sassc
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/sassc*/)
(
  cd /blfs/${LFS_PKG_DIR}
  autoreconf -fi
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# GTK-3
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/gtk+-3*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr  \
  --sysconfdir=/etc          \
  --enable-broadway-backend  \
  --disable-x11-backend       \
  --enable-wayland-backend
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Fonts
cp -rv /blfs/lfs/static/firacode /usr/share/fonts/

# Seatd
mkdir /blfs/seatd
git clone https://git.sr.ht/~kennylevinsen/seatd /blfs/seatd
unset LFS_PKG_DIR && export LFS_PKG_DIR=seatd
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libevdev
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libevdev*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure $XORG_CONFIG
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# mtdev
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/mtdev*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libinput
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libinput*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=$XORG_PREFIX \
  --buildtype=release         \
  -Ddebug-gui=false           \
  -Dtests=false               \
  -Ddocumentation=false       \
  -Dlibwacom=false            \
  ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Json-c
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/json-c*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC_LIBS=OFF ..
)
make -C /blfs/${LFS_PKG_DIR}/build
make -C /blfs/${LFS_PKG_DIR}/build install

# wlroots
mkdir /blfs/wlroots
git clone https://github.com/swaywm/wlroots.git /blfs/wlroots
unset LFS_PKG_DIR && export LFS_PKG_DIR=wlroots
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# sway
mkdir /blfs/sway
git clone https://github.com/swaywm/sway.git /blfs/sway
unset LFS_PKG_DIR && export LFS_PKG_DIR=sway
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# swaybg
mkdir /blfs/swaybg
git clone https://github.com/swaywm/swaybg.git /blfs/swaybg
unset LFS_PKG_DIR && export LFS_PKG_DIR=swaybg
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# grim
mkdir /blfs/grim
git clone https://github.com/emersion/grim.git /blfs/grim
unset LFS_PKG_DIR && export LFS_PKG_DIR=grim
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# slurp
mkdir /blfs/slurp
git clone https://github.com/emersion/slurp.git /blfs/slurp
unset LFS_PKG_DIR && export LFS_PKG_DIR=slurp
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# Foot
mkdir /blfs/foot
git clone https://codeberg.org/dnkl/foot.git /blfs/foot
unset LFS_PKG_DIR && export LFS_PKG_DIR=foot
mkdir -pv /blfs/${LFS_PKG_DIR}/bld/release
(
  cd /blfs/${LFS_PKG_DIR}/bld/release
  meson --buildtype=release --prefix=/usr -Db_lto=true ../..
)
ninja -C /blfs/${LFS_PKG_DIR}/bld/release
ninja -C /blfs/${LFS_PKG_DIR}/bld/release install

# inih
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/inih*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# xfsprogs
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/xfsprogs*/)
(
  cd /blfs/${LFS_PKG_DIR}
  make DEBUG=-DNDEBUG INSTALL_USER=root INSTALL_GROUP=root
)
make -C /blfs/${LFS_PKG_DIR} PKG_DOC_DIR=/usr/share/doc/${LFS_PKG_DIR} install
make -C /blfs/${LFS_PKG_DIR} PKG_DOC_DIR=/usr/share/doc/${LFS_PKG_DIR} install-dev

# efivar
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/efivar*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-gcc_9-1.patch
make -C /blfs/${LFS_PKG_DIR} CFLAGS="-O3 -Wno-stringop-truncation"
make -C /blfs/${LFS_PKG_DIR} install LIBDIR=/usr/lib

# Popt
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/popt*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# efibootmgr
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/efibootmgr*/)
sed -e '/extern int efi_set_verbose/d' -i /blfs/${LFS_PKG_DIR}/src/efibootmgr.c
make -C /blfs/${LFS_PKG_DIR} EFIDIR=LFS EFI_LOADER=bootx64.efi
make -C /blfs/${LFS_PKG_DIR} install EFIDIR=LFS
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
mkdir -pv /boot/efi/boot 
cp -v /boot/vmlinuz-linux /boot/efi/boot/bootx64.efi
efibootmgr --create --disk /dev/sda --part 1 --label "Quiet" --loader "\efi\boot\bootx64.efi"

# alsa-lib
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/alsa-lib*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# alsa-plugins
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/alsa-plugins*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --sysconfdir=/etc
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# alsa-utils
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/alsa-utils*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --disable-alsaconf --disable-bat --disable-xmlto --with-curses=ncursesw
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
alsactl -L store
usermod -a -G audio quiet
make -C /blfs/$(basename -- /blfs/blfs-bootscripts*/) install-alsa

# libogg
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libogg*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Speex
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/speex-*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Speexdsp
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/speexdsp*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libcap
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libcap*/)
make -C /blfs/${LFS_PKG_DIR}/pam_cap
install -v -m755 /blfs/${LFS_PKG_DIR}/pam_cap/pam_cap.so /usr/lib/security
install -v -m644 /blfs/${LFS_PKG_DIR}/pam_cap/capability.conf /etc/security
mv -v /etc/pam.d/system-auth{,.bak}
cat > /etc/pam.d/system-auth << "EOF"
# Begin /etc/pam.d/system-auth

auth      optional    pam_cap.so
EOF
tail -n +3 /etc/pam.d/system-auth.bak >> /etc/pam.d/system-auth

# FLAC
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/flac*/)
patch -d /blfs/${LFS_PKG_DIR} -Np1 -i /blfs/${LFS_PKG_DIR}-security_fixes-1.patch
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-thorough-tests --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libvorbis
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libvorbis*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/Vorbis* /usr/share/doc/${LFS_PKG_DIR}

# Opus
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/opus*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libsndfile
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libsndfile*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# pulseaudio
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/pulseaudio*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr \
  --buildtype=release \
  -Ddatabase=gdbm     \
  -Ddoxygen=false     \
  -Dbluez5=disabled
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
rm -fv /etc/dbus-1/system.d/pulseaudio-system.conf

# Fuse
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/fuse*/)
sed -i '/^udev/,$ s/^/#/' /blfs/${LFS_PKG_DIR}/util/meson.build
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install
chmod u+s /usr/bin/fusermount3
install -v -m755 -d /usr/share/doc/${LFS_PKG_DIR}
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/{README.NFS,kernel.txt} /usr/share/doc/${LFS_PKG_DIR}
cp -Rv /blfs/${LFS_PKG_DIR}/doc/html /usr/share/doc/${LFS_PKG_DIR}

# sshfs
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/sshfs*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  meson --prefix=/usr --buildtype=release ..
)
ninja -C /blfs/${LFS_PKG_DIR}/build
ninja -C /blfs/${LFS_PKG_DIR}/build install

# libass
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libass*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# fdk-aac
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/fdk-aac*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# lame
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/lame*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-mp3rtp --disable-static --enable-nasm
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} pkghtmldir=/usr/share/doc/${LFS_PKG_DIR} install

# libtheora
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libtheora*/)
sed -i 's/png_\(sizeof\)/\1/g' /blfs/${LFS_PKG_DIR}/examples/png2theora.c
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libvpx
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libvpx*/)
sed -i 's/cp -p/cp/' /blfs/${LFS_PKG_DIR}/build/make/Makefile
mkdir -pv /blfs/${LFS_PKG_DIR}/libvpx-build
(
  cd /blfs/${LFS_PKG_DIR}/libvpx-build
  ../configure --prefix=/usr --enable-shared --disable-static
)
make -C /blfs/${LFS_PKG_DIR}/libvpx-build
make -C /blfs/${LFS_PKG_DIR}/libvpx-build install

# x264
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/x264*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-shared --disable-cli
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# x265
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/x265*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/bld
(
  cd /blfs/${LFS_PKG_DIR}/bld
  cmake -DCMAKE_INSTALL_PREFIX=/usr ../source
)
make -C /blfs/${LFS_PKG_DIR}/bld
make -C /blfs/${LFS_PKG_DIR}/bld install
rm -vf /usr/lib/libx265.a

# SDL2
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/SDL2*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
rm -v /usr/lib/libSDL2*.a

# FFMPEG
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/ffmpeg*/)
sed -i 's/-lflite"/-lflite -lasound"/' /blfs/${LFS_PKG_DIR}/configure
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --enable-gpl              \
  --enable-version3         \
  --enable-nonfree          \
  --disable-static          \
  --enable-shared           \
  --disable-debug           \
  --enable-avresample       \
  --enable-libass           \
  --enable-libfdk-aac       \
  --enable-libfreetype      \
  --enable-libmp3lame       \
  --enable-libopus          \
  --enable-libtheora        \
  --enable-libvorbis        \
  --enable-libvpx           \
  --enable-libx264          \
  --enable-libx265          \
  --enable-openssl          \
  --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
gcc /blfs/${LFS_PKG_DIR}/tools/qt-faststart.c -o /blfs/${LFS_PKG_DIR}/tools/qt-faststart
make -C /blfs/${LFS_PKG_DIR} install
install -v -m755 /blfs/${LFS_PKG_DIR}/tools/qt-faststart /usr/bin
install -v -m755 -d /usr/share/doc/${LFS_PKG_DIR}
install -v -m644 /blfs/${LFS_PKG_DIR}/doc/*.txt /usr/share/doc/${LFS_PKG_DIR}

# cbindgen
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/cbindgen*/)
(
  cd /blfs/${LFS_PKG_DIR}
  cargo build --release
)
install -Dm755 /blfs/${LFS_PKG_DIR}/target/release/cbindgen /usr/bin/

# dbus-glib
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/d-bus-glib/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --sysconfdir=/etc --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# c-ares
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/c-ares*/)
mkdir -pv /blfs/${LFS_PKG_DIR}/build
(
  cd /blfs/${LFS_PKG_DIR}/build
  cmake  -DCMAKE_INSTALL_PREFIX=/usr ..
)
make -C /blfs/${LFS_PKG_DIR}/build
make -C /blfs/${LFS_PKG_DIR}/build install

# node
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/node*/)
sed -i 's|ares_nameser.h|arpa/nameser.h|' /blfs/${LFS_PKG_DIR}/src/cares_wrap.h
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr \
  --shared-cares            \
  --shared-libuv            \
  --shared-openssl          \
  --shared-nghttp2          \
  --shared-zlib             \
  --with-intl=system-icu
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
ln -sf node /usr/share/doc/${LFS_PKG_DIR}

# Python
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/Python*/)
(
  cd /blfs/${LFS_PKG_DIR}
  CXX="/usr/bin/g++"        \
  ./configure --prefix=/usr \
  --enable-shared           \
  --with-system-expat       \
  --with-system-ffi         \
  --with-ensurepip=yes      \
  --enable-optimizations
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install
ln -svfn ${LFS_PKG_DIR} /usr/share/doc/python-3

# startup-notification
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/startup-notification*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# libevent
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/libevent*/)
sed -i 's/python/&3/' /blfs/${LFS_PKG_DIR}/event_rpcgen.py
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --disable-static
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# luajit
mkdir /blfs/luajit
git clone https://luajit.org/git/luajit.git /blfs/luajit
make -C /blfs/luajit PREFIX=/usr
make -C /blfs/luajit PREFIX=/usr install

# lzo
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/lzo*/)
(
  cd /blfs/${LFS_PKG_DIR}
  ./configure --prefix=/usr --enable-shared --disable-static --docdir=/usr/share/doc/${LFS_PKG_DIR}
)
make -C /blfs/${LFS_PKG_DIR}
make -C /blfs/${LFS_PKG_DIR} install

# Openvpn
mkdir /blfs/openvpn
git clone https://github.com/OpenVPN/openvpn.git /blfs/openvpn
(
  cd /blfs/openvpn
  autoreconf -ivf
  ./configure --prefix=/usr --disable-lz4
)
make -C /blfs/openvpn
make -C /blfs/openvpn install
mkdir -pv /etc/openvpn
cp /blfs/lfs/static/client.conf /etc/openvpn
cp /blfs/lfs/static/credentials /etc/openvpn

# MPV
mkdir /blfs/mpv
git clone https://github.com/mpv-player/mpv.git /blfs/mpv
(
  cd /blfs/mpv
  ./bootstrap.py
  ./waf configure --prefix=/usr     \
  --disable-android                 \
  --disable-tvos                    \
  --disable-egl-android             \
  --disable-swift                   \
  --disable-uwp                     \
  --disable-win32-internal-pthreads \
  --disable-libbluray               \
  --enable-sdl2                     \
  --lua=luajit                      \
  --disable-x11                     \
  --disable-egl-x11                 \
  --disable-gl-win32                \
  --disable-vdpau                   \
  --disable-vdpau-gl-x11            \
  --disable-d3d11                   \
  --disable-ios-gl                  \
  --disable-d3d-hwaccel             \
  --disable-d3d9-hwaccel            \
  ./waf
  ./waf install
)

# Youtube DL
curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/bin/youtube-dl
chmod a+rx /usr/bin/youtube-dl
ln -sv python3.9 /usr/bin/python

# firefox-9
unset LFS_PKG_DIR && export LFS_PKG_DIR=$(basename -- /blfs/firefox-9*/)
cat > /blfs/${LFS_PKG_DIR}/mozconfig << "EOF"
ac_add_options --disable-necko-wifi
ac_add_options --with-system-libevent
ac_add_options --with-system-webp
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
ac_add_options --with-system-icu
ac_add_options --enable-official-branding
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
  export SHELL=/bin/sh
  export CC=gcc CXX=g++
  export MACH_USE_SYSTEM_PYTHON=1 
  export MOZBUILD_STATE_PATH=${PWD}/mozbuild
  ./mach configure
  ./mach build
  MACH_USE_SYSTEM_PYTHON=1 ./mach install
  unset CC CXX MACH_USE_SYSTEM_PYTHON MOZBUILD_STATE_PATH SHELL
)

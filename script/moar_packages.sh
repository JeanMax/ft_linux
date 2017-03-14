set -e

export MAKEFLAGS='-j 4'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FOLDER="/tools/build/log"

GREEN="\033[32;01m"
RED="\033[31;01m"
NORMAL="\033[0m"

export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc \
    --localstatedir=/var --disable-static"

# UTILS
function error() {
	echo -e "\n$RED$1$NORMAL"
    test $2 && tail -n 25 "$2"
	exit 1
}

function success() {
	echo -e "$GREEN$1$NORMAL"
}

function before() {
    set -x
	cd /sources
	tar --skip-old-files -xvf $(ls $1*tar* || ls $1*tgz) || unzip -d $1 $1*zip
	cd $(ls -d *$1*/)
}

function after() {
	cd /sources
	rm -rf $(ls -d $1*/)
    set +x
}


# BLFS
function install_blfs-bootscripts() {
    # Chapter 3 blfs
    make install-random
}

function install_lsb-release() {
    # Chapter 3 blfs
    sed -i "s|n/a|unavailable|" lsb_release
    ./help2man -N --include ./lsb_release.examples \
               --alt_version_key=program_version ./lsb_release > lsb_release.1
    install -v -m 644 lsb_release.1 /usr/share/man/man1/lsb_release.1
    install -v -m 755 lsb_release /usr/bin/lsb_release
}

function install_sudo() {
    # Chapter 3 blfs
    cat > /etc/profile << "EOF"
# Begin /etc/profile
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>
# modifications by Dagmar d'Surreal <rivyqntzne@pbzpnfg.arg>

# System wide environment variables and startup programs.

# System wide aliases and functions should go in /etc/bashrc.  Personal
# environment variables and startup programs should go into
# ~/.bash_profile.  Personal aliases and functions should go into
# ~/.bashrc.

# Functions to help us manage paths.  Second argument is the name of the
# path variable to be modified (default: PATH)
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
export PATH=/bin:/usr/bin

if [ $EUID -eq 0 ] ; then
        pathappend /sbin:/usr/sbin
        unset HISTFILE
fi

# Setup some environment variables.
export HISTSIZE=1000
export HISTIGNORE="&:[bf]g:exit"

# Set some defaults for graphical systems
export XDG_DATA_DIRS=/usr/share/
export XDG_CONFIG_DIRS=/etc/xdg/

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

    install --directory --mode=0755 --owner=root --group=root /etc/profile.d

    cat > /etc/profile.d/dircolors.sh << "EOF"
# Setup for /bin/ls and /bin/grep to support color, the alias is in /etc/bashrc.
if [ -f "/etc/dircolors" ] ; then
        eval $(dircolors -b /etc/dircolors)
fi

if [ -f "$HOME/.dircolors" ] ; then
        eval $(dircolors -b $HOME/.dircolors)
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
EOF

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

    cat > /etc/profile.d/readline.sh << "EOF"
# Setup the INPUTRC environment variable.
if [ -z "$INPUTRC" -a ! -f "$HOME/.inputrc" ] ; then
        INPUTRC=/etc/inputrc
fi
export INPUTRC
EOF

    cat > /etc/profile.d/umask.sh << "EOF"
# By default, the umask should be set.
if [ "$(id -gn)" = "$(id -un)" -a $EUID -gt 99 ] ; then
  umask 002
else
  umask 022
fi
EOF

    cat > /etc/profile.d/i18n.sh << "EOF"
# Set up i18n variables
export LANG=en_US.UTF-8
EOF

    cat > /etc/bashrc << "EOF"
# Begin /etc/bashrc
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>
# updated by Bruce Dubbs <bdubbs@linuxfromscratch.org>

# System wide aliases and functions.

# System wide environment variables and startup programs should go into
# /etc/profile.  Personal environment variables and startup programs
# should go into ~/.bash_profile.  Personal aliases and functions should
# go into ~/.bashrc

# Provides colored /bin/ls and /bin/grep commands.  Used in conjunction
# with code in /etc/profile.

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Provides prompt for non-login shells, specifically shells started
# in the X environment. [Review the LFS archive thread titled
# PS1 Environment Variable for a great case study behind this script
# addendum.]

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

    cat > ~/.bash_profile << "EOF"
# Begin ~/.bash_profile
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>
# updated by Bruce Dubbs <bdubbs@linuxfromscratch.org>

# Personal environment variables and startup programs.

# Personal aliases and functions should go in ~/.bashrc.  System wide
# environment variables and startup programs are in /etc/profile.
# System wide aliases and functions are in /etc/bashrc.

if [ -f "$HOME/.bashrc" ] ; then
  source $HOME/.bashrc
fi

if [ -d "$HOME/bin" ] ; then
  pathprepend $HOME/bin
fi

# Having . in the PATH is dangerous
#if [ $EUID -gt 99 ]; then
#  pathappend .
#fi

# End ~/.bash_profile
EOF

    cat > ~/.bashrc << "EOF"
# Begin ~/.bashrc
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>

# Personal aliases and functions.

# Personal environment variables and startup programs should go in
# ~/.bash_profile.  System wide environment variables and startup
# programs are in /etc/profile.  System wide aliases and functions are
# in /etc/bashrc.

if [ -f "/etc/bashrc" ] ; then
  source /etc/bashrc
fi

# End ~/.bashrc
EOF

cat > ~/.bash_logout << "EOF"
# Begin ~/.bash_logout
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>

# Personal items to perform on logout.

# End ~/.bash_logout
EOF

dircolors -p > /etc/dircolors


    # Chapter 4 blfs
    ./configure --prefix=/usr              \
                --libexecdir=/usr/lib      \
                --with-secure-path         \
                --with-all-insults         \
                --with-env-editor          \
                --docdir=/usr/share/doc/sudo-1.8.19p2 \
                --with-passprompt="[sudo] password for %p"
    make

    make install
    ln -sfv libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0
}

function install_openssl() {
    # Chapter 4 blfs
    export MAKEFLAGS='-j 1'

    ./config --prefix=/usr         \
             --openssldir=/etc/ssl \
             --libdir=lib          \
             shared                \
             zlib-dynamic
    make depend
    make -j1

    make MANDIR=/usr/share/man MANSUFFIX=ssl install
    install -dv -m755 /usr/share/doc/openssl-1.0.2k
    cp -vfr doc/*     /usr/share/doc/openssl-1.0.2k

    # Certificate Authority Certificates
    cd /sources
    install -vm755 make-ca.sh-20170119 /usr/sbin/make-ca.sh
    /usr/sbin/make-ca.sh

    export MAKEFLAGS='-j 4'
}

function install_openssh() {
    # Chapter 4 blfs
    install  -v -m700 -d /var/lib/sshd
    chown    -v root:sys /var/lib/sshd

    groupadd -g 50 sshd
    useradd  -c 'sshd PrivSep' \
             -d /var/lib/sshd  \
             -g sshd           \
             -s /bin/false     \
             -u 50 sshd

    ./configure --prefix=/usr                     \
                --sysconfdir=/etc/ssh             \
                --with-md5-passwords              \
                --with-privsep-path=/var/lib/sshd
    make

    make install
    install -v -m755    contrib/ssh-copy-id /usr/bin

    install -v -m644    contrib/ssh-copy-id.1 \
            /usr/share/man/man1
    install -v -m755 -d /usr/share/doc/openssh-7.4p1
    install -v -m644    INSTALL LICENCE OVERVIEW README* \
            /usr/share/doc/openssh-7.4p1
}

function install_nano() {
    # Chapter 6 blfs
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --enable-utf8     \
                --docdir=/usr/share/doc/nano-2.6.3
    make

    make install
    install -v -m644 doc/nanorc.sample /etc
    install -v -m644 doc/texinfo/nano.html /usr/share/doc/nano-2.6.3
}

function install_pcre() {
    # Chapter 9 blfs
    ./configure --prefix=/usr                     \
                --docdir=/usr/share/doc/pcre-8.40 \
                --enable-unicode-properties       \
                --enable-pcre16                   \
                --enable-pcre32                   \
                --enable-pcregrep-libz            \
                --enable-pcregrep-libbz2          \
                --enable-pcretest-libreadline     \
                --disable-static
    make

    make install
    mv -v /usr/lib/libpcre.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libpcre.so) /usr/lib/libpcre.so
}

function install_libffi() {
    # Chapter 9 blfs
    sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
        -i include/Makefile.in

    sed -e '/^includedir/ s/=.*$/=@includedir@/' \
        -e 's/^Cflags: -I${includedir}/Cflags:/' \
        -i libffi.pc.in

    ./configure --prefix=/usr --disable-static
    make

    make install
}

function install_giflib() {
    # Chapter 10 blfs
    ./configure --prefix=/usr --disable-static
    make
    make install
}


function install_zsh() {
    # Chapter 7 blfs
    # tar --strip-components=1 -xvf ../zsh-5.3.1-doc.tar.xz

    ./configure --prefix=/usr         \
                --bindir=/bin         \
                --sysconfdir=/etc/zsh \
                --enable-etcdir=/etc/zsh
    make

    makeinfo  Doc/zsh.texi --plaintext -o Doc/zsh.txt
    makeinfo  Doc/zsh.texi --html      -o Doc/html
    makeinfo  Doc/zsh.texi --html --no-split --no-headers -o Doc/zsh.html

    make install
    make infodir=/usr/share/info install.info

    install -v -m755 -d                 /usr/share/doc/zsh-5.3.1/html
    install -v -m644 Doc/html/*         /usr/share/doc/zsh-5.3.1/html
    install -v -m644 Doc/zsh.{html,txt} /usr/share/doc/zsh-5.3.1

    # make htmldir=/usr/share/doc/zsh-5.3.1/html install.html
    # install -v -m644 Doc/zsh.dvi /usr/share/doc/zsh-5.3.1

    mv -v /usr/lib/libpcre* /lib
    ln -v -sf ../../lib/libpcre.so.0 /usr/lib/libpcre.so

    # mv -v /usr/lib/libgdbm.so.* /lib
    # ln -v -sf ../../lib/libgdbm.so.3 /usr/lib/libgdbm.so

    cat >> /etc/shells << "EOF"
/bin/zsh
EOF
}

function install_emacs() {
    # Chapter 6 blfs
    ./autogen.sh
    ./configure --prefix=/usr --localstatedir=/var \
                --without-x --without-xpm --without-jpeg --without-png \
                --without-rsvg --without-imagemagick --without-tiff --without-gif
    make

    make install
    chown -v -R root:root /usr/share/emacs/25.1

    # gtk-update-icon-cache -t -f --include-image-data /usr/share/icons/hicolor
    # update-desktop-database
}

function install_zip() {
    # Chapter 12 blfs
    make -f unix/Makefile generic_gcc

    make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
}

function install_unzip() {
    # Chapter 12 blfs
    make -f unix/Makefile generic

    make prefix=/usr MANDIR=/usr/share/man/man1 \
          -f unix/Makefile install
}

function install_tcl8() {
    # Chapter 13 blfs
    cd unix

    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                $([ $(uname -m) = x86_64 ] && echo --enable-64bit)
    make

    sed -e "s#$SRCDIR/unix#/usr/lib#" \
        -e "s#$SRCDIR#/usr/include#"  \
        -i tclConfig.sh

    sed -e "s#$SRCDIR/unix/pkgs/tdbc1.0.4#/usr/lib/tdbc1.0.4#" \
        -e "s#$SRCDIR/pkgs/tdbc1.0.4/generic#/usr/include#"    \
        -e "s#$SRCDIR/pkgs/tdbc1.0.4/library#/usr/lib/tcl8.6#" \
        -e "s#$SRCDIR/pkgs/tdbc1.0.4#/usr/include#"            \
        -i pkgs/tdbc1.0.4/tdbcConfig.sh

    sed -e "s#$SRCDIR/unix/pkgs/itcl4.0.5#/usr/lib/itcl4.0.5#" \
        -e "s#$SRCDIR/pkgs/itcl4.0.5/generic#/usr/include#"    \
        -e "s#$SRCDIR/pkgs/itcl4.0.5#/usr/include#"            \
        -i pkgs/itcl4.0.5/itclConfig.sh

    unset SRCDIR

    make install
    make install-private-headers
    ln -v -sf tclsh8.6 /usr/bin/tclsh
    chmod -v 755 /usr/lib/libtcl8.6.so

}

function install_expect() {
	# Chapter 13 blfs
	./configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include
    make

    make install
    ln -svf expect5.45/libexpect5.45.so /usr/lib
}

function install_dejagnu() {
    # Chapter 13 blfs
    ./configure --prefix=/usr
	makeinfo --html --no-split -o doc/dejagnu.html doc/dejagnu.texi
    makeinfo --plaintext       -o doc/dejagnu.txt  doc/dejagnu.texi
    make install
    install -v -dm755   /usr/share/doc/dejagnu-1.6
    install -v -m644    doc/dejagnu.{html,txt} \
            /usr/share/doc/dejagnu-1.6
}

function install_check() {
    # Chapter 13 blfs
    ./configure --prefix=/usr --disable-static
	make
    make docdir=/usr/share/doc/check-0.11.0 install
}

function install_Python-3() {
    # Chapter 13 blfs
    CXX="/usr/bin/g++"              \
       ./configure --prefix=/usr       \
       --enable-shared     \
       --with-system-expat \
       --with-system-ffi   \
       --with-ensurepip=yes
    make
    make install
    chmod -v 755 /usr/lib/libpython3.6m.so
    chmod -v 755 /usr/lib/libpython3.so
    install -v -dm755 /usr/share/doc/python-3.6.0/html
    tar --strip-components=1 \
        --no-same-owner \
        --no-same-permissions \
        -C /usr/share/doc/python-3.6.0/html \
        -xvf ../python-3.6.0-docs-html.tar.bz2

}

function install_ruby() {
    # Chapter 13 blfs
    ./configure --prefix=/usr   \
                --enable-shared \
                --docdir=/usr/share/doc/ruby-2.4.0
    make
    make capi
    make install
}

function install_wget() {
    # Chapter 15 blfs
    ./configure --prefix=/usr      \
                --sysconfdir=/etc  \
                --with-ssl=openssl
    make

    make install

    echo ca-directory=/etc/ssl/certs >> /etc/wgetrc
}

function install_curl() {
    # Chapter 17 blfs
    patch -Np1 -i ../curl-7.52.1-valgrind_filter-1.patch
    ./configure --prefix=/usr                           \
                --disable-static                        \
                --enable-threaded-resolver              \
                --with-ca-path=/etc/ssl/certs
    make

    make install

    rm -rf docs/examples/.deps

    find docs \( -name Makefile\* \
         -o -name \*.1       \
         -o -name \*.3 \)    \
         -exec rm {} \;
    install -v -d -m755 /usr/share/doc/curl-7.52.1
    cp -v -R docs/*     /usr/share/doc/curl-7.52.1
}

function install_lynx() {
    # Chapter 18 blfs
    ./configure --prefix=/usr          \
                --sysconfdir=/etc/lynx \
                --datadir=/usr/share/doc/lynx-2.8.8rel.2 \
                --with-zlib            \
                --with-bzlib           \
                --with-screen=ncursesw \
                --enable-locale-charset
    make

    make install-full
    chgrp -v -R root /usr/share/doc/lynx-2.8.8rel.2/lynx_doc

    sed -e '/#LOCALE/     a LOCALE_CHARSET:TRUE'     \
        -i /etc/lynx/lynx.cfg
    sed -e '/#DEFAULT_ED/ a DEFAULT_EDITOR:vi'       \
        -i /etc/lynx/lynx.cfg
    sed -e '/#PERSIST/    a PERSISTENT_COOKIES:TRUE' \
        -i /etc/lynx/lynx.cfg
}

function install_git() {
    # Chapter 13 blfs
    ./configure --prefix=/usr --with-gitconfig=/etc/gitconfig
    make
    # make html
    make install
}

# function install_gpm() {
#     # Chapter 12 blfs
#     sed -i -e 's:<gpm.h>:"headers/gpm.h":' src/prog/{display-buttons,display-coords,get-versions}.c
#     ./autogen.sh
#     ./configure --prefix=/usr --sysconfdir=/etc
#     make

#     make install
#     install-info --dir-file=/usr/share/info/dir           \
#                  /usr/share/info/gpm.info
#     ln -sfv libgpm.so.2.1.0 /usr/lib/libgpm.so
#     install -v -m644 conf/gpm-root.conf /etc
#     install -v -m755 -d /usr/share/doc/gpm-1.20.7/support
#     install -v -m644    doc/support/*                     \
#             /usr/share/doc/gpm-1.20.7/support
#     install -v -m644    doc/{FAQ,HACK_GPM,README*}        \
#             /usr/share/doc/gpm-1.20.7
# }


# X
function install_which() {
    # Chapter 12 blfs
    ./configure --prefix=/usr
    make

    make install
}

function install_libpng() {
    # Chapter 10 blfs
    gzip -cd ../libpng-1.6.28-apng.patch.gz | patch -p0
    LIBS=-lpthread ./configure --prefix=/usr --disable-static
    make

    make install
    mkdir -v /usr/share/doc/libpng-1.6.28
    cp -v README libpng-manual.txt /usr/share/doc/libpng-1.6.28
}

function install_glib-() {
    # Chapter 9 blfs
    ./configure --prefix=/usr --with-pcre=system
    make

    make install
}

function install_icu() {
    # Chapter 9 blfs
    patch -p1 -i ../icu4c-58.2-fix_enumeration-1.patch
    cd source
    ./configure --prefix=/usr
    make

    make install
}


function install_freetype() {
    # Chapter 10 blfs
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg

    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
        -i include/freetype/config/ftoption.h

    ./configure --prefix=/usr --disable-static
    make

    make install
    install -v -m755 -d /usr/share/doc/freetype-2.7.1
    cp -v -R docs/*     /usr/share/doc/freetype-2.7.1
}

function install_harfbuzz() {
    # Chapter 10 blfs
    ./configure --prefix=/usr --with-gobject
    make

    make install
}

function install_freetype-() {
    # Chapter 10 blfs
    install_freetype
}

function install_fontconfig() {
    # Chapter 10 blfs
    sed -e '/FC_CHAR_WIDTH/s/CHAR_WIDTH/CHARWIDTH/'             \
        -e '/FC_CHARWIDTH/a #define FC_CHAR_WIDTH FC_CHARWIDTH' \
        -i fontconfig/fontconfig.h
    sed 's/CHAR_WIDTH/CHARWIDTH/' -i src/fcobjs.h

    ./configure --prefix=/usr        \
                --sysconfdir=/etc    \
                --localstatedir=/var \
                --disable-docs       \
                --docdir=/usr/share/doc/fontconfig-2.12.1
    make
    make install

    install -v -dm755 \
            /usr/share/{man/man{3,5},doc/fontconfig-2.12.1/fontconfig-devel}
    install -v -m644 fc-*/*.1         /usr/share/man/man1
    install -v -m644 doc/*.3          /usr/share/man/man3
    install -v -m644 doc/fonts-conf.5 /usr/share/man/man5
    install -v -m644 doc/fontconfig-devel/* \
            /usr/share/doc/fontconfig-2.12.1/fontconfig-devel
    install -v -m644 doc/*.{pdf,sgml,txt,html} \
            /usr/share/doc/fontconfig-2.12.1
}

function install_util-macros() {
    # Chapter 24 blfs
    cat > /etc/profile.d/xorg.sh << "EOF"
XORG_PREFIX="$XORG_PREFIX"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
EOF
    chmod 644 /etc/profile.d/xorg.sh

    ./configure $XORG_CONFIG

    make install
}

function install_bigreqsproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_compositeproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_damageproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_dmxproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_dri2proto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_dri3proto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_fixesproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_fontsproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_glproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_inputproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_kbproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_presentproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_randrproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_recordproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_renderproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_resourceproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_scrnsaverproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_videoproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xcmiscproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xextproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xf86bigfontproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xf86dgaproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xf86driproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xf86vidmodeproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xineramaproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_xproto() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_libXau() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make

    make install
}

function install_libXdmcp() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make

    make install
}

function install_xcb-proto() {
    # Chapter 24 blfs
    patch -Np1 -i ../xcb-proto-1.12-schema-1.patch
    patch -Np1 -i ../xcb-proto-1.12-python3-1.patch
    ./configure $XORG_CONFIG

    make install
}

function install_libxcb() {
    # Chapter 24 blfs
    patch -Np1 -i ../libxcb-1.12-python3-1.patch
    sed -i "s/pthread-stubs//" configure

    ./configure $XORG_CONFIG      \
                --enable-xinput   \
                --without-doxygen \
                --docdir='${datadir}'/doc/libxcb-1.12
    make

    make install
}

function install_xtrans() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libX11() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXext() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libFS() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libICE() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libSM() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXScrnSaver() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXt-() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG \
        --with-appdefaultdir=/etc/X11/app-defaults
    make
    make install
    /sbin/ldconfig
}

function install_libXmu() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXpm() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXaw() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXfixes() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXcomposite() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXrender() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXcursor() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXdamage() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libfontenc() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXfont2() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG --disable-devel-docs
    make
    make install
    /sbin/ldconfig
}

function install_libXft() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXi-() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXinerama() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXrandr() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXres() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXtst() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXv-() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXvMC() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXxf86dga() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libXxf86vm() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libdmx() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libpciaccess() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libxkbfile() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_libxshmfence() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    /sbin/ldconfig
}

function install_xcb-util-0() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcb-util-image() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcb-util-keysyms() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcb-util-renderutil() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcb-util-wm() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcb-util-cursor() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_libdrm() {
    # Chapter 25 blfs
    sed -i "/pthread-stubs/d" configure.ac
    autoreconf -fiv

    ./configure --prefix=/usr --enable-udev
    make
    make install
}

function install_libvdpau() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG \
                --docdir=/usr/share/doc/libvdpau-1.1.1
    make
    make install
}

function install_libarchive() {
    # Chapter 9 blfs
    ./configure --prefix=/usr --disable-static
    make
    make install
}

function install_elfutils() {
    # Chapter 13 blfs
    ./configure --prefix=/usr --program-prefix="eu-"
    make
    make install
}

function install_cmake() {
    # Chapter 13 blfs
    sed -i '/CMAKE_USE_LIBUV 1/s/1/0/' CMakeLists.txt
    sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake

    ./bootstrap --prefix=/usr       \
                --system-libs       \
                --mandir=/share/man \
                --no-system-jsoncpp \
                --docdir=/share/doc/cmake-3.7.2
    make
    make install
}

function install_Python-2() {
    # Chapter 13 blfs
    ./configure --prefix=/usr       \
                --enable-shared     \
                --with-system-expat \
                --with-system-ffi   \
                --with-ensurepip=yes \
                --enable-unicode=ucs4
    make
    make install
    chmod -v 755 /usr/lib/libpython2.7.so.1.0
    export PYTHONDOCS=/usr/share/doc/python-2.7.13 #TODO
}

function install_llvm() {
    # Chapter 13 blfs
    tar -xf ../cfe-3.9.1.src.tar.xz -C tools
    tar -xf ../compiler-rt-3.9.1.src.tar.xz -C projects

    mv tools/cfe-3.9.1.src tools/clang
    mv projects/compiler-rt-3.9.1.src projects/compiler-rt
    mkdir -v build
    cd       build

    CC=gcc CXX=g++                              \
      cmake -DCMAKE_INSTALL_PREFIX=/usr           \
      -DLLVM_ENABLE_FFI=ON                  \
      -DCMAKE_BUILD_TYPE=Release            \
      -DLLVM_BUILD_LLVM_DYLIB=ON            \
      -DLLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -Wno-dev ..
    make
    make install
}

function install_mesa() {
    # Chapter 24 blfs
    patch -Np1 -i ../mesa-13.0.4-add_xdemos-1.patch
    GLL_DRV="i915,r600,nouveau,radeonsi,svga,swrast"
    sed -i "/pthread_stubs_possible=/s/yes/no/" configure.ac

    ./autogen.sh CFLAGS='-O2' CXXFLAGS='-O2'    \
                 --prefix=$XORG_PREFIX           \
                 --sysconfdir=/etc               \
                 --enable-texture-float          \
                 --enable-osmesa                 \
                 --enable-xa                     \
                 --enable-glx-tls                \
                 --with-egl-platforms="drm,x11"  \
                 --with-gallium-drivers=$GLL_DRV

    unset GLL_DRV

    make
    make -C xdemos DEMOS_PREFIX=$XORG_PREFIX
    make install
    make -C xdemos DEMOS_PREFIX=$XORG_PREFIX install
    install -v -dm755 /usr/share/doc/mesa-13.0.4
    cp -rfv docs/* /usr/share/doc/mesa-13.0.4
}

function install_xbitmaps() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make install
}

function install_iceauth() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_luit() {
    # Chapter 24 blfs
    line1="#ifdef _XOPEN_SOURCE"
    line2="#  undef _XOPEN_SOURCE"
    line3="#  define _XOPEN_SOURCE 600"
    line4="#endif"
    sed -i -e "s@#ifdef HAVE_CONFIG_H@$line1\n$line2\n$line3\n$line4\n\n&@" sys.c
    unset line1 line2 line3 line4
    ./configure $XORG_CONFIG
    make
    make install
}

function install_mkfontdir() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_mkfontscale() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_sessreg() {
    # Chapter 24 blfs
    sed -e 's/\$(CPP) \$(DEFS)/$(CPP) -P $(DEFS)/' -i man/Makefile.in
    ./configure $XORG_CONFIG
    make
    make install
}

function install_setxkbmap() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_smproxy() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_x11perf() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xauth() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xbacklight() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcmsdb() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xcursorgen() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xdpyinfo() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xdriinfo() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xev() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xgamma() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xhost() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xinput() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xkbcomp() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xkbevd() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xkbutils() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xkill() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xlsatoms() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xlsclients() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xmessage() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xmodmap() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xpr-() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xprop() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xrandr() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xrdb() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xrefresh() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xset-() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xsetroot() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xvinfo() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xwd() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xwininfo() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xwud() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
    rm -f $XORG_PREFIX/bin/xkeystone
}

function install_xcursor-themes() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-util() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_encodings() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-alias() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-adobe-utopia-type1() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-bh-ttf() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-bh-type1() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-ibm-type1() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-misc-ethiopic() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_font-xfree86-type1() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xkeyboard-config() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG --with-xkb-rules-symlink=xorg
    make
    make install
}

function install_pixman() {
    # Chapter 10 blfs
    ./configure --prefix=/usr --disable-static
    make
    make install
}

function install_libepoxy() {
    # Chapter 25 blfs
    ./configure --prefix=/usr
    make
    make install
}

function install_xorg-server() {
    # Chapter 24 blfs
    patch -Np1 -i ../xorg-server-1.19.1-add_prime_support-1.patch
    ./configure $XORG_CONFIG            \
                --enable-glamor          \
                --enable-install-setuid  \
                --enable-suid-wrapper    \
                --disable-systemd-logind \
                --with-xkb-output=/var/lib/xkb
    make
    make install
    mkdir -pv /etc/X11/xorg.conf.d
    cat >> /etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF
}

function install_libevdev() {
    # Chapter 24 blfs
    #TODO: reconfigure kernel
    # Device Drivers  --->
    # Input device support --->
    # <*> Generic input layer (needed for...) [CONFIG_INPUT]
    # <*>   Event interface                   [CONFIG_INPUT_EVDEV]
    # [*]   Miscellaneous devices  --->       [CONFIG_INPUT_MISC]
    #       <*>    User level driver support      [CONFIG_INPUT_UINPUT]
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xf86-video-fbdev() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_twm() {
    # Chapter 24 blfs
    sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xterm() {
    # Chapter 24 blfs
    sed -i '/v0/{n;s/new:/new:kb=^?:/}' termcap
    printf '\tkbs=\\177,\n' >> terminfo

    TERMINFO=/usr/share/terminfo \
            ./configure $XORG_CONFIG     \
            --with-app-defaults=/etc/X11/app-defaults

    make
    make install
    make install-ti
    cat >> /etc/X11/app-defaults/XTerm << "EOF"
*VT100*locale: true
*VT100*faceName: Monospace
*VT100*faceSize: 10
*backarrowKeyIsErase: true
*ptyInitialErase: true
EOF
}

function install_xclock() {
    # Chapter 24 blfs
    ./configure $XORG_CONFIG
    make
    make install
}

function install_xinit() {
    # Chapter 24 blfs
    sed -e '/$serverargs $vtarg/ s/serverargs/: #&/' \
        -i startx.cpp
    ./configure $XORG_CONFIG --with-xinitdir=/etc/X11/app-defaults
    make
    make install
    ldconfig

    cat > /etc/X11/xorg.conf.d/xkb-defaults.conf << "EOF"
Section "InputClass"
    Identifier "XKB Defaults"
    MatchIsKeyboard "yes"
    Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF

    #TODO: video driver config?
}

function install_dejavu-fonts() {
    # Chapter 24 blfs
    install -v -d -m755 /usr/share/fonts/dejavu
    install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
    fc-cache -v /usr/share/fonts/dejavu
}


# i3
function install_dbus-1() {
    # Chapter 12 blfs
    groupadd -g 18 messagebus || true
    useradd -c "D-Bus Message Daemon User" -d /var/run/dbus \
            -u 18 -g messagebus -s /bin/false messagebus || true
    ./configure --prefix=/usr                  \
                --sysconfdir=/etc              \
                --localstatedir=/var           \
                --disable-doxygen-docs         \
                --disable-xml-docs             \
                --disable-static               \
                --disable-systemd              \
                --without-systemdsystemunitdir \
                --with-console-auth-dir=/run/console/ \
                --docdir=/usr/share/doc/dbus-1.10.14
    make
    make install
    dbus-uuidgen --ensure

    cat > /etc/dbus-1/session-local.conf << "EOF"
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>

  <!-- Search for .service files in /usr/local -->
  <servicedir>/usr/local/share/dbus-1/services</servicedir>

</busconfig>
EOF

    tar -xvf $(ls ../blfs-bootscripts*tar*)
    cd blfs-bootscripts-20170225
    make install-dbus
}

function install_dbus-glib() {
    # Chapter 9 blfs
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --disable-static
    make
    make install
}

function install_libxkbcommon() {
    # Chapter 9 blfs
    ./configure $XORG_CONFIG     \
                --docdir=/usr/share/doc/libxkbcommon-0.7.1
    make
    make install
}

function install_asciidoc() {
    # Chapter 11 blfs
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/asciidoc-8.6.9
    make
    make install
    make docs
}

function install_libxml2() {
    # Chapter 9 blfs
    ./configure --prefix=/usr --disable-static --with-history
    make
    make install
}

function install_sgml-common() {
    # Chapter 50 blfs
    patch -Np1 -i ../sgml-common-0.6.3-manpage-1.patch
    autoreconf -f -i
    ./configure --prefix=/usr --sysconfdir=/etc
    make
    make docdir=/usr/share/doc install

    install-catalog --add /etc/sgml/sgml-ent.cat \
                    /usr/share/sgml/sgml-iso-entities-8879.1986/catalog

    install-catalog --add /etc/sgml/sgml-docbook.cat \
                    /etc/sgml/sgml-ent.cat
}

function install_docbook-xml() {
    # Chapter 51 blfs
    install -v -d -m755 /usr/share/xml/docbook/xml-dtd-4.5
    install -v -d -m755 /etc/xml
    chown -R root:root .
    cp -v -af docbook.cat *.dtd ent/ *.mod \
       /usr/share/xml/docbook/xml-dtd-4.5

    if [ ! -e /etc/xml/docbook ]; then
        xmlcatalog --noout --create /etc/xml/docbook
    fi
    xmlcatalog --noout --add "public" \
               "-//OASIS//DTD DocBook XML V4.5//EN" \
               "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//DTD XML Exchange Table Model 19990315//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ENTITIES DocBook XML Notations V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "public" \
               "-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod" \
               /etc/xml/docbook
    xmlcatalog --noout --add "rewriteSystem" \
               "http://www.oasis-open.org/docbook/xml/4.5" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5" \
               /etc/xml/docbook
    xmlcatalog --noout --add "rewriteURI" \
               "http://www.oasis-open.org/docbook/xml/4.5" \
               "file:///usr/share/xml/docbook/xml-dtd-4.5" \
               /etc/xml/docbook

    if [ ! -e /etc/xml/catalog ]; then
        xmlcatalog --noout --create /etc/xml/catalog
    fi
    xmlcatalog --noout --add "delegatePublic" \
               "-//OASIS//ENTITIES DocBook XML" \
               "file:///etc/xml/docbook" \
               /etc/xml/catalog
    xmlcatalog --noout --add "delegatePublic" \
               "-//OASIS//DTD DocBook XML" \
               "file:///etc/xml/docbook" \
               /etc/xml/catalog
    xmlcatalog --noout --add "delegateSystem" \
               "http://www.oasis-open.org/docbook/" \
               "file:///etc/xml/docbook" \
               /etc/xml/catalog
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
                   "file:///usr/share/xml/docbook/xml-dtd-4.5" \
                   /etc/xml/docbook
        xmlcatalog --noout --add "rewriteURI" \
                   "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
                   "file:///usr/share/xml/docbook/xml-dtd-4.5" \
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
}

function install_docbook-xsl() {
    # Chapter 51 blfs
    install -v -m755 -d /usr/share/xml/docbook/xsl-stylesheets-1.79.1

    cp -v -R VERSION assembly common eclipse epub epub3 extensions fo        \
       highlighting html htmlhelp images javahelp lib manpages params  \
       profiling roundtrip slides template tests tools webhelp website \
       xhtml xhtml-1_1 xhtml5                                          \
       /usr/share/xml/docbook/xsl-stylesheets-1.79.1

    ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-1.79.1/VERSION.xsl

    install -v -m644 -D README \
            /usr/share/doc/docbook-xsl-1.79.1/README.txt
    install -v -m644    RELEASE-NOTES* NEWS* \
            /usr/share/doc/docbook-xsl-1.79.1

    if [ ! -d /etc/xml ]; then install -v -m755 -d /etc/xml; fi
    if [ ! -f /etc/xml/catalog ]; then
        xmlcatalog --noout --create /etc/xml/catalog
    fi

    xmlcatalog --noout --add "rewriteSystem" \
               "http://docbook.sourceforge.net/release/xsl/1.79.1" \
               "/usr/share/xml/docbook/xsl-stylesheets-1.79.1" \
               /etc/xml/catalog

    xmlcatalog --noout --add "rewriteURI" \
               "http://docbook.sourceforge.net/release/xsl/1.79.1" \
               "/usr/share/xml/docbook/xsl-stylesheets-1.79.1" \
               /etc/xml/catalog

    xmlcatalog --noout --add "rewriteSystem" \
               "http://docbook.sourceforge.net/release/xsl/current" \
               "/usr/share/xml/docbook/xsl-stylesheets-1.79.1" \
               /etc/xml/catalog

    xmlcatalog --noout --add "rewriteURI" \
               "http://docbook.sourceforge.net/release/xsl/current" \
               "/usr/share/xml/docbook/xsl-stylesheets-1.79.1" \
               /etc/xml/catalog
}

function install_libxslt() {
    # Chapter 9 blfs
    ./configure --prefix=/usr --disable-static
    make
    make install
}

function install_xmlto() {
    # Chapter 51 blfs
    LINKS="/usr/bin/links" \
         ./configure --prefix=/usr

    make
    make install
}

function install_cairo() {
    # Chapter 25 blfs
    ./configure --prefix=/usr    \
                --disable-static \
                --enable-tee
    make
    make install
}

function install_pango() {
    # Chapter 25 blfs
    ./configure --prefix=/usr --sysconfdir=/etc
    make
    make install
}

function install_startup() {
    # https://freedesktop.org/wiki/Software/startup-notification/
    ./configure --prefix=/usr
    make
    make install
}

function install_yajl() {
    # http://lloyd.github.io/yajl/
    ./configure --prefix=/usr
    make
    make install
    mv -v /usr/local/lib/libyajl* /usr/lib/
    mv -v /usr/local/include/yajl /usr/include/
    mv -v /usr/local/share/pkgconfig/yajl.pc /usr/share/pkgconfig/
}

function install_libev-() {
    # http://software.schmorp.de/pkg/libev.html
    ./configure --prefix=/usr
    make
    make install
}

function install_Pod() {
    # http://search.cpan.org/dist/Pod-Simple/lib/Pod/Simple.pod
    perl Makefile.PL
    make
    make test
    make install
}


function install_xcb-util-xrm() {
    # https://github.com/Airblader/xcb-util-xrm
    ./configure --prefix=/usr
    make
    make install
}

function install_i3() {
    # https://github.com/i3/i3/blob/next/PACKAGE-MAINTAINER
    autoreconf -fi
    mkdir -p build
    cd build
    ../configure --prefix=/usr
    make
    make install
}


PACKAGES='blfs-bootscripts
lsb-release
sudo
openssl
openssh
nano
pcre
libffi
giflib
zsh
emacs
zip
unzip
tcl8
expect
dejagnu
check
Python-3
ruby
wget
curl
lynx
git
which'

# libpng
# glib-
# icu
# freetype
# harfbuzz
# freetype-
# fontconfig
# util-macros
# bigreqsproto
# compositeproto
# damageproto
# dmxproto
# dri2proto
# dri3proto
# fixesproto
# fontsproto
# glproto
# inputproto
# kbproto
# presentproto
# randrproto
# recordproto
# renderproto
# resourceproto
# scrnsaverproto
# videoproto
# xcmiscproto
# xextproto
# xf86bigfontproto
# xf86dgaproto
# xf86driproto
# xf86vidmodeproto
# xineramaproto
# xproto
# libXau
# libXdmcp
# xcb-proto
# libxcb
# xtrans
# libX11
# libXext
# libFS
# libICE
# libSM
# libXScrnSaver
# libXt-
# libXmu
# libXpm
# libXaw
# libXfixes
# libXcomposite
# libXrender
# libXcursor
# libXdamage
# libfontenc
# libXfont2
# libXft
# libXi-
# libXinerama
# libXrandr
# libXres
# libXtst
# libXv-
# libXvMC
# libXxf86dga
# libXxf86vm
# libdmx
# libpciaccess
# libxkbfile
# libxshmfence
# xcb-util-0
# xcb-util-image
# xcb-util-keysyms
# xcb-util-renderutil
# xcb-util-wm
# xcb-util-cursor
# libdrm
# libvdpau
# elfutils
# libarchive
# cmake
# Python-2
# llvm
# mesa
# xbitmaps
# iceauth
# luit
# mkfontdir
# mkfontscale
# sessreg
# setxkbmap
# smproxy
# x11perf
# xauth
# xbacklight
# xcmsdb
# xcursorgen
# xdpyinfo
# xdriinfo
# xev
# xgamma
# xhost
# xinput
# xkbcomp
# xkbevd
# xkbutils
# xkill
# xlsatoms
# xlsclients
# xmessage
# xmodmap
# xpr-
# xprop
# xrandr
# xrdb
# xrefresh
# xset-
# xsetroot
# xvinfo
# xwd
# xwininfo
# xwud
# xcursor-themes
# font-util
# encodings
# font-alias
# font-adobe-utopia-type1
# font-bh-ttf
# font-bh-type1
# font-ibm-type1
# font-misc-ethiopic
# font-xfree86-type1
# xkeyboard-config
# libepoxy
# pixman
# xorg-server
# libevdev
# xf86-video-fbdev
# twm
# xterm
# xclock
# xinit
# dejavu-fonts
# dbus-1
# dbus-glib
# libxkbcommon
# asciidoc
# libxml2
# sgml-common
# docbook-xml
# docbook-xsl
# libxslt
# xmlto
# cairo
# pango
# startup
# yajl
# libev-
# Pod
# xcb-util-xrm
# i3'

declare -A SBU

SBU["blfs-bootscripts"]=0.1
SBU["lsb-release"]=0.1
SBU["sudo"]=0.3
SBU["openssl"]=1.6
SBU["openssh"]=0.4
SBU["nano"]=0.1
SBU["pcre"]=0.4
SBU["libffi"]=0.1
SBU["giflib"]=0.1
SBU["zsh"]=1
SBU["emacs"]=1.2
SBU["zip"]=0.1
SBU["unzip"]=0.1
SBU["tcl8"]=1
SBU["expect"]=0.2
SBU["dejagnu"]=0.1
SBU["check"]=0.1
SBU["Python-3"]=1.3
SBU["ruby"]=2.4
SBU["wget"]=0.4
SBU["curl"]=0.4
SBU["lynx"]=0.3
SBU["git"]=0.8

SBU["which"]=0.1
SBU["libpng"]=0.8
SBU["glib-"]=1.1
SBU["icu"]=2.1
SBU["freetype"]=0.2
SBU["harfbuzz"]=0.5
SBU["freetype-"]=0.2
SBU["fontconfig"]=0.4
SBU["util-macros"]=0.1
SBU["bigreqsproto"]=0.1
SBU["compositeproto"]=0.1
SBU["damageproto"]=0.1
SBU["dmxproto"]=0.1
SBU["dri2proto"]=0.1
SBU["dri3proto"]=0.1
SBU["fixesproto"]=0.1
SBU["fontsproto"]=0.1
SBU["glproto"]=0.1
SBU["inputproto"]=0.1
SBU["kbproto"]=0.1
SBU["presentproto"]=0.1
SBU["randrproto"]=0.1
SBU["recordproto"]=0.1
SBU["renderproto"]=0.1
SBU["resourceproto"]=0.1
SBU["scrnsaverproto"]=0.1
SBU["videoproto"]=0.1
SBU["xcmiscproto"]=0.1
SBU["xextproto"]=0.1
SBU["xf86bigfontproto"]=0.1
SBU["xf86dgaproto"]=0.1
SBU["xf86driproto"]=0.1
SBU["xf86vidmodeproto"]=0.1
SBU["xineramaproto"]=0.1
SBU["xproto"]=0.1
SBU["libXau"]=0.1
SBU["libXdmcp"]=0.1
SBU["xcb-proto"]=0.1
SBU["libxcb"]=0.3
SBU["xtrans"]=0.1
SBU["libX11"]=0.1
SBU["libXext"]=0.1
SBU["libFS"]=0.1
SBU["libICE"]=0.1
SBU["libSM"]=0.1
SBU["libXScrnSaver"]=0.1
SBU["libXt-"]=0.1
SBU["libXmu"]=0.1
SBU["libXpm"]=0.1
SBU["libXaw"]=0.1
SBU["libXfixes"]=0.1
SBU["libXcomposite"]=0.1
SBU["libXrender"]=0.1
SBU["libXcursor"]=0.1
SBU["libXdamage"]=0.1
SBU["libfontenc"]=0.1
SBU["libXfont2"]=0.1
SBU["libXft"]=0.1
SBU["libXi-"]=0.1
SBU["libXinerama"]=0.1
SBU["libXrandr"]=0.1
SBU["libXres"]=0.1
SBU["libXtst"]=0.1
SBU["libXv-"]=0.1
SBU["libXvMC"]=0.1
SBU["libXxf86dga"]=0.1
SBU["libXxf86vm"]=0.1
SBU["libdmx"]=0.1
SBU["libpciaccess"]=0.1
SBU["libxkbfile"]=0.1
SBU["libxshmfence"]=0.1
SBU["xcb-util-0"]=0.1
SBU["xcb-util-image"]=0.1
SBU["xcb-util-keysyms"]=0.1
SBU["xcb-util-renderutil"]=0.1
SBU["xcb-util-wm"]=0.1
SBU["xcb-util-cursor"]=0.1
SBU["libdrm"]=0.3
SBU["libvdpau"]=0.1
SBU["elfutils"]=0.9
SBU["libarchive"]=0.3
SBU["cmake"]=2.6
SBU["Python-2"]=0.8
SBU["llvm"]=25
SBU["mesa"]=12.3
SBU["xbitmaps"]=0.1
SBU["iceauth"]=0.1
SBU["luit"]=0.1
SBU["mkfontdir"]=0.1
SBU["mkfontscale"]=0.1
SBU["sessreg"]=0.1
SBU["setxkbmap"]=0.1
SBU["smproxy"]=0.1
SBU["x11perf"]=0.1
SBU["xauth"]=0.1
SBU["xbacklight"]=0.1
SBU["xcmsdb"]=0.1
SBU["xcursorgen"]=0.1
SBU["xdpyinfo"]=0.1
SBU["xdriinfo"]=0.1
SBU["xev"]=0.1
SBU["xgamma"]=0.1
SBU["xhost"]=0.1
SBU["xinput"]=0.1
SBU["xkbcomp"]=0.1
SBU["xkbevd"]=0.1
SBU["xkbutils"]=0.1
SBU["xkill"]=0.1
SBU["xlsatoms"]=0.1
SBU["xlsclients"]=0.1
SBU["xmessage"]=0.1
SBU["xmodmap"]=0.1
SBU["xpr-"]=0.1
SBU["xprop"]=0.1
SBU["xrandr"]=0.1
SBU["xrdb"]=0.1
SBU["xrefresh"]=0.1
SBU["xset-"]=0.1
SBU["xsetroot"]=0.1
SBU["xvinfo"]=0.1
SBU["xwd"]=0.1
SBU["xwininfo"]=0.1
SBU["xwud"]=0.1
SBU["xcursor-themes"]=0.1
SBU["font-util"]=0.1
SBU["encodings"]=0.1
SBU["font-alias"]=0.1
SBU["font-adobe-utopia-type1"]=0.1
SBU["font-bh-ttf"]=0.1
SBU["font-bh-type1"]=0.1
SBU["font-ibm-type1"]=0.1
SBU["font-misc-ethiopic"]=0.1
SBU["font-xfree86-type1"]=0.1
SBU["xkeyboard-config"]=0.1
SBU["pixman"]=0.8
SBU["libepoxy"]=0.2
SBU["xorg-server"]=2.3
SBU["libevdev"]=0.1
SBU["xf86-video-fbdev"]=0.1
SBU["twm"]=0.1
SBU["xterm"]=0.1
SBU["xclock"]=0.1
SBU["xinit"]=0.1
SBU["dejavu-fonts"]=0.1

SBU["dbus-1"]=0.3
SBU["dbus-glib"]=0.1
SBU["libxkbcommon"]=0.2
SBU["asciidoc"]=0.1
SBU["libxml2"]=0.6
SBU["sgml-common"]=0.1
SBU["docbook-xml"]=0.1
SBU["docbook-xsl"]=0.1
SBU["libxslt"]=0.3
SBU["xmlto"]=0.1
SBU["cairo"]=0.8
SBU["pango"]=0.3
SBU["startup"]=1 #TODO
SBU["yajl"]=1 #TODO
SBU["libev-"]=1 #TODO
SBU["Pod"]=1 #TODO
SBU["xcb-util-xrm"]=1 #TODO
SBU["i3"]=1 #TODO


SBU_TOTAL=84.6
SBU_PER_SECOND=0.01
SBU_DONE=0

for todo in $PACKAGES; do
    log="$LOG_FOLDER/moar_packages-$todo.log"
	if [ -f "$log" ]; then
		success "$todo already done!"

	    SBU_TOTAL=$(echo "$SBU_TOTAL - ${SBU[$todo]}" | bc -l)
    else
        echo -e "Installing package: $todo\t\t@$(date +"%H:%M:%S")"
        echo "SBU: ${SBU[$todo]}"
        echo "progress: $SBU_DONE / $SBU_TOTAL SBU at $SBU_PER_SECOND SBU/s"
        ETA_PACKAGE=$(echo "${SBU[$todo]} / $SBU_PER_SECOND" | bc)
        ETA_TOTAL=$(echo "($SBU_TOTAL - $SBU_DONE) / $SBU_PER_SECOND" | bc)
        echo -e "eta package: $(date -u -d "0 $ETA_PACKAGE seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_PACKAGE seconds" +"%H:%M:%S")"
        echo -e "eta total: $(date -u -d "0 $ETA_TOTAL seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_TOTAL seconds" +"%H:%M:%S")"

	    before $todo &> "$log.tmp"
		install_$todo &>> "$log.tmp"
        test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
		after $todo &>> "$log.tmp"
		mv "$log.tmp" "$log"

	    SBU_DONE=$(echo "$SBU_DONE + ${SBU[$todo]}" | bc -l)
        SBU_PER_SECOND=$(echo "$SBU_DONE / $SECONDS" | bc -l)
    fi
done

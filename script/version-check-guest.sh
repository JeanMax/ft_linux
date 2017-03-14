#!/bin/bash

set -ex

getfacl --version #acl
getfattr --version #attr
autoconf --version
automake --version
bash --version
bc --version
ar --version #binutils
bison --version
bzip2 --help
checkmk --version #check
chmod --version #coreutils
runtest --version #dejagnu
diff --version #diffutils
udevd --version #eudev
mkfs.ext4 -V #e2fsprogs
xmlwf -v #expat
expect --version
file --version
find --version #findutils
flex --version
gawk --version
gcc --version
gdbmtool --version #gdbm
gettext --version
locale --version #glibc
test -e /usr/lib/libgmp.so #gmp
gperf --version
grep --version
groff --version
grub-mkconfig --version #grub
gzip --version
test -e /etc/protocols #iana-etc
ping --version #inetutils
intltoolize --version #intltool
nstat --version #iproute2
showkey --version #kbd
kmod --version
less --version
capsh --print #libcap
test -e /usr/lib/libpipeline.so #libpipeline
libtool --version
m4 --version
make --version
man --version #man-db
test -e /usr/share/man/man1/locale.1  #man-pages
test -e /usr/lib/libmpc.so #mpc
test -e /usr/lib/libmpfr.so #mpfr
ncursesw6-config --version #ncurses
patch --version
perl --version
pkg-config --version
pgrep --version #procps-ng
killall --version #psmisc
test -e /usr/lib/libreadline.so #readline
sed --version
su --help #shadow
syslogd -v #sysklogd
bootlogd #sysvinit
tar --version
echo | tclsh #tcl
info --version #texinfo
test -e /usr/share/zoneinfo/Europe/Paris #Time Zone Data
test -e /etc/udev/rules.d/55-lfs.rules #Udev-lfs Tarball
mount --version #util-linux
vim --version
test -e /usr/lib/perl5/site_perl/5.24.1/i686-linux/auto/XML/Parser/Expat/Expat.so #XML::Parser
xz --version
test -e /usr/lib/libz.so #zlib





echo
echo yay

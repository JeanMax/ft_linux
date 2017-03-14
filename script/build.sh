set -e

MAKE_CHECK='false'

export MAKEFLAGS='-j 4'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FOLDER="/tools/build/log"

GREEN="\033[32;01m"
RED="\033[31;01m"
NORMAL="\033[0m"

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
	tar --skip-old-files -xvf $(ls $1*tar*)
	cd $(ls -d $1*/)
}

function after() {
	cd /sources
	rm -rf $(ls -d $1*/)
    set +x
}

# CREATE ENV
function create_dir_n_links() {
	# Chapter 6.5
	mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
	mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
	install -dv -m 0750 /root
	install -dv -m 1777 /tmp /var/tmp
	mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
	mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
	mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir -pv /usr/libexec
	mkdir -pv /usr/{,local/}share/man/man{1..8}

	case $(uname -m) in
		x86_64) mkdir -pv /lib64 ;;
	esac

	mkdir -pv /var/{log,mail,spool}
	ln -sv /run /var/run || true
	ln -sv /run/lock /var/lock || true
	mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

	# Chapter 6.6
	ln -sv /tools/bin/{bash,cat,echo,pwd,stty} /bin || true
	ln -sv /tools/bin/perl /usr/bin || true
	ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib || true
	ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib || true
	sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la
	ln -sv bash /bin/sh || true
	ln -sv /proc/self/mounts /etc/mtab || true
	cat > /etc/passwd << EOF
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
	cat > /etc/group << EOF
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
systemd-journal:x:23:
input:x:24:
mail:x:34:
nogroup:x:99:
users:x:999:
EOF

	touch /var/log/{btmp,lastlog,wtmp}
	chgrp -v utmp /var/log/lastlog
	chmod -v 664 /var/log/lastlog
	chmod -v 600 /var/log/btmp
	#exec /tools/bin/bash --login +h #TODO: done?
}

# PACKAGES
function install_linux() {
	# Chapter 6.7
	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	find dest/include \( -name .install -o -name ..install.cmd \) -delete
	cp -rv dest/include/* /usr/include
}

function install_man-pages() {
	# Chapter 6.8
	make install
}

function install_glibc() {
	# Chapter 6.9
	patch -Np1 -i ../glibc-2.25-fhs-1.patch || true

    case $(uname -m) in
        x86) ln -s ld-linux.so.2 /lib/ld-lsb.so.3 || true
             ;;
        x86_64) ln -s ../lib/ld-linux-x86-64.so.2 /lib64 || true
                ln -s ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3 || true
             ;;
    esac

	mkdir -pv build
	cd build
    ../configure --prefix=/usr                   \
                 --enable-kernel=2.6.32          \
                 --enable-obsolete-rpc           \
                 --enable-stack-protector=strong \
                 libc_cv_slibdir=/lib
	make
	test $MAKE_CHECK == 'true' && make check || true #yolo #TODO check non-posix errors
	touch /etc/ld.so.conf || true
	make install
	cp -v ../nscd/nscd.conf /etc/nscd.conf
	mkdir -pv /var/cache/nscd

	mkdir -pv /usr/lib/locale
	localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
	localedef -i de_DE -f ISO-8859-1 de_DE
	localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
	localedef -i de_DE -f UTF-8 de_DE.UTF-8
	localedef -i en_GB -f UTF-8 en_GB.UTF-8
	localedef -i en_HK -f ISO-8859-1 en_HK
	localedef -i en_PH -f ISO-8859-1 en_PH
	localedef -i en_US -f ISO-8859-1 en_US
	localedef -i en_US -f UTF-8 en_US.UTF-8
	localedef -i es_MX -f ISO-8859-1 es_MX
	localedef -i fa_IR -f UTF-8 fa_IR
	localedef -i fr_FR -f ISO-8859-1 fr_FR
	localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
	localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
	localedef -i it_IT -f ISO-8859-1 it_IT
	localedef -i it_IT -f UTF-8 it_IT.UTF-8
	localedef -i ja_JP -f EUC-JP ja_JP
	localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
	localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
	localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
	localedef -i zh_CN -f GB18030 zh_CN.GB18030

	cat > /etc/nsswitch.conf <<EOF
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

    tar -xf ../../tzdata2016j.tar.gz

    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}

    for tz in etcetera southamerica northamerica europe africa antarctica  \
                       asia australasia backward pacificnew systemv; do
        zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
        zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
    done

    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO
	cp -v /usr/share/zoneinfo/Europe/Paris /etc/localtime

	cat > /etc/ld.so.conf <<EOF
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

	cat >> /etc/ld.so.conf <<EOF
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
	mkdir -pv /etc/ld.so.conf.d
}

# STUFF
function adjust() {
	# Chapter 6.10
	mv -v /tools/bin/{ld,ld-old}
	mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
	mv -v /tools/bin/{ld-new,ld}
	ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

	gcc -dumpspecs | sed -e 's@/tools@@g'					\
		-e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
		-e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >		\
		`dirname $(gcc --print-libgcc-file-name)`/specs

	echo 'int main(){}' > dummy.c
	cc dummy.c -v -Wl,--verbose &> dummy.log
	readelf -l a.out | grep -q ': /lib'
	grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
	grep -B1 '^ /usr/include' dummy.log
	grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
	grep "/lib.*/libc.so.6 " dummy.log
	grep found dummy.log
	rm -v dummy.c a.out dummy.log
}

# YET ANOTHER PACKAGES SHIT LOAD OF FUNCTIONS
function install_zlib() {
	# Chapter 6.11
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mv -v /usr/lib/libz.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
}

function install_file() {
	# Chapter 6.12
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_binutils() {
	# Chapter 6.13
	expect -c "spawn ls" | grep "spawn ls"
	mkdir -pv build
	cd build
    ../configure --prefix=/usr       \
                 --enable-gold       \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --with-system-zlib
	make tooldir=/usr
	test $MAKE_CHECK == 'true' && make -k check || true #yolo #TODO
	make tooldir=/usr install
}

function install_gmp() {
	# Chapter 6.14
	./configure --prefix=/usr	 \
			--enable-cxx	 \
			--disable-static \
			--docdir=/usr/share/doc/gmp-6.1.2
	make
	make html
    if [ $MAKE_CHECK == 'true' ]; then
	    make check 2>&1 | tee gmp-check-log
	    awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
    fi
	make install
	make install-html
}

function install_mpfr() {
	# Chapter 6.15
	./configure --prefix=/usr		 \
			--disable-static	 \
			--enable-thread-safe \
			--docdir=/usr/share/doc/mpfr-3.1.5
	make
	make html
	test $MAKE_CHECK == 'true' && make check
	make install
	make install-html
}

function install_mpc() {
	# Chapter 6.16
	./configure --prefix=/usr	 \
			--disable-static \
			--docdir=/usr/share/doc/mpc-1.0.3
	make
	make html
	test $MAKE_CHECK == 'true' && make check
	make install
	make install-html

}

function install_gcc() {
	# Chapter 6.17
    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' \
                -i.orig gcc/config/i386/t-linux64
            ;;
    esac
	mkdir -pv build
	cd build
	SED=sed								  \
		../configure --prefix=/usr			  \
		--enable-languages=c,c++ \
		--disable-multilib		 \
		--disable-bootstrap		 \
		--with-system-zlib
	make
	ulimit -s 32768
    if [ $MAKE_CHECK == 'true' ]; then
	    make -k check || true #yolo #TODO
	    ../contrib/test_summary
    fi
	make install
	ln -sv ../usr/bin/cpp /lib
	ln -sv gcc /usr/bin/cc
	install -v -dm755 /usr/lib/bfd-plugins
	ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/6.3.0/liblto_plugin.so \
		/usr/lib/bfd-plugins/
	echo 'int main(){}' > dummy.c
	cc dummy.c -v -Wl,--verbose &> dummy.log
	readelf -l a.out | grep -q ': /lib'
	grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
	grep -B4 '^ /usr/include' dummy.log
	grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
	grep "/lib.*/libc.so.6 " dummy.log
	grep found dummy.log
	rm -v dummy.c a.out dummy.log
	mkdir -pv /usr/share/gdb/auto-load/usr/lib
	mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
}

function install_bzip2() {
	# Chapter 6.18
	patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
	sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
	sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
	make -f Makefile-libbz2_so
	make clean
	make
	make PREFIX=/usr install
	cp -v bzip2-shared /bin/bzip2
	cp -av libbz2.so* /lib
	ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
	rm -v /usr/bin/{bunzip2,bzcat,bzip2}
	ln -sv bzip2 /bin/bunzip2
	ln -sv bzip2 /bin/bzcat
}

function install_pkg-config() {
	# Chapter 6.19
    ./configure --prefix=/usr              \
                --with-internal-glib       \
                --disable-compile-warnings \
                --disable-host-tool        \
                --docdir=/usr/share/doc/pkg-config-0.29.1
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_ncurses() {
	# Chapter 6.20
	sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
	./configure --prefix=/usr			\
			--mandir=/usr/share/man \
			--with-shared			\
			--without-debug			\
			--without-normal		\
			--enable-pc-files		\
			--enable-widec
	make
	make install
	mv -v /usr/lib/libncursesw.so.6* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
	for lib in ncurses form panel menu ; do
		rm -vf					  /usr/lib/lib${lib}.so
		echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
		ln -sfv ${lib}w.pc		  /usr/lib/pkgconfig/${lib}.pc
	done
	rm -vf					   /usr/lib/libcursesw.so
	echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
	ln -sfv libncurses.so	   /usr/lib/libcurses.so
	mkdir -pv	   /usr/share/doc/ncurses-6.0
	cp -v -R doc/* /usr/share/doc/ncurses-6.0
}

function install_attr() {
	# Chapter 6.21
	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i -e "/SUBDIRS/s|man[25]||g" man/Makefile
	./configure --prefix=/usr \
			--bindir=/bin \
			--disable-static
	make
	make -j1 tests root-tests
	make install install-dev install-lib
	chmod -v 755 /usr/lib/libattr.so
	mv -v /usr/lib/libattr.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
}

function install_acl() {
	# Chapter 6.22
	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i "s:| sed.*::g" test/{sbits-restore,cp,misc}.test
	sed -i -e "/TABS-1;/a if (x > (TABS-1)) x = (TABS-1);" \
		libacl/__acl_to_any_text.c
	./configure --prefix=/usr	 \
			--bindir=/bin	 \
			--disable-static \
			--libexecdir=/usr/lib
	make
	make install install-dev install-lib
	chmod -v 755 /usr/lib/libacl.so
	mv -v /usr/lib/libacl.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
}

function install_libcap() {
	# Chapter 6.23
	sed -i '/install.*STALIBNAME/d' libcap/Makefile
	make
	make RAISE_SETFCAP=no prefix=/usr install
	chmod -v 755 /usr/lib/libcap.so
	mv -v /usr/lib/libcap.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
}

function install_sed() {
	# Chapter 6.24
    sed -i 's/usr/tools/'       build-aux/help2man
    sed -i 's/panic-tests.sh//' Makefile.in
	./configure --prefix=/usr --bindir=/bin
	make
	make html
	test $MAKE_CHECK == 'true' && make check || true #yolo #TODO
	make install
    install -d -m755           /usr/share/doc/sed-4.4
    install -m644 doc/sed.html /usr/share/doc/sed-4.4
}

function install_shadow() {
	# Chapter 6.25
	sed -i 's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i 's/groups\.1 / /'	{} \;
	find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
	find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'	{} \;
	sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
		-e 's@/var/spool/mail@/var/mail@' etc/login.defs

    echo '--- src/useradd.c   (old)
+++ src/useradd.c   (new)
@@ -2027,6 +2027,8 @@
        is_shadow_grp = sgr_file_present ();
 #endif

+       get_defaults ();
+
        process_flags (argc, argv);

 #ifdef ENABLE_SUBIDS
@@ -2036,8 +2038,6 @@
            (!user_id || (user_id <= uid_max && user_id >= uid_min));
 #endif                         /* ENABLE_SUBIDS */

-       get_defaults ();
-
 #ifdef ACCT_TOOLS_SETUID
 #ifdef USE_PAM
        {' | patch -p0 -l

    sed -i 's/1000/999/' etc/useradd
	./configure --sysconfdir=/etc --with-group-name-max-length=32
	make
	make install
	mv -v /usr/bin/passwd /bin
	pwconv
	grpconv
	# passwd root
    echo "root:root" | chpasswd
}

function install_psmisc() {
	# Chapter 6.26
	./configure --prefix=/usr
	make
	make install
	mv -v /usr/bin/fuser   /bin
	mv -v /usr/bin/killall /bin
}

function install_iana() {
	# Chapter 6.27
	make
	make install
}

function install_m4() {
	# Chapter 6.28
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_bison() {
	# Chapter 6.29
	./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.4
	make
	make install
}

function install_flex() {
	# Chapter 6.30
    HELP2MAN=/tools/bin/true \
	        ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.3
	make
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
	ln -sv flex /usr/bin/lex
}

function install_grep() {
	# Chapter 6.31
	./configure --prefix=/usr --bindir=/bin
	make
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
}

function install_readline() {
	# Chapter 6.32
	sed -i '/MV.*old/d' Makefile.in
	sed -i '/{OLDSUFF}/c:' support/shlib-install
	./configure --prefix=/usr	 \
		--disable-static \
		--docdir=/usr/share/doc/readline-7.0
	make SHLIB_LIBS=-lncurses
	make SHLIB_LIBS=-lncurses install
	mv -v /usr/lib/lib{readline,history}.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
	ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
	install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-7.0
}

function install_bash() {
	# Chapter 6.33
    patch -Np1 -i ../bash-4.4-upstream_fixes-1.patch
	./configure --prefix=/usr                       \
                --docdir=/usr/share/doc/bash-4.4 \
                --without-bash-malloc               \
                            --with-installed-readline
	make
	chown -Rv nobody .
	test $MAKE_CHECK == 'true' && su nobody -s /bin/bash -c "PATH=$PATH make tests"
	make install
	mv -vf /usr/bin/bash /bin
	# (exec /bin/bash --login +h -c ls) #TODO: done?
}

function install_bc() {
	# Chapter 6.34
	patch -Np1 -i ../bc-1.06.95-memory_leak-1.patch
	./configure --prefix=/usr			\
			--with-readline			\
			--mandir=/usr/share/man \
			--infodir=/usr/share/info
	make
	echo "quit" | ./bc/bc -l Test/checklib.b
	make install
}

function install_libtool() {
	# Chapter 6.35
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
}

function install_gdbm() {
	# Chapter 6.36
	./configure --prefix=/usr \
			--disable-static \
			--enable-libgdbm-compat
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_gperf() {
	# Chapter 6.37
	./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.0.4
	make
	test $MAKE_CHECK == 'true' && make -j1 check
	make install
}

function install_expat() {
	# Chapter 6.38
	./configure --prefix=/usr --disable-static
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	install -v -dm755 /usr/share/doc/expat-2.2.0
	install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.0
}

function install_inetutils() {
	# Chapter 6.39
	./configure --prefix=/usr		 \
			--localstatedir=/var \
			--disable-logger	 \
			--disable-whois		 \
			--disable-rcp		 \
			--disable-rexec		 \
			--disable-rlogin	 \
			--disable-rsh		 \
			--disable-servers
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
	mv -v /usr/bin/ifconfig /sbin
}

function install_perl() {
	# Chapter 6.40
	echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
	export BUILD_ZLIB=False
	export BUILD_BZIP2=0
	sh Configure -des -Dprefix=/usr					\
		-Dvendorprefix=/usr			  \
		-Dman1dir=/usr/share/man/man1 \
		-Dman3dir=/usr/share/man/man3 \
		-Dpager="/usr/bin/less -isR"  \
		-Duseshrplib
	make
	# make -k test #TODO
	make install
	unset BUILD_ZLIB BUILD_BZIP2
}

function install_XML() {
	# Chapter 6.41
	perl Makefile.PL
	make
	test $MAKE_CHECK == 'true' && make test
	make install
}

function install_intltool() {
	# Chapter 6.42
	sed -i 's:\\\${:\\\$\\{:' intltool-update.in
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
}

function install_autoconf() {
	# Chapter 6.43
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
}

function install_automake() {
	# Chapter 6.44
	sed -i 's:/\\\${:/\\\$\\{:' bin/automake.in
	./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.15
	make
	sed -i "s:./configure:LEXLIB=/usr/lib/libfl.a &:" t/lex-{clean,depend}-cxx.sh
	test $MAKE_CHECK == 'true' && make -j4 check || true #TODO
	make install
}

function install_xz() {
	# Chapter 6.45
	./configure --prefix=/usr	 \
		--disable-static \
		--docdir=/usr/share/doc/xz-5.2.3
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mv -v	/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
	mv -v /usr/lib/liblzma.so.* /lib
	ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
}

function install_kmod() {
	# Chapter 6.46
	./configure --prefix=/usr		   \
			--bindir=/bin		   \
			--sysconfdir=/etc	   \
			--with-rootlibdir=/lib \
			--with-xz			   \
			--with-zlib
	make
	make install
	for target in depmod insmod lsmod modinfo modprobe rmmod; do
		ln -sv ../bin/kmod /sbin/$target
	done
	ln -sv kmod /bin/lsmod
}

function install_gettext() {
	# Chapter 6.47
    sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
        sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in

	./configure --prefix=/usr	 \
		--disable-static \
		--docdir=/usr/share/doc/gettext-0.19.8.1
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	chmod -v 0755 /usr/lib/preloadable_libintl.so
}

function install_procps-ng() {
	# Chapter 6.48
	./configure --prefix=/usr							 \
			--exec-prefix=							 \
			--libdir=/usr/lib						 \
			--docdir=/usr/share/doc/procps-ng-3.3.12 \
			--disable-static						 \
			--disable-kill
	make
	sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
	mv -v /usr/lib/libprocps.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
}

function install_e2fsprogs() {
	# Chapter 6.49
	mkdir -pv build
	cd build
	LIBS=-L/tools/lib					 \
		CFLAGS=-I/tools/include				 \
		PKG_CONFIG_PATH=/tools/lib/pkgconfig \
		../configure --prefix=/usr			 \
		--bindir=/bin			\
		--with-root-prefix=""	\
		--enable-elf-shlibs		\
		--disable-libblkid		\
		--disable-libuuid		\
		--disable-uuidd			\
		--disable-fsck
	make
	ln -sfv /tools/lib/lib{blk,uu}id.so.1 lib
	test $MAKE_CHECK == 'true' && make LD_LIBRARY_PATH=/tools/lib check
	make install
	make install-libs
	chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
	gunzip -v /usr/share/info/libext2fs.info.gz
	install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
	makeinfo -o		 doc/com_err.info ../lib/et/com_err.texinfo
	install -v -m644 doc/com_err.info /usr/share/info
	install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
}

function install_coreutils() {
	# Chapter 6.50
    patch -Np1 -i ../coreutils-8.26-i18n-1.patch
    sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
	FORCE_UNSAFE_CONFIGURE=1 ./configure \
		--prefix=/usr			 \
		--enable-no-install-program=kill,uptime
	FORCE_UNSAFE_CONFIGURE=1 make
	make NON_ROOT_USERNAME=nobody check-root
	echo "dummy:x:1000:nobody" >> /etc/group
	chown -Rv nobody .
	test $MAKE_CHECK =='true' && su nobody -s /bin/bash \
		-c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
	sed -i '/dummy/d' /etc/group
	make install
	mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
	mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
	mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
	mv -v /usr/bin/chroot /usr/sbin
	mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
	sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
	mv -v /usr/bin/{head,sleep,nice,test,[} /bin
}

function install_diffutils() {
	# Chapter 6.51
	sed -i 's:= @mkdir_p@:= /bin/mkdir -p:' po/Makefile.in.in
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_gawk() {
	# Chapter 6.52
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mkdir -pv /usr/share/doc/gawk-4.1.4
	cp	  -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.1.4
}

function install_findutils() {
	# Chapter 6.53
    sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in
	./configure --prefix=/usr --localstatedir=/var/lib/locate
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mv -v /usr/bin/find /bin
	sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
}

function install_groff() {
	# Chapter 6.54
	PAGE=A4 ./configure --prefix=/usr
    export MAKEFLAGS='-j 1'
	make
	make install
    export MAKEFLAGS='-j 4'
}

function install_grub() {
	# Chapter 6.55
	./configure --prefix=/usr		   \
			--sbindir=/sbin		   \
			--sysconfdir=/etc	   \
			--disable-efiemu	   \
			--disable-werror
	make
	make install
}

function install_less() {
	# Chapter 6.56
	./configure --prefix=/usr --sysconfdir=/etc
	make
	make install
}

function install_gzip() {
	# Chapter 6.57
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
    mv -v /usr/bin/gzip /bin
}

function install_iproute() {
	# Chapter 6.58
	sed -i /ARPD/d Makefile
	sed -i 's/arpd.8//' man/man8/Makefile
	rm -v doc/arpd.sgml
    sed -i 's/m_ipt.o//' tc/Makefile
	make
	make DOCDIR=/usr/share/doc/iproute2-4.9.0 install
}

function install_kbd() {
	# Chapter 6.59
	patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
	sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
	sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
	PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	mkdir -pv /usr/share/doc/kbd-2.0.4
	cp -R -v docs/doc/* /usr/share/doc/kbd-2.0.4
}

function install_libpipeline() {
	# Chapter 6.60
	PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_make() {
	# Chapter 6.61
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check || true #TODO
	make install
}

function install_patch() {
	# Chapter 6.62
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_sysklogd() {
	# Chapter 6.63
	sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
    sed -i 's/union wait/int/' syslogd.c
	make
	make BINDIR=/sbin install
cat > /etc/syslog.conf << EOF
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
}

function install_sysvinit() {
	# Chapter 6.64
	patch -Np1 -i ../sysvinit-2.88dsf-consolidated-1.patch
	make -C src
	make -C src install
}


function install_eudev() {
	# Chapter 6.65
	sed -r -i 's|/usr(/bin/test)|\1|' test/udev-test.pl
    sed -i '/keyboard_lookup_key/d' src/udev/udev-builtin-keyboard.c
	cat > config.cache << EOF
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF
	./configure --prefix=/usr			\
		--bindir=/sbin			\
		--sbindir=/sbin			\
		--libdir=/usr/lib		\
		--sysconfdir=/etc		\
		--libexecdir=/lib		\
		--with-rootprefix=		\
		--with-rootlibdir=/lib	\
		--enable-manpages		\
		--disable-static		\
		--config-cache
	LIBRARY_PATH=/tools/lib make
	mkdir -pv /lib/udev/rules.d
	mkdir -pv /etc/udev/rules.d
	test $MAKE_CHECK == 'true' && make LD_LIBRARY_PATH=/tools/lib check
	make LD_LIBRARY_PATH=/tools/lib install
	tar -xvf ../udev-lfs-20140408.tar.bz2
	make -f udev-lfs-20140408/Makefile.lfs install
	LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update
}

function install_util-linux() {
	# Chapter 6.66
	mkdir -pv /var/lib/hwclock
	./configure ADJTIME_PATH=/var/lib/hwclock/adjtime	\
			--docdir=/usr/share/doc/util-linux-2.29.1 \
			--disable-chfn-chsh	 \
			--disable-login		 \
			--disable-nologin	 \
			--disable-su		 \
			--disable-setpriv	 \
			--disable-runuser	 \
			--disable-pylibmount \
			--disable-static	 \
			--without-python	 \
			--without-systemd	 \
			--without-systemdsystemunitdir
	make
	chown -Rv nobody .
	test $MAKE_CHECK == 'true' && su nobody -s /bin/bash -c "PATH=$PATH make -k check"
	make install
}

function install_man-db() {
	# Chapter 6.67
    ./configure --prefix=/usr                        \
                --docdir=/usr/share/doc/man-db-2.7.6.1 \
                --sysconfdir=/etc                    \
                --disable-setuid                     \
                --enable-cache-owner=bin             \
                --with-browser=/usr/bin/lynx         \
                --with-vgrind=/usr/bin/vgrind        \
                --with-grap=/usr/bin/grap            \
                --with-systemdtmpfilesdir=
	make
	test $MAKE_CHECK == 'true' && make check
	make install
}

function install_tar() {
	# Chapter 6.68
	FORCE_UNSAFE_CONFIGURE=1  \
		./configure --prefix=/usr \
		--bindir=/bin
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	make -C doc install-html docdir=/usr/share/doc/tar-1.29
}

function install_texinfo() {
	# Chapter 6.69
	./configure --prefix=/usr --disable-static
	make
	test $MAKE_CHECK == 'true' && make check
	make install
	make TEXMF=/usr/share/texmf install-tex
	pushd /usr/share/info
	rm -v dir
	for f in *;	do
		install-info $f dir 2>/dev/null
	done
	popd
}

function install_vim() {
	# Chapter 6.70
	echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
	./configure --prefix=/usr
	make
	test $MAKE_CHECK == 'true' && make -j1 test
	make install
	ln -sv vim /usr/bin/vi
	for L in  /usr/share/man/{,*/}man1/vim.1; do
		ln -sv vim.1 $(dirname $L)/vi.1
	done
    ln -sv ../vim/vim80/doc /usr/share/doc/vim-8.0.069
	cat > /etc/vimrc << EOF
" Begin /etc/vimrc

set nocompatible
set backspace=2
syntax on
if (&term == "iterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
}

function strip_and_clean() {
    # Chapter 6.72
    /tools/bin/find /usr/lib -type f -name \*.a \
                    -exec /tools/bin/strip --strip-debug {} ';'

    /tools/bin/find /lib /usr/lib -type f -name \*.so* \
                    -exec /tools/bin/strip --strip-unneeded {} ';'

    /tools/bin/find /{bin,sbin} /usr/{bin,sbin,libexec} -type f \
                    -exec /tools/bin/strip --strip-all {} ';'

    rm -rf /tmp/*

    rm -f /usr/lib/lib{bfd,opcodes}.a
    rm -f /usr/lib/libbz2.a
    rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
    rm -f /usr/lib/libltdl.a
    rm -f /usr/lib/libfl.a
    rm -f /usr/lib/libfl_pic.a
    rm -f /usr/lib/libz.a

}

PACKAGES1='linux
man-pages
glibc'

PACKAGES2='zlib
file
binutils
gmp
mpfr
mpc
gcc
bzip2
pkg-config
ncurses
attr
acl
libcap
sed
shadow
psmisc
iana
m4
bison
flex
grep
readline
bash'


PACKAGES3='bc
libtool
gdbm
gperf
expat
inetutils
perl
XML
intltool
autoconf
automake
xz
kmod
gettext
procps-ng
e2fsprogs
coreutils
diffutils
gawk
findutils
groff
grub
less
gzip
iproute
kbd
libpipeline
make
patch
sysklogd
sysvinit
eudev
util-linux
man-db
tar
texinfo
vim'

declare -A SBU

SBU["linux"]=100000
SBU["man-pages"]=100000
SBU["glibc"]=20000000
SBU["zlib"]=100000
SBU["file"]=100000
SBU["binutils"]=5700000
SBU["gmp"]=1300000
SBU["mpfr"]=800000
SBU["mpc"]=300000
SBU["gcc"]=82000000
SBU["bzip2"]=100000
SBU["pkg-config"]=400000
SBU["ncurses"]=400000
SBU["attr"]=100000
SBU["acl"]=100000
SBU["libcap"]=100000
SBU["sed"]=300000
SBU["shadow"]=200000
SBU["psmisc"]=100000
SBU["iana"]=100000
SBU["m4"]=400000
SBU["bison"]=300000
SBU["flex"]=400000
SBU["grep"]=400000
SBU["readline"]=100000
SBU["bash"]=1700000
SBU["bc"]=100000
SBU["libtool"]=2000000
SBU["gdbm"]=100000
SBU["gperf"]=100000
SBU["expat"]=100000
SBU["inetutils"]=400000
SBU["perl"]=5900000
SBU["XML"]=100000
SBU["intltool"]=100000
SBU["autoconf"]=3500000
SBU["automake"]=7500000
SBU["xz"]=200000
SBU["kmod"]=100000
SBU["gettext"]=2900000
SBU["procps-ng"]=100000
SBU["e2fsprogs"]=4100000
SBU["coreutils"]=3100000
SBU["diffutils"]=400000
SBU["gawk"]=300000
SBU["findutils"]=900000
SBU["groff"]=500000
SBU["grub"]=800000
SBU["less"]=100000
SBU["gzip"]=100000
SBU["iproute"]=200000
SBU["kbd"]=100000
SBU["libpipeline"]=100000
SBU["make"]=500000
SBU["patch"]=200000
SBU["sysklogd"]=100000
SBU["sysvinit"]=100000
SBU["eudev"]=200000
SBU["util-linux"]=1000000
SBU["man-db"]=400000
SBU["tar"]=3200000
SBU["texinfo"]=500000
SBU["vim"]=1300000

SBU_TOTAL=157100000
SBU_PER_SECOND=10000
SBU_DONE=0

todo=create_dir_n_links
log="$LOG_FOLDER/build-$todo.log"

if [ -f "$log" ]; then
	success "$todo already done!"
elif [ "$1" == "--init" ]; then
    echo "Executing: $todo"
    set -x
	$todo &> "$log.tmp"
    test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
    set +x
	mv "$log.tmp" "$log"
fi


for todo in $PACKAGES1; do
	log="$LOG_FOLDER/build-$todo.log"
	if [ -f "$log" ]; then
		success "$todo already done!"

	    SBU_TOTAL=$(("$SBU_TOTAL - ${SBU[$todo]}"))
    elif [ "$1" == "--part1" ]; then
        echo -e "Installing package: $todo\t\t@$(date +"%H:%M:%S")"
        echo "µSBU: ${SBU[$todo]} ($((${SBU[$todo]} * 100 / $SBU_TOTAL))%)"
        echo "progress: $SBU_DONE / $SBU_TOTAL µSBU at $SBU_PER_SECOND µSBU/s ($(($SBU_DONE * 100 / $SBU_TOTAL))%)"
        ETA_PACKAGE=$(("${SBU[$todo]} / $SBU_PER_SECOND"))
        ETA_TOTAL=$(("($SBU_TOTAL - $SBU_DONE) / $SBU_PER_SECOND"))
        echo -e "eta package: $(date -u -d "0 $ETA_PACKAGE seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_PACKAGE seconds" +"%H:%M:%S")"
        echo -e "eta total: $(date -u -d "0 $ETA_TOTAL seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_TOTAL seconds" +"%H:%M:%S")"

	    before $todo &> "$log.tmp"
		install_$todo &>> "$log.tmp"
        test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
		after $todo &>> "$log.tmp"
		mv "$log.tmp" "$log"

        SBU_DONE=$(("$SBU_DONE + ${SBU[$todo]}"))
        SBU_PER_SECOND=$(("$SBU_DONE / $SECONDS"))
	fi
done

todo=adjust
log="$LOG_FOLDER/build-$todo.log"
if [ -f "$log" ]; then
	success "$todo already done!"
elif [ "$1" == "--part1" ]; then
    echo "Executing: $todo"
    set -x
	$todo &> "$log.tmp"
    test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
    set +x
	mv "$log.tmp" "$log"
fi

for todo in $PACKAGES2; do
	log="$LOG_FOLDER/build-$todo.log"
	if [ -f "$log" ]; then
		success "$todo already done!"

	    SBU_TOTAL=$(("$SBU_TOTAL - ${SBU[$todo]}"))
    elif [ "$1" == "--part1" ]; then
        echo -e "Installing package: $todo\t\t@$(date +"%H:%M:%S")"
        echo "µSBU: ${SBU[$todo]} ($((${SBU[$todo]} * 100 / $SBU_TOTAL))%)"
        echo "progress: $SBU_DONE / $SBU_TOTAL µSBU at $SBU_PER_SECOND µSBU/s ($(($SBU_DONE * 100 / $SBU_TOTAL))%)"
        ETA_PACKAGE=$(("${SBU[$todo]} / $SBU_PER_SECOND"))
        ETA_TOTAL=$(("($SBU_TOTAL - $SBU_DONE) / $SBU_PER_SECOND"))
        echo -e "eta package: $(date -u -d "0 $ETA_PACKAGE seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_PACKAGE seconds" +"%H:%M:%S")"
        echo -e "eta total: $(date -u -d "0 $ETA_TOTAL seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_TOTAL seconds" +"%H:%M:%S")"

	    before $todo &> "$log.tmp"
		install_$todo &>> "$log.tmp"
        test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
		after $todo &>> "$log.tmp"
		mv "$log.tmp" "$log"

        SBU_DONE=$(("$SBU_DONE + ${SBU[$todo]}"))
        SBU_PER_SECOND=$(("$SBU_DONE / $SECONDS"))
	fi
done


for todo in $PACKAGES3; do
	log="$LOG_FOLDER/build-$todo.log"
	if [ -f "$log" ]; then
		success "$todo already done!"

	    SBU_TOTAL=$(("$SBU_TOTAL - ${SBU[$todo]}"))
    elif [ "$1" == "--part2" ]; then
        echo -e "Installing package: $todo\t\t@$(date +"%H:%M:%S")"
        echo "µSBU: ${SBU[$todo]} ($((${SBU[$todo]} * 100 / $SBU_TOTAL))%)"
        echo "progress: $SBU_DONE / $SBU_TOTAL µSBU at $SBU_PER_SECOND µSBU/s ($(($SBU_DONE * 100 / $SBU_TOTAL))%)"
        ETA_PACKAGE=$(("${SBU[$todo]} / $SBU_PER_SECOND"))
        ETA_TOTAL=$(("($SBU_TOTAL - $SBU_DONE) / $SBU_PER_SECOND"))
        echo -e "eta package: $(date -u -d "0 $ETA_PACKAGE seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_PACKAGE seconds" +"%H:%M:%S")"
        echo -e "eta total: $(date -u -d "0 $ETA_TOTAL seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_TOTAL seconds" +"%H:%M:%S")"

	    before $todo &> "$log.tmp"
		install_$todo &>> "$log.tmp"
        test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
		after $todo &>> "$log.tmp"
		mv "$log.tmp" "$log"

        SBU_DONE=$(("$SBU_DONE + ${SBU[$todo]}"))
        SBU_PER_SECOND=$(("$SBU_DONE / $SECONDS"))
	fi
done


todo=strip_and_clean
log="$LOG_FOLDER/build-$todo.log"
if [ -f "$log" ]; then
	success "$todo already done!"
elif [ "$1" == "--clean" ]; then
    echo "Executing: $todo"
    set -x
	$todo &> "$log.tmp"
    test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
    set +x
	mv "$log.tmp" "$log"
fi

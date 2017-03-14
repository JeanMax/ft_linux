#!/bin/bash
set -e

export LFS='/mnt/lfs'
export MAKEFLAGS='-j 4'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FOLDER="$HERE/log"

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
	# Chapter 5.3
    set -x
	cd $LFS/sources
	tar --skip-old-files -xvf $(ls $1*tar*)
	cd $(ls -d */)
}

function after() {
	# Chapter 5.3
	cd $LFS/sources
	rm -rf $(ls -d */)
    set +x
}

# PACKAGES
function install_binutils() {
	# Chapter 5.4
	mkdir -pv build
	cd build
	../configure \
		--prefix=/tools				 \
		--with-sysroot=$LFS			 \
		--with-lib-path=/tools/lib	 \
		--target=$LFS_TGT			 \
		--disable-nls				 \
		--disable-werror
	make
	case $(uname -m) in
		x86_64) mkdir -pv /tools/lib && ln -sv lib /tools/lib64 ;;
	esac
	make install
}

function install_gc() {
	# Chapter 5.5
	for BIN in mpfr gmp mpc; do
		rm -rfv $BIN
		tar --skip-old-files -xvf $(ls ../$BIN*tar*)
		mv -v $(ls -d $BIN*/) $BIN
	done

	for file in gcc/config/{linux,i386/linux{,64}}.h; do
		cp -uv $file{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' $file.orig > $file
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done

	case $(uname -m) in
		x86_64)
			sed -e '/m64=/s/lib64/lib/' \
				-i.orig gcc/config/i386/t-linux64
			;;
	esac

    mkdir -pv build
	cd build
	../configure			\
		--target=$LFS_TGT							   \
		--prefix=/tools								   \
		--with-glibc-version=2.11					   \
		--with-sysroot=$LFS							   \
		--with-newlib								   \
		--without-headers							   \
		--with-local-prefix=/tools					   \
		--with-native-system-header-dir=/tools/include \
		--disable-nls								   \
		--disable-shared							   \
		--disable-multilib							   \
		--disable-decimal-float						   \
		--disable-threads							   \
		--disable-libatomic							   \
		--disable-libgomp							   \
		--disable-libmpx							   \
		--disable-libquadmath						   \
		--disable-libssp							   \
		--disable-libvtv							   \
		--disable-libstdcxx							   \
		--enable-languages=c,c++
	make
	make install
}

function install_linux() {
	# Chapter 5.6
	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	cp -rv dest/include/* /tools/include
}

function install_glibc() {
	# Chapter 5.7
	mkdir -pv build
	cd	build
	../configure							 \
	  --prefix=/tools					 \
	  --host=$LFS_TGT					 \
	  --build=$(../scripts/config.guess) \
	  --enable-kernel=2.6.32			 \
	  --with-headers=/tools/include		 \
	  libc_cv_forced_unwind=yes			 \
	  libc_cv_c_cleanup=yes
	make
	make install

	echo 'int main(){}' > dummy.c
	$LFS_TGT-gcc dummy.c
	readelf -l a.out | grep -q ': /tools'
	rm -v dummy.c a.out
}

function install_gcc() {
	# Chapter 5.8
	mkdir -pv build
	cd build
	../libstdc++-v3/configure			\
	--host=$LFS_TGT					\
	--prefix=/tools					\
	--disable-multilib				\
	--disable-nls					\
	--disable-libstdcxx-threads		\
	--disable-libstdcxx-pch			\
	--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/6.3.0
	make
	make install
}

function install_binutils-() {
	# Chapter 5.9
	mkdir -pv build
	cd build
	CC=$LFS_TGT-gcc				   \
	AR=$LFS_TGT-ar				   \
	RANLIB=$LFS_TGT-ranlib		   \
	../configure				   \
		--prefix=/tools			   \
		--disable-nls			   \
		--disable-werror		   \
		--with-lib-path=/tools/lib \
		--with-sysroot
	make
	make install
	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib
	cp -v ld/ld-new /tools/bin
}

function install_gcc-() {
	# Chapter 5.10
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

	for file in gcc/config/{linux,i386/linux{,64}}.h
	do
		cp -uv $file{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' $file.orig > $file
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done

	case $(uname -m) in
		x86_64)
			sed -e '/m64=/s/lib64/lib/' \
				-i.orig gcc/config/i386/t-linux64
			;;
	esac

	for BIN in mpfr gmp mpc; do
		rm -rfv $BIN
		tar --skip-old-files -xvf $(ls ../$BIN*tar*)
		mv -v $(ls -d $BIN*/) $BIN
	done

    mkdir -pv build
	cd build
	CC=$LFS_TGT-gcc									   \
	CXX=$LFS_TGT-g++								   \
	AR=$LFS_TGT-ar									   \
	RANLIB=$LFS_TGT-ranlib							   \
	../configure									   \
		--prefix=/tools								   \
		--with-local-prefix=/tools					   \
		--with-native-system-header-dir=/tools/include \
		--enable-languages=c,c++					   \
		--disable-libstdcxx-pch						   \
		--disable-multilib							   \
		--disable-bootstrap							   \
		--disable-libgomp

	make
	make install
	ln -sv gcc /tools/bin/cc

	echo 'int main(){}' > dummy.c
	cc dummy.c
	readelf -l a.out | grep -q ': /tools'
	rm -v dummy.c a.out
}

function install_tcl-core() {
	# Chapter 5.11
	cd unix
	./configure --prefix=/tools
	make
	make install
	chmod -v u+w /tools/lib/libtcl8.6.so
	make install-private-headers
	ln -sv tclsh8.6 /tools/bin/tclsh
}

function install_expect() {
	# Chapter 5.12
	cp -v configure{,.orig}
	sed 's:/usr/local/bin:/bin:' configure.orig > configure
	./configure --prefix=/tools		  \
		--with-tcl=/tools/lib \
		--with-tclinclude=/tools/include
	make
	make SCRIPTS="" install
}

function install_dejagnu() {
	# Chapter 5.13
	./configure --prefix=/tools
	make install
}

function install_check() {
	# Chapter 5.14
	PKG_CONFIG= ./configure --prefix=/tools
	make
	make install
}

function install_ncurses() {
	# Chapter 5.15
	sed -i s/mawk// configure
	./configure --prefix=/tools \
		--with-shared	\
		--without-debug \
		--without-ada	\
		--enable-widec	\
		--enable-overwrite
	make
	make install
}

function install_bash() {
	# Chapter 5.16
	./configure --prefix=/tools --without-bash-malloc
	make
	make install
	ln -sv bash /tools/bin/sh
}

function install_bison() {
	# Chapter 5.17
	./configure --prefix=/tools
	make
	make install
}

function install_bzip2() {
	# Chapter 5.18
	make
	make PREFIX=/tools install
}

function install_coreutils() {
	# Chapter 5.19
	./configure --prefix=/tools --enable-install-program=hostname
	make
	make install
}

function install_diffutils() {
	# Chapter 5.20
	./configure --prefix=/tools
	make
	make install
}

function install_file() {
	# Chapter 5.21
	./configure --prefix=/tools
	make
	make install
}

function install_findutils() {
	# Chapter 5.22
	./configure --prefix=/tools
	make
	make install
}

function install_gawk() {
	# Chapter 5.23
	./configure --prefix=/tools
	make
	make install
}

function install_gettext() {
	# Chapter 5.24
	cd gettext-tools
	EMACS="no" ./configure --prefix=/tools --disable-shared
	make -C gnulib-lib
	make -C intl pluralx.c
	make -C src msgfmt
	make -C src msgmerge
	make -C src xgettext
	cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
}

function install_grep() {
	# Chapter 5.25
	./configure --prefix=/tools
	make
	make install
}

function install_gzip() {
	# Chapter 5.26
	./configure --prefix=/tools
	make
	make install
}

function install_m4() {
	# Chapter 5.27
	./configure --prefix=/tools
	make
	make install
}

function install_make() {
	# Chapter 5.28
	./configure --prefix=/tools --without-guile
	make
	make install
}

function install_patch() {
	# Chapter 5.29
	./configure --prefix=/tools
	make
	make install
}

function install_perl() {
	# Chapter 5.30
	sh Configure -des -Dprefix=/tools -Dlibs=-lm
	make
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.24.1
    cp -Rv lib/* /tools/lib/perl5/5.24.1
}

function install_sed() {
	# Chapter 5.31
	./configure --prefix=/tools
	make
	make install
}

function install_tar() {
	# Chapter 5.32
	./configure --prefix=/tools
	make
	make install
}

function install_texinfo() {
	# Chapter 5.33
	./configure --prefix=/tools
	make
	make install
}

function install_util-linux() {
	# Chapter 5.34
	./configure --prefix=/tools				   \
		--without-python			   \
		--disable-makeinstall-chown	   \
		--without-systemdsystemunitdir \
		PKG_CONFIG=""
	make
	make install
}

function install_xz() {
	# Chapter 5.35
	./configure --prefix=/tools
	make
	make install
}


function stripping() {
	# Chapter 5.36
	strip --strip-debug /tools/lib/* || true
	/usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true
	rm -rf /tools/{,share}/{info,man,doc}
}


PACKAGES='binutils
gc
linux
glibc
gcc
binutils-
gcc-
tcl-core
expect
dejagnu
check
ncurses
bash
bison
bzip2
coreutils
diffutils
file
findutils
gawk
gettext
grep
gzip
m4
make
patch
perl
sed
tar
texinfo
util-linux
xz'

declare -A SBU

SBU["binutils"]=1
SBU["gc"]=8.4
SBU["linux"]=0.1
SBU["glibc"]=4.1
SBU["gcc"]=0.4
SBU["binutils-"]=1.1
SBU["gcc-"]=11
SBU["tcl-core"]=0.4
SBU["expect"]=0.1
SBU["dejagnu"]=0.1
SBU["check"]=0.1
SBU["ncurses"]=0.5
SBU["bash"]=0.4
SBU["bison"]=0.3
SBU["bzip2"]=0.1
SBU["coreutils"]=0.6
SBU["diffutils"]=0.2
SBU["file"]=0.1
SBU["findutils"]=0.3
SBU["gawk"]=0.2
SBU["gettext"]=0.9
SBU["grep"]=0.2
SBU["gzip"]=0.1
SBU["m4"]=0.2
SBU["make"]=0.1
SBU["patch"]=0.2
SBU["perl"]=1.3
SBU["sed"]=0.1
SBU["tar"]=0.3
SBU["texinfo"]=0.2
SBU["util-linux"]=0.9
SBU["xz"]=0.2

SBU_TOTAL_TEMP=34.2
SBU_TOTAL=191.3
SBU_PER_SECOND=0.01
SBU_DONE=0


for todo in $PACKAGES; do
    log="$LOG_FOLDER/temp_build-$todo.log"
	if [ -f "$log" ]; then
		success "$todo already done!"

	    SBU_TOTAL=$(echo "$SBU_TOTAL - ${SBU[$todo]}" | bc -l)
	    SBU_TOTAL_TEMP=$(echo "$SBU_TOTAL_TEMP - ${SBU[$todo]}" | bc -l)
    else
        echo -e "Installing package: $todo\t\t@$(date +"%H:%M:%S")"
        echo "SBU: ${SBU[$todo]} ($(echo "${SBU[$todo]} * 100 / $SBU_TOTAL" | bc -l)%)"
        echo "progress: $SBU_DONE / $SBU_TOTAL_TEMP SBU ($SBU_TOTAL total) at $SBU_PER_SECOND SBU/s ($(echo "$SBU_DONE * 100 / $SBU_TOTAL" | bc -l)%)"
        ETA_PACKAGE=$(echo "${SBU[$todo]} / $SBU_PER_SECOND" | bc)
        ETA_TEMP=$(echo "($SBU_TOTAL_TEMP - $SBU_DONE) / $SBU_PER_SECOND" | bc)
        ETA_TOTAL=$(echo "($SBU_TOTAL - $SBU_DONE) / $SBU_PER_SECOND" | bc)
        echo -e "eta package: $(date -u -d "0 $ETA_PACKAGE seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_PACKAGE seconds" +"%H:%M:%S")"
        echo -e "eta temp: $(date -u -d "0 $ETA_TEMP seconds" +"%H:%M:%S")\t\t@$(date -d "+ $ETA_TEMP seconds" +"%H:%M:%S")"
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

todo=stripping
log="$LOG_FOLDER/temp_build-$todo.log"
if [ -f "$log" ]; then
	success "$todo already done!"
else
    echo "Executing: $todo"
    set -x
	$todo &> "$log.tmp"
    test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
    set +x
	mv "$log.tmp" "$log"
fi

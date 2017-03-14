#!/bin/bash
set -e

#
# run this once your filesystem/partitions are made
# (and don't forget to edit mount.sh accordingly)
#

export LFS=/mnt/lfs

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FOLDER="$HERE/script"
LOG_FOLDER="$HERE/log"

GREEN="\033[32;01m"
RED="\033[31;01m"
NORMAL="\033[0m"

function error() {
	echo -e "\n$RED$1$NORMAL"
    test $2 && tail -n 25 "$2"
	exit 1
}

function success() {
	echo -e "$GREEN$1$NORMAL"
}


function host_requirements() {
    # Chapter 2.2
    sudo pacman -S bash binutils bison bzip2 coreutils diffutils findutils gawk gcc glibc grep gzip m4 make patch perl sed tar texinfo xz autoconf automake flex libtool

    sudo ln -s /bin/bash /bin/sh || true
    sudo ln -s /usr/bin/bison /usr/bin/yacc || true
    bash "$SCRIPT_FOLDER/version-check.sh" #TODO: automatize
    bash "$SCRIPT_FOLDER/library-check.sh" #TODO: automatize
}

function download_sources() {
    # Chapter 3.1
	sudo mkdir -pv $LFS/sources
	sudo chmod -v a+wt $LFS/sources
	wget --input-file=$SCRIPT_FOLDER/wget-list --continue --directory-prefix=$LFS/sources
	wget --input-file=$SCRIPT_FOLDER/wget-list-bonus --continue --directory-prefix=$LFS/sources
	wget --input-file=$SCRIPT_FOLDER/wget-list-X --continue --directory-prefix=$LFS/sources
}

function create_tools_dir() {
    # Chapter 4.2
	sudo mkdir -v $LFS/tools
	sudo ln -sv $LFS/tools /
}

function add_lfsuser() {
    # Chapter 4.3
	sudo groupadd lfs
	sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
	# sudo passwd lfs
    echo "lfs:lfs" | sudo chpasswd
	sudo chown -vR lfs:lfs $LFS/tools
	sudo chown -vR lfs:lfs $LFS/sources
	sudo chmod -v a+wt $LFS/sources
}

function init_lfsuser() {
    # Chapter 4.4
	sudo su - lfs << KTHXBYE
	cat > ~/.bash_profile << EOF
exec env -i HOME=/home/lfs TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
	cat > ~/.bashrc << EOF
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF
	source ~/.bash_profile
KTHXBYE
}

function temp_build() {
    # Chapter 5
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/temp_build.sh" $LFS/tools/build
    echo "source /home/lfs/.bashrc && $LFS/tools/build/temp_build.sh" | sudo su - lfs
    # "$SCRIPT_FOLDER/do_su.sh" "source /home/lfs/.bashrc && $SCRIPT_FOLDER/temp_build.sh"

    # Chapter 5.37
	sudo chown -R root:root $LFS/tools
}

function final_build-init() {
    # Chapter 6
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/build.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -1 "/tools/build/build.sh --init"
}

function final_build-part1() {
    # Chapter 6
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/build.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -1 "/tools/build/build.sh --part1"
}

function final_build-part2() {
    # Chapter 6
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/build.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -2 "/tools/build/build.sh --part2"
}

function final_build-clean() {
    # Chapter 6
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/build.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -3 "/tools/build/build.sh --clean"
}

function system_config() {
    # Chapter 7/8/9
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/system_config.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -4 "/tools/build/system_config.sh"
}

function moar_packages() {
    sudo mkdir -pv $LFS/tools/build/log
    sudo cp -v "$SCRIPT_FOLDER/moar_packages.sh" $LFS/tools/build
    sudo "$SCRIPT_FOLDER/do_chroot.sh" -4 "/tools/build/moar_packages.sh"
}



# be sure it's mounted every time...
bash "$SCRIPT_FOLDER/mount.sh" > "$LOG_FOLDER/mount.log" 2>&1 || true # Chapter 2.7

TODO_LIST="host_requirements
download_sources
create_tools_dir
add_lfsuser
init_lfsuser"

for todo in $TODO_LIST; do
    log="$LOG_FOLDER/$todo.log"
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
done


TODO_LIST="temp_build
final_build-init
final_build-part1
final_build-part2
final_build-clean
system_config
moar_packages"

for todo in $TODO_LIST; do
    log="$LOG_FOLDER/$todo.log"
    if [ -f "$log" ]; then
	    success "$todo already done!"
    else
        echo "Executing: $todo"
        echo "cf. specific log" > "$log.tmp"
        set -x
	    $todo
        test ${PIPESTATUS[0]} -eq 0 && success "$todo OK!" || error "$todo failed" "$log.tmp"
        set +x
		mv "$log.tmp" "$log"
    fi
done

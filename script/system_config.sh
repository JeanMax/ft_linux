set -e

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
    # set -x
	cd /sources
	tar --skip-old-files -xvf $(ls $1*tar*)
	cd $(ls -d $1*/)
}

function after() {
	cd /sources
	rm -rf $(ls -d $1*/)
    # set +x
}

# Chapter 7
function install_lfs-bootscripts() {
    # Chapter 7.2
    before lfs-bootscripts
    make install
    after lfs-bootscripts
}

function manage_devices() {
    # Chapter 7.4
    bash /lib/udev/init-net-rules.sh
    sed -i 's/NAME=".*"/NAME="eth0"/' /etc/udev/rules.d/70-persistent-net.rules

    #TODO: cdrom/sound...?
}

function network_config() {
    # Chapter 7.5
    cd /etc/sysconfig/
    cat > ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=10.0.2.15
GATEWAY=10.0.2.2
PREFIX=24
BROADCAST=10.0.2.255
EOF
    #TODO: edit!

    cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

domain mcanal
nameserver 10.0.0.1

# End /etc/resolv.conf
EOF

    echo mcanal > /etc/hostname

    cat > /etc/hosts << "EOF"
#<ip-address> <hostname.domain.org> <hostname>
127.0.0.1 localhost.localdomain locahost
::1 localhost.localdomain locahost
EOF
}

function systemv_config() {
    # Chapter 7.6
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

1:2345:respawn:/sbin/agetty --noclear tty1 9600
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

KEYMAP="fr-latin1"
FONT="lat1-16"

# End /etc/sysconfig/console
EOF
}

function bash_shell() {
    # Chapter 7.7
    cat > /etc/profile << "EOF"
# Begin /etc/profile

export LANG=en_US.UTF-8
export LC_NUMERIC=fr_FR.UTF-8
export LC_TIME=fr_FR.UTF-8
export LC_PAPER=fr_FR.UTF-8
export LC_MONETARY=fr_FR.UTF-8
export LC_MEASUREMENT=fr_FR.UTF-8

# End /etc/profile
EOF
}

function inputrc() {
    # Chapter 7.8
    cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
}

function shells() {
    # Chapter 7.9
    cat > /etc/shells <<EOF
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
}

# Chapter 8
function fstab() {
    # Chapter 8.2
    cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sda2      /            ext4     defaults            1     1
/dev/sda3      /boot        ext4     defaults            1     1
/dev/sda4      swap         swap     pri=1               0     0
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0

# End /etc/fstab
EOF
}

function install_linux() {
    # Chapter 8.3
    before linux

    make mrproper
    make defconfig
    # make menuconfig

    # Device Drivers  --->
    # Generic Driver Options  --->
    # [ ] Support for uevent helper [CONFIG_UEVENT_HELPER]
    #    [*] Maintain a devtmpfs filesystem to mount at /dev [CONFIG_DEVTMPFS]

    # cf. libevdev in moar_packages.sh:
    # Device Drivers  --->
    # Input device support --->
    # <*> Generic input layer (needed for...) [CONFIG_INPUT]
    # <*>   Event interface                   [CONFIG_INPUT_EVDEV]
    # [*]   Miscellaneous devices  --->       [CONFIG_INPUT_MISC]
    #       <*>    User level driver support      [CONFIG_INPUT_UINPUT]

    sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-mcanal"/' .config

    make
    make modules_install
    cp -v arch/x86/boot/bzImage /boot/vmlinuz-4.9.9-mcanal
    cp -v System.map /boot/System.map-4.9.9
    cp -v .config /boot/config-4.9.9
    install -d /usr/share/doc/linux-4.9.9
    cp -r Documentation/* /usr/share/doc/linux-4.9.9
    install -v -m755 -d /etc/modprobe.d
    cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF
    mkdir -pv /usr/src/kernel-4.9.9
    cp -rv . /usr/src/kernel-4.9.9
    after linux
}

function grub() {
    # Chapter 8.4
    grub-install /dev/sda
    # grub-mkconfig -o /boot/grub/grub.cfg
    cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2

insmod gzio
insmod part_msdos

menuentry 'LFS' --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-39b3d1bb-498a-4303-80b2-ec002b534a7e' {
    set root='hd0,msdos7'
    if [ x$feature_platform_search_hint = xy ]; then
        search --no-floppy --fs-uuid --set=root --hint-ieee1275='ieee1275//disk@0,msdos7' --hint-bios=hd0,msdos7 --hint-efi=hd0,msdos7 --hint-baremetal=ahci0,msdos7  fbf33fcd-4adf-4310-8ad5-dfac7e22213e
    else
        search --no-floppy --fs-uuid --set=root fbf33fcd-4adf-4310-8ad5-dfac7e22213e
    fi
    linux /vmlinuz-4.9.9-mcanal root=/dev/sda5 ro
}

menuentry 'Arch Linux' --class arch --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-c79f48e4-7e41-43cc-9287-c07e185bd03c' {
    set root='hd0,msdos1'
    if [ x$feature_platform_search_hint = xy ]; then
        search --no-floppy --fs-uuid --set=root --hint-ieee1275='ieee1275//disk@0,msdos1' --hint-bios=hd0,msdos1 --hint-efi=hd0,msdos1 --hint-baremetal=ahci0,msdos1  c79f48e4-7e41-43cc-9287-c07e185bd03c
    else
        search --no-floppy --fs-uuid --set=root c79f48e4-7e41-43cc-9287-c07e185bd03c
    fi
    linux /boot/vmlinuz-linux root=UUID=c79f48e4-7e41-43cc-9287-c07e185bd03c rw  quiet
    initrd  /boot/initramfs-linux.img
}
EOF
}


# Chapter 9
function end() {
    # Chapter 9.1
    echo 8.0 > /etc/lfs-release
    cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="8.0"
DISTRIB_CODENAME=mcanal
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF
}

TODOS="install_lfs-bootscripts
manage_devices
network_config
systemv_config
bash_shell
inputrc
shells
fstab
install_linux
grub
end"

for todo in $TODOS; do
	log="$LOG_FOLDER/system_config-$todo.log"
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

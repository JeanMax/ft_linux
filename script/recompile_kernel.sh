#!/bin/bash -ex

export MAKEFLAGS='-j 4'

# make mrproper
# make defconfig
# # make menuconfig

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

# mkdir -pv /usr/src/kernel-4.9.9
# cp -rv . /usr/src/kernel-4.9.9

#!/bin/bash

set -x

export LFS='/mnt/lfs'

# Chapter 6.2
mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
	mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

if [ "$1" == "-1" ]; then
    # Chapter 6.4
    chroot "$LFS" /tools/bin/env -i \
	       HOME=/root					\
	       TERM="$TERM"				\
	       PS1='\u:\w\$ '				\
	       PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
	       /tools/bin/bash --login +h $(test "$2" && echo -n '-c ') "$(test "$2" && echo -n "$2")"
elif [ "$1" == "-2" ]; then
    # Chapter 6.33
    chroot "$LFS" /tools/bin/env -i            \
           HOME=/root \
           TERM="$TERM" \
           PS1='\u:\w\$ ' \
	       PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
           /bin/bash --login +h $(test "$2" && echo -n '-c ') "$(test "$2" && echo -n "$2")"
elif [ "$1" == "-3" ]; then
    # Chapter 6.72
    chroot "$LFS" /tools/bin/env -i            \
           HOME=/root \
           TERM="$TERM" \
           PS1='\u:\w\$ ' \
           PATH=/bin:/usr/bin:/sbin:/usr/sbin   \
           /tools/bin/bash --login  $(test "$2" && echo -n '-c ') "$(test "$2" && echo -n "$2")"
elif [ "$1" == "-4" ]; then
    # Chapter 6.73
    chroot "$LFS" /usr/bin/env -i              \
           HOME=/root \
           TERM="$TERM" \
           PS1='\u:\w\$ ' \
           PATH=/bin:/usr/bin:/sbin:/usr/sbin     \
           /bin/bash --login  $(test "$2" && echo -n '-c ') "$(test "$2" && echo -n "$2")"
fi

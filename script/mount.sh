#!/bin/bash

# Chapter 2.7

export LFS='/mnt/lfs'

mkdir -pv $LFS
sudo mount -v -t ext4 /dev/sda2 $LFS

# mkdir -pv $LFS/home
# sudo mount -v -t ext4 /dev/sda6 $LFS/home

mkdir -pv $LFS/boot
sudo mount -v -t ext4 /dev/sda3 $LFS/boot

# sudo /sbin/swapon -v /dev/sda3

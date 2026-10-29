#!/bin/sh
# S4SK SD boot script (single-partition rootfs flashed to SD as mmc 0:1).
# Kernel recipe installs Image + DTB into /boot on the rootfs.
setenv bootargs rw root=/dev/mmcblk0p1 rootwait console=ttySC0,921600n8 ignore_loglevel cma=560M
ext4load mmc 0:1 0x48080000 /boot/Image
ext4load mmc 0:1 0x48000000 /boot/r8a779f4-s4sk.dtb
booti 0x48080000 - 0x48000000

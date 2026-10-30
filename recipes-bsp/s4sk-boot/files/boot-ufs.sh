#!/bin/sh
# S4SK UFS boot script (single-partition rootfs flashed to UFS as scsi 0:1).
# Kernel recipe installs Image + DTB into /boot on the rootfs.
# Without the external UFS calibration firmware the link can fail to come
# up on the first try, so retry enumeration and each load before booting.
setenv bootargs rw root=/dev/sda1 rootwait console=ttySC0,921600n8 ignore_loglevel cma=560M
scsi scan || scsi scan || scsi scan
ext4load scsi 0:1 0x48080000 /boot/Image || ext4load scsi 0:1 0x48080000 /boot/Image || ext4load scsi 0:1 0x48080000 /boot/Image
ext4load scsi 0:1 0x48000000 /boot/r8a779f4-s4sk.dtb || ext4load scsi 0:1 0x48000000 /boot/r8a779f4-s4sk.dtb || ext4load scsi 0:1 0x48000000 /boot/r8a779f4-s4sk.dtb
booti 0x48080000 - 0x48000000

# Build a wic.gz SD image (single rootfs partition, no bootloader).
# The kernel recipe installs Image + DTB into /boot (linux-renesas.bbappend),
# so U-Boot can ext4load them from partition 1.
FILESEXTRAPATHS:prepend := "${THISDIR}/../../wic:"
SRC_URI += "file://rcar-singlepart-noloader.wks"
WKS_FILE = "rcar-singlepart-noloader.wks"
IMAGE_FSTYPES:append = " wic.gz"
IMAGE_INSTALL:append = " kernel"

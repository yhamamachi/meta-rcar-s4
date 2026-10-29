# common config
require conf/machine/include/soc-family.inc
MACHINE_FEATURES = ""
# Add variable to Build Configuration in build log
BUILDCFG_VARS:append = " SOC_FAMILY"

# Configuration for kernel
PREFERRED_PROVIDER_virtual/kernel ?= "linux-renesas"
KERNEL_IMAGETYPE = "Image"
IMAGE_FSTYPES += " tar.bz2 ext4 wic.gz wic.bmap"

# Configuration for ARM Trusted Firmware
EXTRA_IMAGEDEPENDS += " arm-trusted-firmware"

# u-boot
PREFERRED_VERSION_u-boot = "v2026.10+git%"
EXTRA_IMAGEDEPENDS += " u-boot"

WKS_FILE ?= "rcar-singlepart-noloader.wks.in"
# bitbake expands ${S4SK_WIC_EXT4_OPTS} at do_write_wks_template before wic
# runs (image_types_wic.bbclass .wks.in mechanism), so mkfs flags can be
# branched per machine/machineconfig without touching the WKS.
# wic ignores EXTRA_IMAGECMD_ext4; ext4 mkfs flags reach wic only via the
# wks --mkfs-extraopts. -b 4096 matches the UFS logical sector size.
S4SK_WIC_EXT4_OPTS ?= "-F -b 4096 -i 8192"

DEFAULTTUNE ?= "aarch64"
require conf/machine/include/arm/arch-arm64.inc

MACHINE_EXTRA_RRECOMMENDS = " \
    kernel-devicetree kernel-modules u-boot optee-os \
"

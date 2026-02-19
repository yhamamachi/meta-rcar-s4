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
PREFERRED_VERSION_u-boot = "v2026.01+git%"
EXTRA_IMAGEDEPENDS += " u-boot"

WKS_FILE ?= "rcar-singlepart-noloader.wks"

DEFAULTTUNE ?= "aarch64"
require conf/machine/include/arm/arch-arm64.inc

MACHINE_EXTRA_RRECOMMENDS = " \
    kernel-devicetree kernel-modules u-boot optee-os \
"

SUMMARY = "Linux kernel"
DESCRIPTION = "Linux kernel for the R-Car board"
HOMEPAGE = "https://github.com/rcar-community/linux"
BUGTRACKER = "https://github.com/orgs/rcar-community/discussions/categories/q-a"
SECTION = "kernel"
LICENSE = "GPLv2-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

# nooelint: oelint.file.requirenotfound - This file is provided by poky
require recipes-kernel/linux/linux-yocto.inc
CVE_PRODUCT ?= ""

# LINUX_VERSION/REPO/BRANCH/SRCREV are defined in inc file
require recipes-kernel/linux/kernel_6.18.inc
COMPATIBLE_MACHINE = "(s4sk|spider)"

# nooelint: oelint.vars.mispell.unknown - Yocto variable
KCONFIG_MODE = "alldefconfig"
# nooelint: oelint.vars.mispell.unknown
KBUILD_DEFCONFIG:${MACHINE} = "renesas_defconfig"
PV = "${LINUX_VERSION}+git${SRCPV}"
SRC_URI = "${REPO};branch=${BRANCH};protocol=https"
SRC_URI:append = " \
    file://rcar-s4.cfg \
    file://${MACHINE}.cfg \
"
UNPACKDIR ??= "${WORKDIR}"
S = "${UNPACKDIR}/git"

BBCLASSEXTEND = ""

do_compile_kernelmodules:append () {
    if (grep -q -i -e '^CONFIG_MODULES=y$' ${B}/.config); then
        # 5.10+ kernels have module.lds that we need to copy for external module builds
        if [ -e "${B}/scripts/module.lds" ]; then
            install -Dm 0644 ${B}/scripts/module.lds ${STAGING_KERNEL_BUILDDIR}/scripts/module.lds
        fi
    fi
}

do_deploy:append() {
    # Remove the redundant device tree file (<device_tree>-<MACHINE>.dtb) that was created in the deploy directory
    for dtbf in ${KERNEL_DEVICETREE}; do
        dtb=`normalize_dtb "$dtbf"`
        dtb_ext=${dtb##*.}
        dtb_base_name=`basename $dtb .$dtb_ext`
        rm -f $deployDir/$dtb_base_name-${KERNEL_DTB_LINK_NAME}.$dtb_ext
    done
}


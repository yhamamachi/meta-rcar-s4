DESCRIPTION = "ARM Trusted Firmware"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://license.rst;md5=1dd070c98a281d18d9eefd938729b031"

COMPATIBLE_MACHINE = "(s4sk|spider)"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit deploy

PV:rcar-gen4 = "v2.14.0+upstream+git${SRCPV}"
BRANCH:rcar-gen4 = "master"
SRC_URI = "git://github.com/ARM-software/arm-trusted-firmware.git;branch=${BRANCH};protocol=https"
SRCREV:rcar-gen4 = "ea6625c639011747bf49ab2afc0ff4152320c4c3"

S = "${WORKDIR}/git"

CLEAN_OPT:rcar-gen4 = "clean_srecord"
BUILD_OPT:rcar-gen4 = "bl31 rcar_srecord"
PLATFORM:rcar-gen4 = "rcar_gen4"

ATFW_OPT ?= ""
ATFW_CONF ?= ""
ATFW_OPT:rcar-gen4 = "LSI=S4 CTX_INCLUDE_AARCH32_REGS=0 LOG_LEVEL=10 DEBUG=0"

# requires CROSS_COMPILE set by hand as there is no configure script
export CROSS_COMPILE="${TARGET_PREFIX}"

# Let the Makefile handle setting up the CFLAGS and LDFLAGS as it is a standalone application
CFLAGS[unexport] = "1"
LDFLAGS[unexport] = "1"
AS[unexport] = "1"
LD[unexport] = "1"

# do_install() nothing
do_install[noexec] = "1"

do_compile () {
    oe_runmake distclean
    oe_runmake ${CLEAN_OPT} PLAT=${PLATFORM} SPD=none MBEDTLS_COMMON_MK=1 ${ATFW_OPT}
    oe_runmake ${BUILD_OPT} PLAT=${PLATFORM} SPD=none MBEDTLS_COMMON_MK=1 ${ATFW_OPT}

    # Create ${S}/release folder to store output for compile tasks
    install -d ${S}/release

    # Move to ${S}/release and rename
    install ${S}/build/${PLATFORM}/release/bl31/bl31.elf                ${S}/release/bl31-${MACHINE}${ATFW_CONF}.elf
    install ${S}/build/${PLATFORM}/release/bl31.bin                     ${S}/release/bl31-${MACHINE}${ATFW_CONF}.bin
    install ${S}/build/${PLATFORM}/release/bl31.srec                    ${S}/release/bl31-${MACHINE}${ATFW_CONF}.srec
}

do_deploy () {
    # Copy binary files to deploy directory
    install -m 0644 ${S}/release/*.elf  ${DEPLOYDIR}
    install -m 0644 ${S}/release/*.bin  ${DEPLOYDIR}
    install -m 0644 ${S}/release/*.srec ${DEPLOYDIR}
}

addtask deploy after do_compile

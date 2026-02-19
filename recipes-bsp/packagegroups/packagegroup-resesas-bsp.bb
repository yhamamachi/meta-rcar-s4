SUMMARY = "Package group for Renesas board"
LICENSE = "MIT"

COMPATIBLE_MACHINE = "(rcar-gen5)"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PR = "r0"

PACKAGES = " \
    packagegroup-renesas-bsp-tools \
    packagegroup-renesas-bsp-demo \
"

RDEPENDS:packagegroup-renesas-bsp-tools = " \
    i2c-tools \
    coreutils \
    can-utils \
    pciutils \
    usbutils \
    libgpiod \
"

RDEPENDS:packagegroup-renesas-bsp-demo = " \
    python3-pip \
    python3-gpiod \
"

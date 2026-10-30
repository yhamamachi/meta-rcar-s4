SUMMARY = "U-Boot boot scripts for booting S4SK Linux from UFS and SD"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE.MIT;md5=25926c3dcbc13c4786613da243b91cd9"

SRC_URI = "file://boot-ufs.sh file://boot-sd.sh file://LICENSE.MIT"

DEPENDS += "u-boot-tools-native"

COMPATIBLE_MACHINE = "(s4sk|spider)"

S = "${UNPACKDIR}"

do_compile() {
    mkimage -T script -A arm64 -C none -n "S4SK UFS boot" -d boot-ufs.sh boot-ufs.uImage
    mkimage -T script -A arm64 -C none -n "S4SK SD boot" -d boot-sd.sh boot-sd.uImage
}

do_install() {
    install -d ${D}/boot
    install -m 0644 boot-ufs.uImage ${D}/boot/
    install -m 0644 boot-sd.uImage ${D}/boot/
}

FILES:${PN} += "/boot/boot-ufs.uImage /boot/boot-sd.uImage"

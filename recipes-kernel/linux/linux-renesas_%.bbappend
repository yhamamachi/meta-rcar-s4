# Install plain Image and DTBs to /boot so U-Boot ext4load/booti can find
# them on the SD rootfs (wic image built with rcar-singlepart-noloader.wks).
do_install:append() {
    install -m 0644 ${KERNEL_OUTPUT_DIR}/Image ${D}/${KERNEL_IMAGEDEST}/Image
    for dtbf in ${KERNEL_DEVICETREE}; do
        dtb="${B}/${dtbf}"
        if [ -e "$dtb" ]; then
            install -m 0644 "$dtb" "${D}/${KERNEL_IMAGEDEST}/$(basename "$dtb")"
        fi
    done
}

# kernel.bbclass auto-packages /boot/Image* into kernel-image but not DTBs;
# add them so the wic rootfs contains /boot/<machine>.dtb for U-Boot booti.
FILES:${KERNEL_PACKAGE_NAME}-image += "/${KERNEL_IMAGEDEST}/*.dtb"

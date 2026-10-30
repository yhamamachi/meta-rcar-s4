# Build a wic.gz image (single rootfs partition, no bootloader).
# The kernel recipe installs Image + DTB into /boot (linux-renesas.bbappend),
# so U-Boot can ext4load them from partition 1.
# WKS template lives in ${LAYERDIR}/files/wic/ (image_types_wic search path);
# mkfs flags come from S4SK_WIC_EXT4_OPTS (conf/machine/rcars4.inc).
WKS_FILE = "rcar-singlepart-noloader.wks.in"
IMAGE_FSTYPES:append = " wic.gz"
IMAGE_INSTALL:append = " kernel"
# U-Boot boot script (/boot/boot-ufs.uImage) for booting from UFS
IMAGE_INSTALL:append = " s4sk-boot-ufs"

# UFS logical sectors are 4096 bytes, but wic writes the MBR partition
# start/count in 512-byte units — U-Boot/kernel read MBR LBAs in logical
# units, so partition 1 would appear ~8x misplaced and the ext4 superblock
# would not be found. A dedicated task rewrites MBR entry 1 to logical
# units after do_image_complete deploys the .wic.gz (the raw .wic is
# short-lived inside do_image_wic and gone by then). Deterministic: the
# script validates the ext4 superblock and derives start/count from it;
# it refuses to touch anything it cannot verify.
# NOTE: do not hook this via do_image_wic:append() — the wic class is
# inherited after bbappend parsing, so function appends onto do_image_wic
# are silently dropped (setVar clears pending :append operations).
# Register the script in SRC_URI so its checksum participates in task
# signatures (image.bbclass sets do_fetch[noexec], so the file is not
# copied to WORKDIR; the task below resolves it from FILESPATH, whose
# paths are baked in at parse time via FILESEXTRAPATHS/THISDIR).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI = "file://fix_ufs_mbr.py"

do_s4sk_fix_ufs_mbr() {
    script=""
    for p in $(echo "${FILESPATH}" | tr ':' ' '); do
        if [ -f "$p/fix_ufs_mbr.py" ]; then
            script="$p/fix_ufs_mbr.py"
            break
        fi
    done
    if [ -z "$script" ]; then
        echo "s4sk_fix_ufs_mbr: fix_ufs_mbr.py not found in FILESPATH" >&2
        exit 1
    fi
    # SD cards have 512-byte logical blocks, so the wic-native MBR (512-byte
    # units) is already correct for SD boot. Keep an unmodified copy of the
    # deployed gz before rewriting the UFS variant in place; SD flashing
    # consumes ${IMAGE_LINK_NAME}-sd.wic.gz.
    cp -f "${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.wic.gz" \
          "${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}-sd.wic.gz"
    # Patch the deployed artifact (what the flash script consumes); the
    # IMGDEPLOYDIR staging copy is intermediate and overwritten per build.
    python3 "$script" "${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.wic.gz"
}
addtask s4sk_fix_ufs_mbr after do_image_complete before do_build
do_s4sk_fix_ufs_mbr[depends] += "python3-native:do_populate_sysroot"

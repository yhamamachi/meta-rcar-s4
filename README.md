# meta-rcar-s4

Yocto BSP layer for Renesas R-Car S4 boards (S4SK, Spider).

## Build

```
./build.sh s4sk          # MACHINE=s4sk, core-image-minimal (+wic.gz via bbappend)
./build.sh spider
```

Kernel versions: `PREFERRED_VERSION_linux-renesas = "6.18%"` (default,
6.18.54 on `renesas-lts/v6.18.54`, verified booting on S4SK hardware).
Override to `"6.12%"` to build the previous LTS kernel.

## Image layout

`core-image-minimal.bbappend` uses `rcar-singlepart-noloader.wks`: a single
ext4 partition with a UUID, no bootloader. Kernel `Image` + DTB are installed
to `/boot/`, and `s4sk-boot-ufs` installs a mkimage boot script
(`/boot/boot-ufs.uImage`).

## Booting on S4SK (verified on hardware, U-Boot 2026.10)

### From SD card
The SD variant keeps the wic-native MBR (512-byte units — SD logical
blocks are 512, so no UFS unit rewrite is applied):
`core-image-minimal-s4sk.rootfs-sd.wic.gz`. Flash it via
`s4sk_remote/s4sk_flash_sd.sh core-image-minimal-s4sk.rootfs-sd.wic.gz`
(TFTP + `gzwrite mmc 0`; destructive — overwrites the SD card). Boot:

```
ext4load mmc 0:1 0x48000000 /boot/boot-sd.uImage
source 0x48000000
```

The boot script sets `root=/dev/mmcblk0p1` and loads `/boot/Image` + DTB.
(The U-Boot env `bootcmd` still holds the legacy `ext4load mmc ... u-boot`
chain; manual boot as above, or adjust env via `setenv`/`saveenv`.)

### From UFS
U-Boot sees the on-board UFS (WDC 128GB) as SCSI device 0 (7 factory
SDK partitions). Kernel 6.18 binds `ufshcd-renesas` (e6860000.ufs) and
enumerates `/dev/sda` with 7 partitions; `dd` read test passes. To boot a
Yocto image flashed to UFS partition 1:

```
scsi scan
ext4load scsi 0:1 0x48000000 /boot/boot-ufs.uImage
source 0x48000000
```

The boot script sets `root=/dev/sda1` and loads `/boot/Image` + DTB.
Flashing a wic image to UFS overwrites the factory SDK image (partitions
1–7) — treat as destructive.

## Recovery (test-only board — full rewrite OK)

UFS writes never touch QSPI (ATF/OP-TEE/U-Boot), so the board always
retains its bootloader and the SD/TFTP fallback path.

- Re-flash UFS (either image): `s4sk_remote/s4sk_flash_ufs.sh <img>.gz`
  (TFTP + `gzwrite scsi 0`). Our image:
  `core-image-minimal-s4sk.rootfs.wic.gz`.
- Restore factory SDK: `s4sk_remote/s4sk_flash_ufs.sh full.img.gz`
  (SDK full image, 487 MB, present in `/tftp/`); factory `bootcmd` then
  boots the SDK from scsi 0:5 again.
- Corrupted QSPI firmware: `s4sk_remote/s4sk_flash_qspi.sh` (ICUMX TTL
  loader via SD card) rewrites ATF/OP-TEE/U-Boot.
- Broken U-Boot env (`bootcmd` etc.): `env restore-defaults` or
  `env import` from a saved env; SD boot remains available regardless.

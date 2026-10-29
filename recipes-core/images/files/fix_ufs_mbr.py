#!/usr/bin/env python3
"""Rewrite MBR partition LBAs of a wic image into logical-block units.

The S4SK UFS device reports 4096-byte logical sectors. Both U-Boot and the
Linux kernel (block/partitions/msdos.c: sector_size = logical/512, then
offs = start_sect * sector_size) interpret MBR start/count fields as *logical
block* addresses, while `wic` writes them in 512-byte units. Result: partitions
point ~8x past the real filesystem ("Can't find ext4 filesystem", ext4ls finds
nothing).

This script patches the MBR in place so each ext4 partition's start/count are
in logical (sector) units; partition DATA offsets are unchanged. Idempotent.

Usage: fix_ufs_mbr.py <file.wic | file.wic.gz> [--sector 4096]
"""
import gzip
import os
import struct
import sys

EXT4_MAGIC = 0xEF53  # s_magic (u16); empirically at superblock offset 0x38 (= byte 1080 in fs)


def load(path: str) -> bytes:
    if path.endswith('.gz'):
        with gzip.open(path, 'rb') as f:
            return f.read()
    with open(path, 'rb') as f:
        return f.read()


def save(path: str, data: bytes) -> None:
    tmp = path + '.fix.tmp'
    if path.endswith('.gz'):
        with gzip.open(tmp, 'wb') as f:
            f.write(data)
    else:
        with open(tmp, 'wb') as f:
            f.write(data)
    os.replace(tmp, path)


def sb_at(d: bytes | bytearray, fs_off: int):
    """Return (blocks_count,) if an ext4 superblock starts at fs_off, else None."""
    if fs_off + 1024 + 60 > len(d):
        return None
    magic = struct.unpack('<H', d[fs_off + 1024 + 0x38:fs_off + 1024 + 0x3A])[0]
    if magic != EXT4_MAGIC:
        return None
    blocks_count = struct.unpack('<I', d[fs_off + 1024 + 4:fs_off + 1024 + 8])[0]
    return blocks_count


def main() -> None:
    sector = 4096
    if '--sector' in sys.argv:
        sector = int(sys.argv[sys.argv.index('--sector') + 1])
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        sys.exit('usage: fix_ufs_mbr.py <wic|.wic.gz> [--sector N]')
    path = args[0]
    data = bytearray(load(path))
    if len(data) < 512 or data[510:512] != b'\x55\xAA':
        sys.exit(f"{path}: no MBR signature — not a DOS-partitioned image")

    patched = 0
    for i in range(4):
        e = 446 + i * 16
        typ = data[e + 4]
        if typ == 0 or typ in (0xEE, 0x05, 0x82):
            continue
        start, count = struct.unpack('<II', data[e + 8:e + 16])
        if sb_at(data, start * sector):
            print(f"entry {i + 1}: already logical (start={start}) — skip")
            continue
        byte_off = start * 512  # current unit: 512-byte sectors (wic default)
        sb = sb_at(data, byte_off)
        if not sb:
            sys.exit(f"entry {i + 1} (type 0x{typ:02x} start={start}): no ext4 superblock at "
                     f"{byte_off} — layout unknown, refusing")
        if byte_off % sector:
            sys.exit(f"entry {i + 1}: partition offset {byte_off} is not a multiple of {sector} — cannot encode")
        new_start = byte_off // sector
        new_count = sb  # ext4 s_blocks_count: exact logical size of the filesystem
        data[e + 8:e + 16] = struct.pack('<II', new_start, new_count)
        patched += 1
        print(f"entry {i + 1}: start {start}->{new_start}, count {count}->{new_count} "
              f"(logical {sector}-byte units; fs bytes {new_count * sector} <= partition bytes {count * 512})")
        assert new_count * sector <= count * 512, "filesystem larger than partition"

    if patched == 0:
        print(f"{path}: nothing to patch (already logical or no ext4 partitions)")
        return
    assert data[510:512] == b'\x55\xAA'
    save(path, bytes(data))
    print(f"{path}: patched {patched} partition entr{'y' if patched == 1 else 'ies'}")


if __name__ == '__main__':
    main()

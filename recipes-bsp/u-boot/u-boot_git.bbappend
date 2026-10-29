# S4SK QSPI boot: ICUMX loads U-Boot (CA Program #3) to RAM @0x50000000 and
# jumps there (verified from board boot log "CA Program #3 image load info:
# load address = 0x50000000"). Upstream defconfig leaves CONFIG_TEXT_BASE=0,
# so force the link base to match the ICUMX destination.
# Spider boots via SPL and must keep the default text base.
do_configure:append() {
    if [ "${MACHINE}" = "s4sk" ]; then
        sed -i 's/^CONFIG_TEXT_BASE=.*$/CONFIG_TEXT_BASE=0x50000000/' ${B}/.config
        oe_runmake -C ${S} O=${B} oldconfig
    fi
}

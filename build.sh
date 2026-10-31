#!/bin/bash

MACHINE=s4sk

SCRIPT_DIR=$(cd `dirname $0` && pwd)

# Release line follows the checked-out branch/tag: wrynose* builds Yocto 6.0
# (separate oe-core/bitbake/meta-yocto/meta-openembedded clones); anything
# else builds scarthgap. Default: scarthgap.
YOCTO_VERSION=scarthgap
REF=$(git -C ${SCRIPT_DIR} branch --show-current 2>/dev/null)
if [[ -z "${REF}" ]]; then
    REF=$(git -C ${SCRIPT_DIR} describe --tags 2>/dev/null)
fi
if [[ "${REF}" == wrynose* ]]; then
    YOCTO_VERSION=wrynose
fi

mkdir -p ${SCRIPT_DIR}/build
if [[ "${YOCTO_VERSION}" == "wrynose" ]]; then
    mkdir -p ${SCRIPT_DIR}/build/wrynose
    cd ${SCRIPT_DIR}/build/wrynose
else
    cd ${SCRIPT_DIR}/build
fi
export WORK=`pwd`
TARGET_IMAGE=core-image-minimal
USE_SSTATE_MIRROR=no
USE_NEXT_KERNEL=no
BUILD_SBOM=no
BUILD_ROOTFS_ONLY=no
REMOVE_WORKDIR=no
IS_BUILD_INSIDE_REPO=no
IS_BUILD_SDK=no

Usage () {
    echo "Usage:"
    echo "    $0 <board_option> <options>"
    echo "board_option:"
    echo "    s4sk:         Build for S4SK board(default)"
    echo "    spider:       Build for Spider board"
    echo "options:"
    echo "    -h | --help:          Show this help"
    echo "    -s | --sdk:           Build Yocto SDK"
    echo "       | --sbom:          Build SBOM files"
    echo "       | --sstate-mirror: Use sstate mirror server. This may decrease build time."
    echo "       | --rm-work:       Remove working directory while building to reduce storage space."
    exit
}
for arg in $@; do
    if [[ "$arg" == "s4sk" ]]; then
        MACHINE=s4sk
    elif [[ "$arg" == "spider" ]]; then
        MACHINE=spider
    elif [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
        Usage; exit
    elif [[ "$arg" == "-s" ]] || [[ "$arg" == "--sdk" ]]; then
        IS_BUILD_SDK=yes
    elif [[ "$arg" == "--sbom" ]]; then
        BUILD_SBOM=yes
    elif [[ "$arg" == "--rm-work" ]]; then
        REMOVE_WORKDIR=yes
    elif [[ "$arg" == "--sstate-mirror" ]]; then
        USE_SSTATE_MIRROR=yes
    elif [[ "$arg" == "--next-kernel" ]]; then
        USE_NEXT_KERNEL=yes
    elif [[ "$arg" == "--build-rootfs-only" ]]; then
        BUILD_ROOTFS_ONLY=yes
    fi
done

if [[ "$(cat ${SCRIPT_DIR}/conf/layer.conf 2>&1 | grep LAYERDEPENDS_rcar-s4 )" != "" ]] ;then
    IS_BUILD_INSIDE_REPO=yes
fi

cd $WORK
if [[ "${YOCTO_VERSION}" == "wrynose" ]]; then
    # Yocto 6.0 (wrynose): oe-core + bitbake + meta-yocto as separate clones
    # (tested layout; oe-core clone lives in `poky` directory).
    git clone --branch wrynose git://git.openembedded.org/openembedded-core poky
    git clone git://git.openembedded.org/bitbake
    git clone --branch wrynose git://git.yoctoproject.org/meta-yocto
    git clone --branch wrynose git://git.openembedded.org/meta-openembedded
else
    git clone git://git.yoctoproject.org/poky
    git clone git://git.openembedded.org/meta-openembedded
fi
if [[ "${IS_BUILD_INSIDE_REPO}" == "yes" ]]; then
    rm -f meta-rcar-s4
    ln -sfd ${SCRIPT_DIR} meta-rcar-s4
else
    git clone https://github.com/yhamamachi/meta-rcar-s4.git
fi

# Release pins (README.md "Release pins"): reproducible release build.
# meta-rcar-s4 is referenced by release tag (<codename>-YYYY-MM-DD; multiple
# releases can coexist as tags). poky/meta-openembedded are upstream repos we
# cannot tag, so they stay SHA-pinned to the commits tested in this release.
# Branch tips may move; these never change for this release.
if [[ "${YOCTO_VERSION}" == "wrynose" ]]; then
    RCAR_S4_TAG=wrynose-2026-10-30
    POKY_PIN=ae5a301091f5b0574ea7444aab40b309b6d9f3f2
    BITBAKE_TAG=yocto-6.0.4
    META_YOCTO_PIN=79b6d87030178bed0088ad3b00aa6dfbabac37c4
    MOE_PIN=c734c2cb9713dbd6d50697a9f6c25ebdf3ae589e
    git -C poky checkout -B wrynose ${POKY_PIN}
    git -C bitbake checkout ${BITBAKE_TAG}
    git -C meta-yocto checkout -B wrynose ${META_YOCTO_PIN}
    git -C meta-openembedded checkout -B wrynose ${MOE_PIN}
    if [[ "${IS_BUILD_INSIDE_REPO}" == "no" ]]; then
        git -C meta-rcar-s4 checkout -B wrynose refs/tags/${RCAR_S4_TAG}
    fi
else
    RCAR_S4_TAG=release-2026-10-30
    POKY_PIN=104772c5fd0653290cbb5e4b77813343957939cc
    MOE_PIN=0f00f8b9a21950640da8c5707343e5540133f86e
    git -C poky checkout -B scarthgap ${POKY_PIN}
    git -C meta-openembedded checkout -B scarthgap ${MOE_PIN}
    if [[ "${IS_BUILD_INSIDE_REPO}" == "no" ]]; then
        git -C meta-rcar-s4 checkout -B scarthgap refs/tags/${RCAR_S4_TAG}
    fi
fi

cd $WORK
rm -rf build-$MACHINE/conf
TEMPLATECONF=${WORK}/meta-rcar-s4/conf/templates/${MACHINE} \
    . poky/oe-init-build-env build-$MACHINE

if [[ "${YOCTO_VERSION}" == "wrynose" ]]; then
# wrynose layout: oe-core (poky dir) + separate meta-yocto; MOE subset as
# validated by the wrynose-2026-10-30 release build. Quoted heredoc: TOPDIR
# must stay unexpanded here for bitbake to resolve.
cat << 'EOS' > conf/bblayers.conf
BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  ${TOPDIR}/../poky/meta \
  ${TOPDIR}/../meta-yocto/meta-poky \
  ${TOPDIR}/../meta-yocto/meta-yocto-bsp \
  ${TOPDIR}/../meta-rcar-s4 \
  ${TOPDIR}/../meta-openembedded/meta-oe \
  ${TOPDIR}/../meta-openembedded/meta-python \
  ${TOPDIR}/../meta-openembedded/meta-networking \
  "
EOS
fi

if [[ "${USE_SSTATE_MIRROR}" == "yes" ]]; then
cat << EOS >> conf/local.conf
BB_HASHSERVE_UPSTREAM = "wss://hashserv.yoctoproject.org/ws"
SSTATE_MIRRORS ?= "file://.* http://cdn.jsdelivr.net/yocto/sstate/all/PATH;downloadfilename=PATH"
BB_HASHSERVE = "auto"
BB_SIGNATURE_HANDLER = "OEEquivHash"
EOS
fi

if [[ "${BUILD_SBOM}" == "yes" ]]; then
cat << EOS >> conf/local.conf
# added for SBOM
# required. enable to generate spdx files.
INHERIT += "create-spdx"
# optional. if "1", output spdx files will be formatted.
SPDX_PRETTY = "1"
# optional. if "1", output spdx files includes [file-information section](https://spdx.github.io/spdx-spec/v2.3/file-information/).
SPDX_INCLUDE_SOURCES = "1"
# optional. if "1", bitbake will create source files archive for each package.
SPDX_ARCHIVE_SOURCES = "1"
# optional. if "1", bitbake will create output binary archive for each package.
SPDX_ARCHIVE_PACKAGED = "1"
EOS
else # Disable SBOM build to reduce build time
cat << EOS >> conf/local.conf
# Disable create-spdx
INHERIT:remove = "create-spdx"
EOS
fi

if [[ "${USE_NEXT_KERNEL}" == "yes" ]]; then
cat << EOS >> conf/local.conf
# Upstream Kernel Builds
PREFERRED_VERSION_linux-renesas = "6.18%"
LINUXLIBCVERSION = "6.18%"
EOS
fi

if [[ "${BUILD_ROOTFS_ONLY}" == "yes" ]]; then
cat << EOS >> conf/local.conf
# Disable kernel building
PREFERRED_PROVIDER_virtual/kernel = "linux-dummy"
EOS
fi

if [[ "${REMOVE_WORKDIR}" == "yes" ]]; then
    echo 'INHERIT += "rm_work"' >> conf/local.conf
fi

# pyenv shim dirs on PATH make OE's tmp/hosttools/python3 symlink point at
# the shim; fetch wrappers shebang #!/usr/bin/env python3 and die with
# exit 127 ("pyenv: python3: command not found"). Force /usr/bin first so
# hosttools resolves to the real python3.
export PATH=/usr/bin:/bin:$PATH

bitbake ${TARGET_IMAGE}
if [[ "${IS_BUILD_SDK}" == "yes" ]]; then
    bitbake ${TARGET_IMAGE} -c populate_sdk
fi

# Cleanup symbolic link
if [[ "${IS_BUILD_INSIDE_REPO}" == "yes" ]]; then
    rm -f ${WORK}/meta-rcar-s4
fi


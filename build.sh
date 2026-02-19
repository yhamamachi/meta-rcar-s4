#!/bin/bash

MACHINE=s4sk

SCRIPT_DIR=$(cd `dirname $0` && pwd)

mkdir -p ${SCRIPT_DIR}/build
cd ${SCRIPT_DIR}/build
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
git clone git://git.yoctoproject.org/poky
git clone git://git.openembedded.org/meta-openembedded
if [[ "${IS_BUILD_INSIDE_REPO}" == "yes" ]]; then
    rm -f meta-rcar-s4
    ln -sfd ${SCRIPT_DIR} meta-rcar-s4
else
    git clone https://github.com/yhamamachi/meta-rcar-s4.git
fi

git -C poky checkout -B scarthgap origin/scarthgap
git -C meta-openembedded checkout -B scarthgap origin/scarthgap
if [[ "${IS_BUILD_INSIDE_REPO}" == "no" ]]; then
    git -C meta-${MACHINE} checkout -B scarthgap origin/scarthgap-dev
fi

cd $WORK
rm -rf build-$MACHINE/conf
TEMPLATECONF=${WORK}/meta-rcar-s4/conf/templates/${MACHINE} \
    . poky/oe-init-build-env build-$MACHINE

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

bitbake ${TARGET_IMAGE}
if [[ "${IS_BUILD_SDK}" == "yes" ]]; then
    bitbake ${TARGET_IMAGE} -c populate_sdk
fi

# Cleanup symbolic link
if [[ "${IS_BUILD_INSIDE_REPO}" == "yes" ]]; then
    rm -f ${WORK}/meta-${MACHINE}
fi


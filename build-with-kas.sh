#!/bin/bash
# kas-based build entry point. Thin wrapper over kas: clones/pins all repos
# into a per-release-line work dir and builds via bitbake there.
#
# Release line follows the checked-out branch/tag (same rule as build.sh):
# wrynose* -> Yocto 6.0 split repos; anything else -> scarthgap bundled poky.
#
# Usage:
#   ./build-with-kas.sh              # s4sk, core-image-minimal
#   ./build-with-kas.sh spider       # spider board
#   ./build-with-kas.sh s4sk core-image-base   # other target
#
# Cache reuse (optional):
#   DL_DIR=/path/to/downloads SSTATE_DIR=/path/to/sstate ./build-with-kas.sh
#   Keep DL_DIR/SSTATE_DIR per release line (signatures differ across versions).
#
# kas is a pip tool (pip install kas); expects kas on PATH or ~/.local/bin/kas.

MACHINE=s4sk
TARGET=""
for arg in "$@"; do
    if [[ "$arg" == "s4sk" || "$arg" == "spider" ]]; then
        MACHINE="$arg"
    else
        TARGET="$arg"
    fi
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Release line auto-detection, mirroring build.sh.
YOCTO_VERSION=scarthgap
REF=$(git -C "${SCRIPT_DIR}" branch --show-current 2>/dev/null)
if [[ -z "${REF}" ]]; then
    REF=$(git -C "${SCRIPT_DIR}" describe --tags 2>/dev/null)
fi
if [[ "${REF}" == wrynose* ]]; then
    YOCTO_VERSION=wrynose
fi

KAS="$(command -v kas || echo "$HOME/.local/bin/kas")"
if [[ ! -x "$KAS" ]]; then
    echo "kas not found (pip install kas)" >&2
    exit 1
fi

# kas clones repos into KAS_WORK_DIR and builds in <workdir>/build.
# Separate dirs per release line: tmp/sstate must not be shared.
export KAS_WORK_DIR="${SCRIPT_DIR}/build/kas-${YOCTO_VERSION}"
mkdir -p "$KAS_WORK_DIR"

# Keep host env out of the build (same defense as build.sh: pyenv shims on
# PATH break OE's hosttools python3 symlink).
export PATH=/usr/bin:/bin

CONFIG="conf/kas/kas-${MACHINE}.yml"
if [[ "${YOCTO_VERSION}" != "wrynose" ]]; then
    CONFIG="conf/kas/kas-${MACHINE}-scarthgap.yml"
fi

cd "$SCRIPT_DIR"
if [[ -n "$TARGET" ]]; then
    KAS_TARGET="$TARGET" exec "$KAS" build "$CONFIG"
else
    exec "$KAS" build "$CONFIG"
fi

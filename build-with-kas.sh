#!/bin/bash
# kas-based build entry point (wrynose and later). Thin wrapper over kas:
# clones/pins all repos into build/kas and builds via bitbake there.
#
# Usage:
#   ./build-with-kas.sh              # s4sk, core-image-minimal
#   ./build-with-kas.sh spider       # spider board
#   ./build-with-kas.sh s4sk core-image-base   # other target
#
# Cache reuse (optional):
#   DL_DIR=/path/to/downloads SSTATE_DIR=/path/to/sstate ./build-with-kas.sh
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

KAS="$(command -v kas || echo "$HOME/.local/bin/kas")"
if [[ ! -x "$KAS" ]]; then
    echo "kas not found (pip install kas)" >&2
    exit 1
fi

# kas clones repos into KAS_WORK_DIR and builds in <workdir>/build.
export KAS_WORK_DIR="${SCRIPT_DIR}/build/kas"
mkdir -p "$KAS_WORK_DIR"

# Keep host env out of the build (same defense as build.sh: pyenv shims on
# PATH break OE's hosttools python3 symlink).
export PATH=/usr/bin:/bin

cd "$SCRIPT_DIR"
if [[ -n "$TARGET" ]]; then
    KAS_TARGET="$TARGET" exec "$KAS" build "conf/kas/kas-${MACHINE}.yml"
else
    exec "$KAS" build "conf/kas/kas-${MACHINE}.yml"
fi
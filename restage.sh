#!/usr/bin/env bash
#
# Stages freshly-built kernel artifacts from bazel-bin/gborges/{gbrpi4,gbrpi5}
# into device/gborges/{gbrpi4,gbrpi5}-kernel/ in the AOSP tree, so the next
# `make bootimage systemimage vendorimage` picks them up.
#
# Usage:
#   ./gborges/restage.sh <aosp-root> [gbrpi4|gbrpi5|all]
#
# Examples:
#   ./gborges/restage.sh /mnt/build/aosp           # both boards
#   ./gborges/restage.sh /mnt/build/aosp gbrpi4    # rpi4 only
#
# Run from the kernel manifest root after a successful
# `tools/bazel build //gborges:gbrpi{4,5}`.
#
# Idempotent: re-running just overwrites whatever is in the destination.

set -euo pipefail

AOSP_ROOT="${1:-${ANDROID_BUILD_TOP:-}}"
BOARD="${2:-all}"

if [[ -z "${AOSP_ROOT}" ]]; then
    echo "ERROR: usage: $0 <aosp-root> [gbrpi4|gbrpi5|all]" >&2
    echo "       (or export ANDROID_BUILD_TOP)" >&2
    exit 1
fi
if [[ ! -d "${AOSP_ROOT}/device/gborges" ]]; then
    echo "ERROR: ${AOSP_ROOT}/device/gborges not found." >&2
    echo "       Pass the AOSP root that contains device/gborges/." >&2
    exit 1
fi

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES=(can.ko can-dev.ko can-raw.ko can-bcm.ko mcp251x.ko)

restage_one() {
    local board="$1"            # gbrpi4 or gbrpi5
    local dtb_glob="$2"         # bcm2711-rpi-*.dtb or bcm2712*-rpi-*.dtb

    local src="${REPO_ROOT}/bazel-bin/gborges/${board}"
    local dst="${AOSP_ROOT}/device/gborges/${board}-kernel"

    if [[ ! -f "${src}/Image" ]]; then
        echo "ERROR: ${src}/Image not found — did you 'tools/bazel build //gborges:${board}'?" >&2
        return 1
    fi
    mkdir -p "${dst}/modules" "${dst}/overlays"

    cp -fL "${src}/Image" "${dst}/Image"
    cp -fL ${src}/${dtb_glob} "${dst}/"

    cp -fL "${src}/arch/arm64/boot/dts/overlays/"*.dtbo "${dst}/overlays/"
    cp -fL "${src}/arch/arm64/boot/dts/overlays/hat_map.dtb"     "${dst}/overlays/"
    cp -fL "${src}/arch/arm64/boot/dts/overlays/overlay_map.dtb" "${dst}/overlays/"

    for ko in "${MODULES[@]}"; do
        local found
        found="$(find "${src}" -name "${ko}" -print -quit)"
        if [[ -z "${found}" ]]; then
            echo "ERROR: ${ko} not found under ${src}" >&2
            return 1
        fi
        cp -fL "${found}" "${dst}/modules/${ko}"
    done

    local overlay_count
    overlay_count="$(ls "${dst}/overlays/" | wc -l)"
    echo "${board}: Image + dtbs + ${overlay_count} overlays + ${#MODULES[@]} modules → ${dst}"
}

case "${BOARD}" in
    gbrpi4) restage_one gbrpi4 "bcm2711-rpi-*.dtb" ;;
    gbrpi5) restage_one gbrpi5 "bcm2712*-rpi-*.dtb" ;;
    all)
        restage_one gbrpi4 "bcm2711-rpi-*.dtb"
        restage_one gbrpi5 "bcm2712*-rpi-*.dtb"
        ;;
    *)
        echo "ERROR: unknown board '${BOARD}' — expected gbrpi4 / gbrpi5 / all" >&2
        exit 1
        ;;
esac

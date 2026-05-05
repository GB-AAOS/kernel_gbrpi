#!/usr/bin/env bash
#
# Post-`repo sync` setup for the gborges kernel build.
#
# Materializes prebuilt artifacts that NDK r26 doesn't ship but kleaf's
# build/kernel/kleaf/ndk.BUILD declares as required Bazel inputs (libdl.a
# and libm.a in the aarch64-linux-android sysroot). Without these stubs,
# `tools/bazel build //gborges:gbrpi{4,5}` fails analysis with:
#   missing input file '@@+_repo_rules+prebuilt_ndk//:toolchains/llvm/
#   prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libdl.a'
#
# Idempotent: re-running is a no-op if the stubs already exist.
#
# Run from the kernel manifest root (the directory that contains
# tools/bazel and the prebuilts/ndk-r26 project) after every `repo sync`:
#   ./gborges/setup.sh

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
NDK_LIB_DIR="${REPO_ROOT}/prebuilts/ndk-r26/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"

if [[ ! -d "${NDK_LIB_DIR}" ]]; then
    echo "ERROR: NDK r26 sysroot not found at ${NDK_LIB_DIR}" >&2
    echo "       Run 'repo sync' first." >&2
    exit 1
fi

if ! command -v ar >/dev/null 2>&1; then
    echo "ERROR: 'ar' not in PATH; install binutils." >&2
    exit 1
fi

created=0
for stub in libdl.a libm.a; do
    target="${NDK_LIB_DIR}/${stub}"
    if [[ -f "${target}" ]]; then
        continue
    fi
    (cd "${NDK_LIB_DIR}" && ar rcs "${stub}")
    echo "Created stub ${target}"
    created=$((created + 1))
done

if (( created == 0 )); then
    echo "All NDK stubs already in place — nothing to do."
fi

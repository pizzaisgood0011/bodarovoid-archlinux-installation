#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/lib/guided_disk_b13.sh"
[[ $(b13_layout_mib 73728 4096) == '1024 4096 68600' ]]
[[ $(b13_layout_mib 32768 0) == '1024 0 31736' ]]
! b13_layout_mib 10240 4096 >/dev/null
! b13_layout_mib nope 4096 >/dev/null
! b13_preview '' >/dev/null
# Fail closed on a nonexistent device.
! b13_disk_info /dev/bodarovoid-nonexistent >/dev/null
# No disk-write utilities may be invoked in this read-only module.
! grep -Eq '^[[:space:]]*(sgdisk|parted|sfdisk|wipefs|mkfs\.|mkswap|dd|mount|swapon)[[:space:]]' "$ROOT/lib/guided_disk_b13.sh"
printf 'PASS: B13 guided layout calculations and read-only checks (NO DISK WRITES)\n'

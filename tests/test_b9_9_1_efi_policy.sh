#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/lib/safety_b991.sh"
b98_validate() { B98_ERRORS=(); [[ ${MOCK_GATE:-ok} == ok ]]; }
b991_efi_parttype() { printf '%s\n' "${MOCK_PARTTYPE:-c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"; }
b991_efi_type() { printf '%s\n' "${MOCK_FS:-}"; }
DISK=/dev/mockdisk EFI_PART=/dev/mockefi ROOT_PART=/dev/mockroot SWAP_PART=/dev/mockswap
MOCK_FS=''
b991_validate create
[[ ${B991_PLAN[0]} == 'CREATE NEW EFI'* ]]
if b991_validate reuse; then echo 'FAIL: reused blank EFI' >&2; exit 1; fi
MOCK_FS=vfat
b991_validate reuse
[[ ${B991_PLAN[0]} == 'PRESERVE EFI'* ]]
if b991_validate create; then echo 'FAIL: create over existing FAT' >&2; exit 1; fi
MOCK_FS=ext4
if b991_validate reuse; then echo 'FAIL: reuse ext4 EFI' >&2; exit 1; fi
MOCK_FS='' MOCK_PARTTYPE=wrong
if b991_validate create; then echo 'FAIL: wrong ESP GUID' >&2; exit 1; fi
MOCK_PARTTYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b SWAP_PART=/dev/mockefi
if b991_validate create; then echo 'FAIL: overlapping partitions' >&2; exit 1; fi
SWAP_PART=/dev/mockswap MOCK_GATE=blocked
if b991_validate create; then echo 'FAIL: upstream gates' >&2; exit 1; fi
MOCK_GATE=ok
report=$(b991_report create)
[[ $report == *'Real installation remains DISABLED.'* ]]
[[ $report != *'[NOT EXECUTED] mkfs.fat'* ]]
printf 'B9.9.1 EFI create/reuse policy tests passed.\n'

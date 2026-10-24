#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/lib/safety_b99.sh"
b98_validate() { B98_ERRORS=(); [[ ${MOCK_GATE:-ok} == ok ]]; }
b99_efi_type() { printf '%s\n' "${MOCK_EFI_TYPE:-vfat}"; }
DISK=/dev/mockdisk EFI_PART=/dev/mockefi ROOT_PART=/dev/mockroot SWAP_PART=/dev/mockswap
MOCK_GATE=ok MOCK_EFI_TYPE=vfat
b99_validate
[[ ${#B99_PLAN[@]} -eq 6 ]]
[[ ${B99_PLAN[0]} == 'PRESERVE EFI'* ]]
[[ ${B99_PLAN[1]} == 'ERASE ROOT'* ]]
[[ ${B99_PLAN[2]} == 'ERASE SWAP'* ]]
[[ ${B99_REVIEWED} -eq 0 ]]
output=$(b99_report)
[[ $output == *'Real installation remains DISABLED.'* ]]
[[ $output != *'mkfs.fat '* ]]
MOCK_EFI_TYPE=ext4
if b99_validate; then echo 'FAIL: non-FAT EFI accepted' >&2; exit 1; fi
MOCK_EFI_TYPE=vfat MOCK_GATE=blocked
if b99_validate; then echo 'FAIL: failed upstream gate accepted' >&2; exit 1; fi
MOCK_GATE=ok SWAP_PART=/dev/mockefi
if b99_validate; then echo 'FAIL: overlapping partitions accepted' >&2; exit 1; fi
printf 'B9.9 read-only EFI preservation and policy tests passed.\n'

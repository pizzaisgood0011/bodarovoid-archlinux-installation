#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/lib/preparation_b98.sh"
# Stub the upstream gate; tests do not touch real devices.
b97_validate() { B97_ERRORS=(); [[ ${MOCK_GATE:-ok} == ok ]]; }
DISK=/dev/mockdisk EFI_PART=/dev/mockefi ROOT_PART=/dev/mockroot SWAP_PART=/dev/mockswap
FILESYSTEM=ext4 BOOTLOADER=GRUB
b98_build_commands
[[ ${#B98_COMMANDS[@]} -eq 7 ]]
[[ ${B98_COMMANDS[0]} == 'mkfs.ext4 /dev/mockroot' ]]
[[ ${B98_COMMANDS[1]} == *'EFI filesystem policy deferred to B9.9.1'* ]]
[[ ${B98_COMMANDS[*]} != *'mkfs.fat -F 32'* ]]
[[ ${B98_COMMANDS[2]} == 'mkswap /dev/mockswap' ]]
report=$(b98_report)
[[ $report == *'[NOT EXECUTED] mkfs.ext4'* ]]
[[ $report == *'Real installation remains DISABLED.'* ]]
MOCK_GATE=blocked
if b98_build_commands; then echo 'FAIL: blocked gate passed' >&2; exit 1; fi
[[ ${#B98_COMMANDS[@]} -eq 0 ]]
MOCK_GATE=ok FILESYSTEM=btrfs
if b98_build_commands; then echo 'FAIL: unsupported filesystem passed' >&2; exit 1; fi
FILESYSTEM=ext4 SWAP_PART=''
if b98_build_commands; then echo 'FAIL: missing swap passed' >&2; exit 1; fi
SWAP_PART=/dev/mockswap
ROOT_PART='/dev/mockroot;touch /tmp/unsafe'
b98_build_commands
[[ ${B98_COMMANDS[0]} == *'\;'* ]]
[[ ! -e /tmp/unsafe ]]
echo 'B9.8 read-only command preview gate tests passed.'

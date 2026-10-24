#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/format_b102.sh
DISK=/dev/mockdisk EFI_PART=/dev/mockdisk1 ROOT_PART=/dev/mockdisk3 SWAP_PART=/dev/mockdisk2 FILESYSTEM=ext4
b101_rehearsal_valid() { [[ ${1:-} == "${ALLOW_MODE:-create}" && ${ALLOW:-yes} == yes ]]; }
b95_is_approved() { [[ ${LOCK:-yes} == yes ]]; }
# The mocked block-device check is deliberately rejected: no real block devices used.
! b102_validate create
[[ ${B102_ERRORS[*]} == *'Missing block device'* ]]
ALLOW=no
! b102_validate create
[[ ${B102_ERRORS[*]} == *'missing or stale'* ]]
ALLOW=yes LOCK=no
! b102_validate create
[[ ${B102_ERRORS[*]} == *'lock is missing or stale'* ]]
LOCK=yes ALLOW_MODE=reuse
! b102_validate create
[[ ${B102_ERRORS[*]} == *'missing or stale'* ]]
# Static check: this module has no execution calls or real write authorization.
! grep -Eq '(^|[[:space:]])(eval|mkfs\.|mkswap|wipefs|mount|swapon)[[:space:]]' lib/format_b102.sh
printf 'B10.2 fail-closed read-only formatting design tests passed.\n'

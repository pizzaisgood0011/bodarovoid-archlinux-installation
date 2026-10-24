#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/readiness_b108.sh
DISK=/dev/not-a-real-disk EFI_PART=/dev/fake1 ROOT_PART=/dev/fake3 SWAP_PART=/dev/fake2
b107_validate() { [[ ${1:-} == create ]]; }
b101_rehearsal_valid() { return 0; }
b95_is_approved() { return 0; }
! b108_check create
[[ "${B108_ERRORS[*]}" == *'not a block device'* ]]
! b108_rehearse create 'CHECK /dev/not-a-real-disk ONLY'
[[ -z $B108_CONFIRMATION_FINGERPRINT ]]
! b108_report create >/dev/null
! b108_check reuse
# Verify the read-only swap inspection syntax on this host.
if command -v swapon >/dev/null 2>&1; then
  swapon --show=NAME --noheadings --raw >/dev/null
fi
# Ensure there are no direct mutating commands in the module.
! grep -Eq '^[[:space:]]*(mkfs\.|mkswap|mount|umount|swapon[[:space:]]|swapoff|pacstrap|arch-chroot|grub-install|efibootmgr|dd[[:space:]]|wipefs|sgdisk)[[:space:]]' lib/readiness_b108.sh
printf 'B10.8 read-only safety tests passed.\n'

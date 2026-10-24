#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/prewrite_b109.sh
DISK=/dev/not-a-real-disk
b108_check() { return 1; }
! b109_check create
[[ "${B109_ERRORS[*]}" == *'B10.8'* ]]
! b109_rehearse create 'GUARD /dev/not-a-real-disk ONLY'
[[ -z $B109_FINGERPRINT ]]
! b109_report create >/dev/null
! grep -Eq '^[[:space:]]*(mkfs\.|mkswap|mount|umount|swapoff|pacstrap|arch-chroot|grub-install|efibootmgr|dd[[:space:]]|wipefs|sgdisk)[[:space:]]' lib/prewrite_b109.sh
printf 'B10.9 fail-closed and read-only tests passed.\n'

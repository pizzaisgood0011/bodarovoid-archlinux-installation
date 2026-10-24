#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/pipeline_audit_b107.sh
DISK=/dev/mockdisk EFI_PART=/dev/mockdisk1 ROOT_PART=/dev/mockdisk3 SWAP_PART=/dev/mockdisk2
KERNEL=linux FILESYSTEM=ext4 BOOTLOADER=GRUB
b106_validate() { [[ ${ALLOW:-yes} == yes && ${1:-} == create ]]; }
b107_validate create
[[ ${#B107_MATRIX[@]} -eq 4 ]]
[[ "${B107_FINDINGS[*]}" == *'DO NOT enable installation'* ]]
[[ $(b107_report create) == *'EXECUTION NOT READY'* ]]
for pair in 'ext4 GRUB' 'btrfs GRUB' 'ext4 Limine' 'btrfs Limine'; do
  read -r FILESYSTEM BOOTLOADER <<< "$pair"
  b107_validate create
 done
ALLOW=no
! b107_validate create
[[ "${B107_ERRORS[*]}" == *'prerequisites failed'* ]]
ALLOW=yes
! b107_validate reuse
FILESYSTEM=xfs
! b107_validate create
! grep -Eq '^[[:space:]]*(grub-install|grub-mkconfig|efibootmgr|limine|arch-chroot|mount|mkfs\.|mkswap|swapon|pacstrap|eval)[[:space:]]' lib/pipeline_audit_b107.sh
printf 'B10.7 read-only pipeline audit tests passed.\n'

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/bootloader_b106.sh
DISK=/dev/mockdisk EFI_PART=/dev/mockdisk1 ROOT_PART=/dev/mockdisk3 SWAP_PART=/dev/mockdisk2
KERNEL=linux FILESYSTEM=ext4 BOOTLOADER=GRUB
b105_validate() { [[ ${ALLOW:-yes} == yes && ${1:-} == create ]]; }
b106_validate create
[[ "${B106_STEPS[*]}" == *'GRUB UEFI'* ]]
[[ "${B106_STEPS[*]}" == *'ext4 root UUID'* ]]
[[ $(b106_report create) == *'Real installation DISABLED'* ]]
BOOTLOADER=Limine FILESYSTEM=btrfs
b106_validate create
[[ "${B106_STEPS[*]}" == *'Limine UEFI'* ]]
[[ "${B106_STEPS[*]}" == *'rootflags=subvol=@'* ]]
BOOTLOADER=invalid
! b106_validate create
[[ "${B106_ERRORS[*]}" == *'Unsupported bootloader'* ]]
BOOTLOADER=GRUB EFI_PART=$ROOT_PART
! b106_validate create
[[ "${B106_ERRORS[*]}" == *'overlaps'* ]]
EFI_PART=/dev/mockdisk1 ALLOW=no
! b106_validate create
[[ "${B106_ERRORS[*]}" == *'B10.5'* ]]
ALLOW=yes
! b106_validate reuse
! grep -Eq '^[[:space:]]*(grub-install|grub-mkconfig|efibootmgr|limine|arch-chroot|mount|mkfs\.|pacstrap|eval)[[:space:]]' lib/bootloader_b106.sh
printf 'B10.6 read-only GRUB/Limine planning and safety tests passed.\n'

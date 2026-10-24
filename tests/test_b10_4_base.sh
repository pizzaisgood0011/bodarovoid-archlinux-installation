#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/base_b104.sh
DISK=/dev/fake EFI_PART=/dev/fake1 ROOT_PART=/dev/fake3 SWAP_PART=/dev/fake2
FILESYSTEM=ext4 BOOTLOADER=GRUB KERNEL=linux CPU=AMD
ALLOW=yes
b103_validate() { [[ ${ALLOW:-no} == yes && ${1:-} == create ]]; }
b104_validate create
[[ " ${B104_PACKAGES[*]} " == *' amd-ucode '* ]]
[[ " ${B104_PACKAGES[*]} " == *' grub '* ]]
[[ " ${B104_PACKAGES[*]} " != *' btrfs-progs '* ]]
FILESYSTEM=btrfs BOOTLOADER=Limine KERNEL=linux-lts CPU=Intel
b104_validate create
[[ " ${B104_PACKAGES[*]} " == *' btrfs-progs '* ]]
[[ " ${B104_PACKAGES[*]} " == *' limine '* ]]
[[ " ${B104_PACKAGES[*]} " == *' intel-ucode '* ]]
KERNEL=invalid
! b104_validate create
[[ "${B104_ERRORS[*]}" == *'Unsupported kernel'* ]]
KERNEL=linux ALLOW=no
! b104_validate create
[[ "${B104_ERRORS[*]}" == *'B10.3'* ]]
ALLOW=yes
! b104_validate reuse
[[ "${B104_ERRORS[*]}" == *'B10.3'* ]]
! grep -Eq '^[[:space:]]*(pacstrap|genfstab|mount|umount|mkfs\.|mkswap|swapon|arch-chroot|eval)[[:space:]]' lib/base_b104.sh
printf 'B10.4 read-only package and fstab planning tests passed.\n'

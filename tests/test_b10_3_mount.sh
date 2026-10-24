#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/mount_b103.sh
DISK=/dev/fake EFI_PART=/dev/fake1 ROOT_PART=/dev/fake3 SWAP_PART=/dev/fake2 FILESYSTEM=ext4 BOOTLOADER=GRUB
ALLOW=yes
b102_validate() { [[ ${ALLOW:-no} == yes && ${1:-} == create ]]; }
b103_validate create
[[ ${B103_STEPS[*]} == *'Mount ext4 root'* ]]
[[ ${B103_STEPS[*]} == *'reverse order'* ]]
FILESYSTEM=btrfs
b103_validate create
[[ ${B103_STEPS[*]} == *'subvol=@home'* ]]
FILESYSTEM=ext4 ALLOW=no
! b103_validate create
[[ ${B103_ERRORS[*]} == *'B10.2'* ]]
ALLOW=yes
! b103_validate reuse
B103_TARGET=/tmp
! b103_validate create
[[ ${B103_ERRORS[*]} == *'must be /mnt'* ]]
# This module must never invoke the filesystem or mount executors.
! grep -Eq '^[[:space:]]*(mount|umount|swapon|swapoff|mkfs\.|mkswap|btrfs[[:space:]]subvolume|eval)[[:space:]]' lib/mount_b103.sh
printf 'B10.3 read-only mount and cleanup planning tests passed.\n'

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/authorization_b101.sh
DISK=/dev/test EFI_PART=/dev/test1 ROOT_PART=/dev/test3 SWAP_PART=/dev/test2 FILESYSTEM=ext4 BOOTLOADER=GRUB
b93_snapshot() { printf 'approved-settings'; }
b100_validate() { [[ $1 == create ]]; }
b95_is_approved() { return 0; }
b95_fingerprint() { printf '%s\n' "${TEST_FINGERPRINT:-fingerprint-a}"; }
! b101_rehearse create 'WRONG' || { echo 'Incorrect phrase accepted'; exit 1; }
b101_rehearse create 'REHEARSE /dev/test ONLY'
b101_rehearsal_valid create
TEST_FINGERPRINT=fingerprint-b
! b101_rehearsal_valid create || { echo 'Disk change not rejected'; exit 1; }
TEST_FINGERPRINT=fingerprint-a
FILESYSTEM=btrfs
! b101_rehearsal_valid create || { echo 'Filesystem change not rejected'; exit 1; }
FILESYSTEM=ext4
! b101_rehearsal_valid reuse || { echo 'EFI policy change not rejected'; exit 1; }
! b101_rehearse reuse 'REHEARSE /dev/test ONLY' || { echo 'Invalid plan accepted'; exit 1; }
[[ -z $B101_REHEARSAL_FINGERPRINT ]] || { echo 'Old rehearsal not cleared'; exit 1; }
echo 'B10.1 authorization rehearsal and invalidation tests passed.'

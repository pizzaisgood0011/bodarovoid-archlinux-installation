#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/engine_b100.sh"
DISK=/dev/fake EFI_PART=/dev/fake1 ROOT_PART=/dev/fake2 SWAP_PART=/dev/fake3
FILESYSTEM=ext4 BOOTLOADER=GRUB
b97_validate() { return 0; }
lsblk() { printf 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b\n'; }
blkid() { return 2; }
for FILESYSTEM in ext4 btrfs; do
  for BOOTLOADER in GRUB Limine; do
    b100_validate create
    [[ ${#B100_PLAN[@]} -gt 0 ]]
  done
done
blkid() { printf 'vfat\n'; }
b100_validate reuse
if b100_validate create; then echo 'FAIL: create accepted existing filesystem' >&2; exit 1; fi
EFI_PART="$ROOT_PART"
if b100_validate reuse; then echo 'FAIL: overlapping partitions accepted' >&2; exit 1; fi
EFI_PART=/dev/fake1
b97_validate() { return 1; }
if b100_validate reuse; then echo 'FAIL: missing safety gates accepted' >&2; exit 1; fi
printf 'B10.0 read-only engine foundation tests passed.\n'

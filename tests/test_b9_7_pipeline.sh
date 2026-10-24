#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/pipeline_b97.sh
DISK=/dev/fake; EFI_PART=/dev/fake1; ROOT_PART=/dev/fake2; SWAP_PART=''
b93_is_approved() { return 0; }
b94_run() { B94_ERRORS=(); }
b95_is_approved() { return 0; }
result=$(b97_report)
[[ $result == *'SIMULATION COMPLETE'* && $result == *'Real installation remains DISABLED'* ]] || exit 1
b95_is_approved() { return 1; }
if b97_report >/dev/null; then echo 'FAIL: stale lock accepted'; exit 1; fi
b95_is_approved() { return 0; }
b94_run() { B94_ERRORS=('unsafe target'); }
if b97_report >/dev/null; then echo 'FAIL: preflight failure accepted'; exit 1; fi
b94_run() { B94_ERRORS=(); }
b93_is_approved() { return 1; }
if b97_report >/dev/null; then echo 'FAIL: stale settings accepted'; exit 1; fi
if grep -En '^[[:space:]]*(mkfs|wipefs|sgdisk|parted|pacstrap|mount|swapon|grub-install|arch-chroot|genfstab)([[:space:]]|$)' lib/pipeline_b97.sh; then
  echo 'FAIL: destructive command in simulation module'; exit 1
fi
printf 'B9.7 pipeline simulation gate tests passed.\n'

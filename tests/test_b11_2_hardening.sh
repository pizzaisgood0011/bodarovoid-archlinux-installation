#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
bash -n arch-install.sh lib/vm_install.sh
source lib/vm_install.sh
DISK=/dev/nonexistent EFI_PART=/dev/nonexistent1 ROOT_PART=/dev/nonexistent2 SWAP_PART=/dev/nonexistent3
FILESYSTEM=ext4 BOOTLOADER=GRUB DESKTOP=none KERNEL=linux
B109_FINGERPRINT='' B109_SNAPSHOT='' B109_MODE=''
if vm_install_check; then echo 'FAIL: nonexistent disk was accepted' >&2; exit 1; fi
[[ ${#VM_INSTALL_ERRORS[@]} -gt 0 ]]
# Never call the destructive executor in automated tests.
grep -Fq 'EFI, root and swap must be distinct partitions.' lib/vm_install.sh
grep -Fq 'partition does not belong directly to the selected disk.' lib/vm_install.sh
printf 'PASS: B11.2 static and fail-closed checks (NO DISK WRITES)\n'

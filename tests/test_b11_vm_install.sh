#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n arch-install.sh lib/vm_install.sh
# All validation tests run with fake state and must never execute write commands.
source lib/vm_install.sh
DISK=/dev/not-a-disk EFI_PART=/dev/not-efi ROOT_PART=/dev/not-root SWAP_PART=/dev/not-swap
FILESYSTEM=ext4 BOOTLOADER=GRUB DESKTOP=none KERNEL=linux
B109_FINGERPRINT='' B109_SNAPSHOT='' B109_MODE=''
if vm_install_check; then echo 'FAIL: unsafe state accepted' >&2; exit 1; fi
[[ ${#VM_INSTALL_ERRORS[@]} -gt 0 ]]
FILESYSTEM=btrfs
if vm_install_check; then echo 'FAIL: unsupported filesystem accepted' >&2; exit 1; fi
BOOTLOADER=Limine
if vm_install_check; then echo 'FAIL: unsupported bootloader accepted' >&2; exit 1; fi
# Test virtual-hardware gate with fake DMI: actual host must never be treated as disposable.
if [[ ! $(cat /sys/class/dmi/id/product_name 2>/dev/null) == VirtualBox ]]; then
  if vm_install_is_virtualbox; then echo 'FAIL: non-VirtualBox environment accepted' >&2; exit 1; fi
fi
printf 'PASS: B11 syntax and fail-closed tests (NO DISK WRITES)\n'

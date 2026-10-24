#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for file in arch-install.sh lib/*.sh config/*.sh tests/*.sh; do bash -n "$file"; done
! grep -Rq 'plymouth' lib/ arch-install.sh
# The LUKS initramfs must use systemd's sd-encrypt and rd.luks.name.
grep -Fq 'rd.luks.name=' lib/vm_install.sh
grep -Fq 'sd-encrypt filesystems' lib/vm_install.sh
# Destructive install must retain its explicit confirmation and virtual-disk guard.
grep -Fq 'ERASE ${DISK} AND INSTALL' lib/vm_install.sh
grep -Fq 'bv_disk_guard' lib/vm_install.sh
printf 'RC1 static checks passed. This is not a VM boot or physical-hardware test.\n'

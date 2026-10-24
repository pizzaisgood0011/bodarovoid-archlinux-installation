#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/preflight_b95.sh
# A missing target must never be accepted.
DISK=''; EFI_PART=''; ROOT_PART=''; SWAP_PART=''
if b95_fingerprint >/dev/null 2>&1; then echo 'FAIL: missing target accepted'; exit 1; fi
B95_APPROVED_FINGERPRINT=''; B95_APPROVED_SETTINGS=''
if b95_is_approved >/dev/null 2>&1; then echo 'FAIL: unapproved target accepted'; exit 1; fi
# Source inspection: this stage must not call destructive utilities.
if grep -En '(^|[[:space:]])(mkfs|wipefs|sgdisk|parted|pacstrap|mount|swapon|grub-install)([[:space:]]|$)' lib/preflight_b95.sh; then
  echo 'FAIL: destructive command found'; exit 1
fi
printf 'B9.5 read-only target lock tests passed.\n'

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/config_b105.sh
DISK=/dev/fake EFI_PART=/dev/fake1 ROOT_PART=/dev/fake3 SWAP_PART=/dev/fake2
FILESYSTEM=ext4 BOOTLOADER=GRUB
HOSTNAME=testhost USERNAME=testuser TIMEZONE=UTC KEYMAP=us LOCALE=en_US.UTF-8
b104_validate() { [[ ${ALLOW:-yes} == yes && ${1:-} == create ]]; }
system_valid_hostname() { [[ $1 =~ ^[a-zA-Z0-9-]+$ && -n $1 ]]; }
system_valid_username() { [[ $1 =~ ^[a-z_][a-z0-9_-]*$ && $1 != root ]]; }
# A portable test fixture for locale availability is needed on non-Arch hosts.
if [[ -f /etc/locale.gen ]] && grep -Eq '^[#[:space:]]*en_US\.UTF-8[[:space:]]' /etc/locale.gen; then
  b105_validate create
  [[ ${#B105_STEPS[@]} -ge 8 ]]
  USERNAME=root
  ! b105_validate create
  [[ "${B105_ERRORS[*]}" == *'Username'* ]]
  USERNAME=testuser ALLOW=no
  ! b105_validate create
  [[ "${B105_ERRORS[*]}" == *'B10.4'* ]]
else
  echo 'SKIP locale-dependent positive test: /etc/locale.gen unavailable on this host.'
fi
! grep -Eq '^[[:space:]]*(arch-chroot|useradd|passwd|locale-gen|systemctl|ln|tee|mount|mkfs\.|pacstrap|eval)[[:space:]]' lib/config_b105.sh
printf 'B10.5 read-only system configuration planning tests passed.\n'

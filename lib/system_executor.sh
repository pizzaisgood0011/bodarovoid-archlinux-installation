#!/usr/bin/env bash
# B9.1: configure an existing Arch root. Never partitions or formats disks.

system_exec_validate() {
  system_valid_hostname "${HOSTNAME:-}" || { echo 'Invalid hostname' >&2; return 1; }
  system_valid_username "${USERNAME:-}" || { echo 'Invalid username' >&2; return 1; }
  [[ ${TIMEZONE:-} != /* && ${TIMEZONE:-} != *'..'* && -f /usr/share/zoneinfo/${TIMEZONE:-} ]] || { echo 'Invalid timezone' >&2; return 1; }
  [[ ${KEYMAP:-} =~ ^[a-zA-Z0-9_+.-]+$ ]] || { echo 'Invalid keymap' >&2; return 1; }
  [[ ${LOCALE:-} =~ ^[a-zA-Z0-9_@.-]+$ ]] || { echo 'Invalid locale' >&2; return 1; }
  grep -Eq "^[#[:space:]]*${LOCALE//./\.}[[:space:]]+UTF-8([[:space:]]*)$" /etc/locale.gen || { echo 'Locale not found in locale.gen' >&2; return 1; }
  local keymap_path
  keymap_path=$(find /usr/share/kbd/keymaps -type f \( -name "${KEYMAP}.map.gz" -o -name "${KEYMAP}.map" -o -name "${KEYMAP}.map.xz" \) -print -quit 2>/dev/null) || return 1
  [[ -n $keymap_path ]] || { echo 'Keymap not found' >&2; return 1; }
}

system_exec_preview() {
  system_exec_validate || return 1
  printf 'Target: %s\nHostname: %s\nUsername: %s\nTimezone: %s\nKeymap: %s\nLocale: %s\n' \
    "${1:-/mnt}" "$HOSTNAME" "$USERNAME" "$TIMEZONE" "$KEYMAP" "$LOCALE"
  printf 'Actions: set locale/timezone/hostname, enable NetworkManager, create user, configure wheel sudo.\n'
  printf 'Passwords will be entered interactively in chroot. No disk formatting or bootloader changes.\n'
}

system_exec_apply() {
  local target=${1:-/mnt} confirmed=${2:-}
  [[ $EUID -eq 0 ]] || { echo 'Root required' >&2; return 1; }
  [[ ${LUCIOLE_ENABLE_EXPERIMENTAL_SYSTEM_APPLY:-0} == 1 ]] || { echo 'Experimental system apply is disabled' >&2; return 1; }
  [[ $confirmed == APPLY-SYSTEM-CONFIG ]] || { echo 'Explicit confirmation required' >&2; return 1; }
  [[ $target == /mnt ]] || { echo 'Only /mnt is supported in this patch' >&2; return 1; }
  system_exec_validate || return 1
  [[ -f $target/etc/os-release && -f $target/etc/passwd && -f $target/etc/locale.gen ]] || { echo 'No installed system detected' >&2; return 1; }
  [[ $(findmnt -rn -M "$target" -o SOURCE 2>/dev/null) == /dev/* ]] || { echo 'Target is not a mounted block filesystem' >&2; return 1; }
  [[ ! -e $target/etc/.luciole-b9.1-applied ]] || { echo 'Configuration already applied; refusing repeat' >&2; return 1; }
  [[ ! -e $target/etc/hostname || ! -s $target/etc/hostname ]] || { echo 'Existing hostname; refusing overwrite' >&2; return 1; }
  [[ ! -e $target/etc/locale.conf || ! -s $target/etc/locale.conf ]] || { echo 'Existing locale; refusing overwrite' >&2; return 1; }
  if arch-chroot "$target" id "$USERNAME" >/dev/null 2>&1; then echo 'Username already exists; refusing overwrite' >&2; return 1; fi
  arch-chroot "$target" test -x /usr/bin/locale-gen || return 1
  arch-chroot "$target" test -x /usr/bin/visudo || return 1
  arch-chroot "$target" test -x /usr/bin/NetworkManager || return 1
  arch-chroot "$target" test -f "/usr/share/zoneinfo/$TIMEZONE" || return 1
  # Values passed as environment arguments, not embedded in a shell command string.
  arch-chroot "$target" /usr/bin/env "LUCIOLE_HOSTNAME=$HOSTNAME" "LUCIOLE_USERNAME=$USERNAME" \
    "LUCIOLE_TIMEZONE=$TIMEZONE" "LUCIOLE_KEYMAP=$KEYMAP" "LUCIOLE_LOCALE=$LOCALE" \
    /bin/bash -s <<'CHROOT'
set -Eeuo pipefail
ln -sfn "/usr/share/zoneinfo/$LUCIOLE_TIMEZONE" /etc/localtime
hwclock --systohc
sed -i -E "s/^#[[:space:]]*(${LUCIOLE_LOCALE//./\.}[[:space:]]+UTF-8)/\1/" /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "$LUCIOLE_LOCALE" > /etc/locale.conf
printf 'KEYMAP=%s\n' "$LUCIOLE_KEYMAP" > /etc/vconsole.conf
printf '%s\n' "$LUCIOLE_HOSTNAME" > /etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$LUCIOLE_HOSTNAME" "$LUCIOLE_HOSTNAME" > /etc/hosts
useradd -m -G wheel -s /bin/bash "$LUCIOLE_USERNAME"
install -m 0440 /dev/null /etc/sudoers.d/10-luciole-wheel
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-luciole-wheel
visudo -cf /etc/sudoers
systemctl enable NetworkManager
printf '\nSet the root password:\n'
passwd
printf '\nSet the password for %s:\n' "$LUCIOLE_USERNAME"
passwd "$LUCIOLE_USERNAME"
touch /etc/.luciole-b9.1-applied
CHROOT
}

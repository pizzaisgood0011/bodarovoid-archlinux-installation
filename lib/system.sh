#!/usr/bin/env bash

# Configuration only; no system changes are made here.
KERNEL='linux'
FILESYSTEM='ext4'
BOOTLOADER='GRUB'
ENCRYPTION='none'
CPU='Auto'
GPU='Auto'
DESKTOP='Hyprland'
HOSTNAME=''
USERNAME=''
TIMEZONE=''
KEYMAP=''
LOCALE=''

system_valid_hostname() {
  [[ ${#1} -le 63 && $1 =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]
}

system_valid_username() {
  [[ $1 =~ ^[a-z_][a-z0-9_-]*$ && ${#1} -le 32 && $1 != root ]]
}

system_pick() {
  local variable=$1 title=$2 selection
  shift 2
  selection=$(ui_choose "$title" "$@") || return 0
  printf -v "$variable" '%s' "$selection"
}

system_edit_hostname() {
  local value
  value=$(gum input --header 'Hostname (letters, digits, hyphens)' --value "$HOSTNAME") || return 0
  if system_valid_hostname "$value"; then
    HOSTNAME=$value
  else
    ui_error 'Invalid hostname. Use 1-63 letters, digits, or hyphens; no leading/trailing hyphen.'
    ui_pause
  fi
}

system_edit_username() {
  local value
  value=$(gum input --header 'Username (lowercase letters, digits, _ or -)' --value "$USERNAME") || return 0
  if system_valid_username "$value"; then
    USERNAME=$value
  else
    ui_error 'Invalid username. Start with lowercase letter or underscore; max 32 characters; not root.'
    ui_pause
  fi
}

system_edit_timezone() {
  local value
  local -a zones=()
  if command -v timedatectl >/dev/null 2>&1; then
    mapfile -t zones < <(timedatectl list-timezones 2>/dev/null || true)
  fi
  if (( ${#zones[@]} == 0 )) && [[ -d /usr/share/zoneinfo ]]; then
    mapfile -t zones < <(
      find /usr/share/zoneinfo -type f -printf '%P\n' 2>/dev/null |
        grep -E '^[A-Za-z]+/' | sort -u || true
    )
  fi
  if (( ${#zones[@]} == 0 )); then
    ui_error 'No timezones found in the live environment.'
    ui_pause
    return 0
  fi
  value=$(
    printf '%s\n' "${zones[@]}" |
      gum filter --header 'Choose timezone (Esc to cancel)' \
        --placeholder 'Search timezone...' --height 15
  ) || return 0
  [[ -n $value ]] || return 0
  if [[ $value != /* && $value != *'..'* && -f /usr/share/zoneinfo/$value ]]; then
    TIMEZONE=$value
  else
    ui_error 'Selected timezone is unavailable.'
    ui_pause
  fi
}

system_edit_keymap() {
  local value
  local -a keymaps=()
  if command -v localectl >/dev/null 2>&1; then
    mapfile -t keymaps < <(localectl list-keymaps --no-pager 2>/dev/null || true)
  fi
  if (( ${#keymaps[@]} == 0 )) && [[ -d /usr/share/kbd/keymaps ]]; then
    mapfile -t keymaps < <(
      find /usr/share/kbd/keymaps -type f \( -name '*.map.gz' -o -name '*.map' -o -name '*.map.xz' \) \
        -printf '%f\n' 2>/dev/null |
        sed -E 's/\.map(\.gz|\.xz)?$//' | sort -u
    )
  fi
  if (( ${#keymaps[@]} == 0 )); then
    ui_error 'No console keymaps found.'
    ui_pause
    return 0
  fi
  value=$(
    printf '%s\n' "${keymaps[@]}" |
      gum filter --header 'Choose console keyboard layout (Esc to cancel)' \
        --placeholder 'Search keymap...' --height 15
  ) || return 0
  [[ -n $value ]] && KEYMAP=$value
}

system_edit_locale() {
  local value
  local -a locales=()
  if [[ -r /etc/locale.gen ]]; then
    mapfile -t locales < <(
      awk '
        /^[[:space:]]*#?[[:space:]]*[A-Za-z]/ {
          sub(/^[[:space:]]*#[[:space:]]*/, "")
          if ($2 == "UTF-8") print $1
        }
      ' /etc/locale.gen | sort -u
    )
  fi
  if (( ${#locales[@]} == 0 )); then
    ui_error 'No UTF-8 locale definitions found in /etc/locale.gen.'
    ui_pause
    return 0
  fi
  value=$(
    printf '%s\n' "${locales[@]}" |
      gum filter --header 'Choose system locale (Esc to cancel)' \
        --placeholder 'Search locale...' --height 15
  ) || return 0
  [[ -n $value ]] && LOCALE=$value
}

system_status() {
  printf 'Kernel:     %s\nFilesystem: %s\nBootloader: %s\nEncryption: %s\nCPU:        %s\nGPU:        %s\nDesktop:    %s\nHostname:   %s\nUsername:   %s\nTimezone:   %s\nKeymap:     %s\nLocale:     %s\n' \
    "$KERNEL" "$FILESYSTEM" "$BOOTLOADER" "$ENCRYPTION" "$CPU" "$GPU" "$DESKTOP" \
    "${HOSTNAME:-Not set}" "${USERNAME:-Not set}" "${TIMEZONE:-Not set}" "${KEYMAP:-Not set}" "${LOCALE:-Not set}"
}

system_menu() {
  local action selected
  while true; do
    ui_heading 'System Configuration'
    system_status
    printf '\n'
    action=$(ui_choose 'Choose a setting' \
      'Kernel' 'Filesystem' 'Bootloader' 'Encryption' 'CPU' 'GPU' 'Desktop' \
      'Hostname' 'Username' 'Timezone' 'Keyboard Layout' 'Locale' \
      'Detected Hardware' 'Back') || return 0
    case "$action" in
      Kernel) system_pick KERNEL 'Choose kernel' linux linux-lts linux-zen ;;
      Filesystem) system_pick FILESYSTEM 'Choose root filesystem' ext4 btrfs ;;
      Bootloader) system_pick BOOTLOADER 'Choose bootloader' GRUB Limine ;;
      Encryption) system_pick ENCRYPTION 'Root encryption' none luks2 ;;
      CPU) system_pick CPU 'Choose CPU' Auto AMD Intel ;;
      GPU) system_pick GPU 'Choose graphics' Auto AMD Intel NVIDIA None ;;
      Desktop)
        selected=$(ui_choose 'Choose desktop' Hyprland 'KDE Plasma' GNOME \
          'None (No Desktop Environment)') || continue
        if [[ $selected == 'None (No Desktop Environment)' ]]; then
          DESKTOP='none'
        else
          DESKTOP=$selected
        fi
        DESKTOP_INSTALL_TYPE=Minimal
        DESKTOP_EXTRA_SELECTED=()
        ;;
      Hostname) system_edit_hostname ;;
      Username) system_edit_username ;;
      Timezone) system_edit_timezone ;;
      'Keyboard Layout') system_edit_keymap ;;
      Locale) system_edit_locale ;;
      'Detected Hardware') hardware_menu ;;
      Back) return 0 ;;
    esac
  done
}

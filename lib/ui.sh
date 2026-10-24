#!/usr/bin/env bash

UI_ACCENT='#A78BFA'
UI_WARN='#EBCB8B'
UI_ERROR='#BF616A'

ui_heading() {
  clear
  gum style --foreground "$UI_ACCENT" --bold 'BODAROVOID / ARCH LINUX INSTALLER'
  printf '\n%s\n' "$1"
  printf '↑/↓ Navigate  •  Enter Select  •  Esc Back\n\n'
}

ui_choose() {
  local header=$1
  shift
  gum choose --header "$header" "$@"
}

ui_note() { gum style --foreground "$UI_WARN" "$1"; }
ui_error() { gum style --foreground "$UI_ERROR" "$1"; }
ui_pause() { gum input --placeholder 'Press Enter to continue' >/dev/null || true; }

ui_status() {
  printf 'Disk: %s\nEFI:  %s\nRoot: %s\nSwap: %s\n\n' \
    "${DISK:-Not selected}" "${EFI_PART:-Not selected}" \
    "${ROOT_PART:-Not selected}" "${SWAP_PART:-None}"
}

ui_step() {
  local current=$1 total=$2 label=$3
  printf '\n[%s/%s] %s\n' "$current" "$total" "$label"
}

ui_install_warning() {
  printf '\nIMPORTANT: This installer permanently formats the selected EFI, root and swap partitions.\n'
  printf 'LUKS2 encrypts root only; the separate swap and EFI remain unencrypted.\n'
  printf 'Disconnect unrelated drives and verify every device name before approval.\n'
}

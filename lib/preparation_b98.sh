#!/usr/bin/env bash
# B9.8: command preview only. Never execute generated commands.
B98_ERRORS=()
B98_COMMANDS=()

b98_validate() {
  B98_ERRORS=()
  B98_COMMANDS=()
  if ! declare -F b97_validate >/dev/null || ! b97_validate; then
    B98_ERRORS+=('B9.7 safety gates failed (settings, preflight, or target lock).')
    if declare -p B97_ERRORS &>/dev/null; then
      local error
      for error in "${B97_ERRORS[@]}"; do B98_ERRORS+=("$error"); done
    fi
  fi
  case "${FILESYSTEM:-}" in
    ext4) ;;
    *) B98_ERRORS+=("Unsupported filesystem for B9.8 preview: ${FILESYSTEM:-unset}. Only ext4 is modeled.") ;;
  esac
  case "${BOOTLOADER:-}" in
    GRUB|grub) ;;
    *) B98_ERRORS+=("Unsupported bootloader for B9.8 preview: ${BOOTLOADER:-unset}.") ;;
  esac
  [[ -n ${SWAP_PART:-} ]] || B98_ERRORS+=('B9.8 currently requires a selected swap partition.')
  if ((${#B98_ERRORS[@]})); then return 1; fi
  return 0
}

b98_build_commands() {
  b98_validate || return 1
  # printf %q ensures displayed shell arguments cannot inject commands.
  local efi root swap
  printf -v efi '%q' "$EFI_PART"
  printf -v root '%q' "$ROOT_PART"
  printf -v swap '%q' "$SWAP_PART"
  B98_COMMANDS=(
    "mkfs.ext4 $root"
    "# EFI filesystem policy deferred to B9.9.1 (never format automatically)"
    "mkswap $swap"
    "mount $root /mnt"
    "mkdir -p /mnt/boot/efi"
    "mount $efi /mnt/boot/efi"
    "swapon $swap"
  )
}

b98_report() {
  local cmd err
  printf 'B9.8 — FILESYSTEM COMMAND PREVIEW (READ ONLY)\n\n'
  if ! b98_build_commands; then
    printf 'BLOCKED — no command preview generated:\n'
    for err in "${B98_ERRORS[@]}"; do printf '  - %s\n' "$err"; done
    printf '\nNo disk changes were made.\n'
    return 1
  fi
  printf 'Target disk: %s\nEFI: %s\nRoot: %s\nSwap: %s\n\n' "$DISK" "$EFI_PART" "$ROOT_PART" "$SWAP_PART"
  printf 'WARNING: These commands would erase existing data on selected partitions if run manually.\n'
  printf 'Do NOT copy and execute them. This screen is for review only.\n\n'
  for cmd in "${B98_COMMANDS[@]}"; do printf '[NOT EXECUTED] %s\n' "$cmd"; done
  printf '\nPREVIEW COMPLETE — no changes made. Real installation remains DISABLED.\n'
}

b98_menu() {
  ui_heading 'B9.8 — Filesystem Preparation Preview (READ ONLY)'
  printf 'Review proposed filesystem commands; nothing will be executed.\n\n'
  local action
  action=$(ui_choose 'Choose an action' 'Review commands (read only)' 'Back') || return 0
  [[ $action == 'Review commands (read only)' ]] || return 0
  ui_heading 'B9.8 — Command Preview'
  b98_report || true
  ui_pause
}

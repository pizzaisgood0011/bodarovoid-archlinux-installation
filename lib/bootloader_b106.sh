#!/usr/bin/env bash
# B10.6: UEFI bootloader planning only. No commands are executed.
B106_ERRORS=()
B106_STEPS=()

b106_validate() {
  local mode=${1:-} kernel=${KERNEL:-} fs=${FILESYSTEM:-} loader=${BOOTLOADER:-}
  B106_ERRORS=() B106_STEPS=()
  if ! declare -F b105_validate >/dev/null || ! b105_validate "$mode"; then
    B106_ERRORS+=('B10.5 system configuration prerequisites failed or authorization rehearsal is stale.')
  fi
  case "$kernel" in linux|linux-lts|linux-zen) ;; *) B106_ERRORS+=('Unsupported kernel selection.') ;; esac
  case "$fs" in ext4|btrfs) ;; *) B106_ERRORS+=('Unsupported root filesystem.') ;; esac
  case "$loader" in GRUB|Limine) ;; *) B106_ERRORS+=('Unsupported bootloader selection.') ;; esac
  case "$mode" in create|reuse) ;; *) B106_ERRORS+=('EFI policy must be create or reuse.') ;; esac
  [[ -n ${EFI_PART:-} && -n ${ROOT_PART:-} && ${EFI_PART:-} != "${ROOT_PART:-}" ]] || B106_ERRORS+=('EFI/root partition selection is missing or overlaps.')
  ((${#B106_ERRORS[@]} == 0)) || return 1
  B106_STEPS+=(
    'Require verified UEFI boot, mounted EFI and root, and successful pacstrap/fstab/system configuration'
    'Resolve root UUID and EFI UUID from the actual mounted filesystems after formatting; never guess UUIDs'
    'Validate installed kernel image and initramfs paths; never assume an initramfs name without checking'
    'Keep EFI reuse non-destructive: never format EFI, overwrite unrelated boot files, or delete other OS entries'
  )
  if [[ $fs == btrfs ]]; then
    B106_STEPS+=('Validate Btrfs @ root subvolume and ensure boot configuration uses the correct rootflags=subvol=@')
  else
    B106_STEPS+=('Validate ext4 root UUID and omit Btrfs rootflags')
  fi
  if [[ $loader == GRUB ]]; then
    B106_STEPS+=(
      'Plan GRUB UEFI installation using the verified /boot/efi mount and a dedicated bootloader identifier'
      'Plan grub-mkconfig only after verifying the installed kernel and initramfs'
      'Check resulting EFI executable, GRUB configuration and firmware boot entry before claiming bootability'
    )
  else
    B106_STEPS+=(
      'Plan Limine UEFI EFI executable placement without overwriting other OS boot files'
      'Plan Limine configuration using verified kernel/initramfs paths, root UUID and filesystem-specific root flags'
      'Check installed Limine package layout and firmware boot-entry method before enabling execution'
      'Limine syntax and installation method require validation against the installed package version'
    )
  fi
  B106_STEPS+=(
    'Stop on any failure; do not claim a bootable system without a real reboot test'
    'No grub-install, grub-mkconfig, limine, efibootmgr, file writes, or disk operations execute in B10.6'
  )
}

b106_report() {
  local mode=${1:-} item
  printf 'B10.6 — UEFI BOOTLOADER INTEGRATION PLAN (READ ONLY)\n\n'
  if ! b106_validate "$mode"; then
    printf 'BLOCKED:\n'
    for item in "${B106_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI: %s\nRoot: %s\nEFI policy: %s\nFilesystem: %s\nKernel: %s\nBootloader: %s\n\n' \
    "$DISK" "$EFI_PART" "$ROOT_PART" "$mode" "$FILESYSTEM" "$KERNEL" "$BOOTLOADER"
  for item in "${B106_STEPS[@]}"; do printf '[PLAN ONLY] %s\n' "$item"; done
  printf '\nB10.6 PLAN COMPLETE — no bootloader installed, no EFI files written. Real installation DISABLED.\n'
}

b106_menu() {
  local choice mode
  ui_heading 'B10.6 — Bootloader Plan (READ ONLY)'
  choice=$(ui_choose 'Select same EFI policy as B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.6 — Bootloader Integration Plan'
  b106_report "$mode" || true
  ui_pause
}

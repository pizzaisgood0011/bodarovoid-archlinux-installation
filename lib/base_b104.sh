#!/usr/bin/env bash
# B10.4: read-only package and fstab plan. No installation commands execute.
B104_ERRORS=()
B104_PACKAGES=()
B104_STEPS=()

b104_cpu_vendor() {
  case ${CPU:-Auto} in
    AMD) printf 'amd-ucode' ;;
    Intel) printf 'intel-ucode' ;;
    Auto)
      local vendor
      vendor=$(awk -F: '/^vendor_id[[:space:]]*:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null) || return 1
      case $vendor in
        AuthenticAMD) printf 'amd-ucode' ;;
        GenuineIntel) printf 'intel-ucode' ;;
        *) return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}

b104_validate() {
  local mode=${1:-} microcode
  B104_ERRORS=() B104_PACKAGES=() B104_STEPS=()
  if ! declare -F b103_validate >/dev/null || ! b103_validate "$mode"; then
    B104_ERRORS+=('B10.3 mount plan prerequisites failed or authorization rehearsal is stale.')
  fi
  case ${KERNEL:-} in
    linux|linux-lts|linux-zen) ;;
    *) B104_ERRORS+=('Unsupported kernel selection.') ;;
  esac
  case ${FILESYSTEM:-} in
    ext4|btrfs) ;;
    *) B104_ERRORS+=('Unsupported root filesystem.') ;;
  esac
  case ${BOOTLOADER:-} in
    GRUB|Limine) ;;
    *) B104_ERRORS+=('Unsupported bootloader.') ;;
  esac
  if ! microcode=$(b104_cpu_vendor); then
    B104_ERRORS+=('CPU vendor could not be determined; choose AMD or Intel explicitly.')
  fi
  ((${#B104_ERRORS[@]} == 0)) || return 1
  B104_PACKAGES=(base "$KERNEL" linux-firmware "$microcode" networkmanager sudo vim)
  if [[ $FILESYSTEM == btrfs ]]; then B104_PACKAGES+=(btrfs-progs); fi
  if [[ $BOOTLOADER == GRUB ]]; then
    B104_PACKAGES+=(grub efibootmgr)
  else
    B104_PACKAGES+=(limine efibootmgr)
  fi
  B104_STEPS+=("Check pacstrap, genfstab, and package repository availability (not executed)")
  B104_STEPS+=("After verified mounting, install selected packages into /mnt (not executed)")
  B104_STEPS+=("Generate fstab from actual mounted UUIDs; review entries before writing (not executed)")
  B104_STEPS+=("Verify fstab root, EFI, swap and Btrfs subvolume entries as applicable")
  B104_STEPS+=("Stop on package download, signature, or installation errors; never proceed to bootloader")
  B104_STEPS+=("Bootloader configuration remains unimplemented; this is not a bootable installation")
}

b104_report() {
  local mode=${1:-} step
  printf 'B10.4 — BASE SYSTEM INSTALLATION PLAN (READ ONLY)\n\n'
  if ! b104_validate "$mode"; then
    printf 'BLOCKED:\n'
    for step in "${B104_ERRORS[@]}"; do printf '  - %s\n' "$step"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nKernel: %s\nCPU: %s\nFilesystem: %s\nBootloader: %s\nEFI policy: %s\n\n' "$DISK" "$KERNEL" "${CPU:-Auto}" "$FILESYSTEM" "$BOOTLOADER" "$mode"
  printf '[PLAN ONLY] pacstrap -K /mnt'
  printf ' %q' "${B104_PACKAGES[@]}"
  printf '\n'
  printf '[PLAN ONLY] genfstab -U /mnt (output to be reviewed before writing /mnt/etc/fstab)\n'
  for step in "${B104_STEPS[@]}"; do printf '[PLAN ONLY] %s\n' "$step"; done
  printf '\nB10.4 PLAN COMPLETE — no packages installed, no fstab written. Real installation DISABLED.\n'
}

b104_menu() {
  local choice mode
  ui_heading 'B10.4 — Base System Plan (READ ONLY)'
  choice=$(ui_choose 'Select same EFI policy as B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.4 — Package and fstab Plan'
  b104_report "$mode" || true
  ui_pause
}

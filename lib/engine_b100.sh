#!/usr/bin/env bash
# B10.0: read-only engine design. No command execution or authorization.
B100_ERRORS=()
B100_PLAN=()
B100_EFI_MODE=''

b100_validate() {
  local mode=${1:-} fs ptype
  B100_ERRORS=() B100_PLAN=()
  [[ $mode == create || $mode == reuse ]] || B100_ERRORS+=('Select EFI create or reuse explicitly.')
  [[ ${FILESYSTEM:-} == ext4 || ${FILESYSTEM:-} == btrfs ]] || B100_ERRORS+=('Unsupported root filesystem.')
  [[ ${BOOTLOADER:-} == GRUB || ${BOOTLOADER:-} == Limine ]] || B100_ERRORS+=('Unsupported bootloader.')
  if ! declare -F b97_validate >/dev/null || ! b97_validate; then
    B100_ERRORS+=('B9.7 prerequisite safety gates failed (settings, preflight, target lock).')
  fi
  [[ -n ${DISK:-} && -n ${EFI_PART:-} && -n ${ROOT_PART:-} && -n ${SWAP_PART:-} ]] || B100_ERRORS+=('Disk, EFI, root and swap are required for B10.0.')
  if [[ -n ${EFI_PART:-} && -n ${ROOT_PART:-} && -n ${SWAP_PART:-} ]]; then
    [[ $EFI_PART != "$ROOT_PART" && $EFI_PART != "$SWAP_PART" && $ROOT_PART != "$SWAP_PART" ]] || B100_ERRORS+=('Partition roles must not overlap.')
  fi
  if [[ -n ${EFI_PART:-} ]]; then
    ptype=$(lsblk -dn -o PARTTYPE -- "$EFI_PART" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    [[ $ptype == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] || B100_ERRORS+=('EFI partition does not have the UEFI ESP partition type.')
    fs=$(blkid -p -s TYPE -o value -- "$EFI_PART" 2>/dev/null || true)
    if [[ $mode == reuse ]]; then
      [[ $fs == vfat ]] || B100_ERRORS+=('EFI reuse requires existing vfat signature.')
    elif [[ $mode == create ]]; then
      [[ -z $fs ]] || B100_ERRORS+=('EFI creation preview requires no detected filesystem signature.')
    fi
  fi
  ((${#B100_ERRORS[@]} == 0)) || return 1
  B100_PLAN=(
    "Disk: $DISK"
    "EFI: $EFI_PART ($mode; create is destructive, reuse preserves filesystem)"
    "Root: $ROOT_PART (${FILESYSTEM}; destructive in future)"
    "Swap: $SWAP_PART (destructive in future)"
    "Bootloader: $BOOTLOADER"
    "Root layout: $([[ $FILESYSTEM == btrfs ]] && printf 'Btrfs subvolume layout NOT YET SPECIFIED' || printf 'single ext4 filesystem')"
    "Boot integration: $([[ $BOOTLOADER == Limine ]] && printf 'Limine UEFI integration NOT YET IMPLEMENTED' || printf 'GRUB UEFI integration NOT YET IMPLEMENTED')"
    'All four combinations are DESIGN TARGETS, not approved installation paths.'
    'No commands are executed. No installation authorization is granted.'
  )
}

b100_report() {
  local mode=${1:-} item
  printf 'B10.0 — INSTALLATION ENGINE FOUNDATION (READ ONLY)\n\n'
  if ! b100_validate "$mode"; then
    printf 'BLOCKED:\n'
    for item in "${B100_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  for item in "${B100_PLAN[@]}"; do printf '[PLAN ONLY] %s\n' "$item"; done
  printf '\nENGINE FOUNDATION READY FOR REVIEW — real installation DISABLED.\n'
}

b100_menu() {
  local choice mode
  ui_heading 'B10.0 — Engine Foundation (READ ONLY)'
  choice=$(ui_choose 'Choose EFI policy for this read-only plan' 'Create new EFI (no detected filesystem)' 'Reuse existing EFI (vfat)' 'Back') || return 0
  case "$choice" in
    'Create new EFI (no detected filesystem)') mode=create ;;
    'Reuse existing EFI (vfat)') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.0 — Engine Plan'
  b100_report "$mode" || true
  ui_pause
}

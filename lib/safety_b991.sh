#!/usr/bin/env bash
# B9.9.1 — read-only EFI creation/reuse policy; never writes to disks.
B991_ERRORS=()
B991_PLAN=()
B991_MODE=''

b991_efi_type() {
  blkid -p -s TYPE -o value -- "$EFI_PART" 2>/dev/null || true
}

b991_efi_parttype() {
  lsblk -dn -o PARTTYPE -- "$EFI_PART" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
}

b991_validate() {
  local mode="${1:-}" fs='' ptype=''
  B991_ERRORS=() B991_PLAN=()
  if [[ $mode != create && $mode != reuse ]]; then
    B991_ERRORS+=('Choose CREATE NEW EFI or REUSE EXISTING EFI explicitly.')
    return 1
  fi
  if ! declare -F b98_validate >/dev/null || ! b98_validate; then
    B991_ERRORS+=('B9.8 prerequisite gates failed (including target lock).')
    if declare -p B98_ERRORS &>/dev/null; then
      local err
      for err in "${B98_ERRORS[@]}"; do B991_ERRORS+=("B9.8: $err"); done
    fi
  fi
  if [[ -z ${DISK:-} || -z ${EFI_PART:-} || -z ${ROOT_PART:-} || -z ${SWAP_PART:-} ]]; then
    B991_ERRORS+=('Disk, EFI, root and swap must all be selected.')
    return 1
  fi
  if [[ $EFI_PART == "$ROOT_PART" || $EFI_PART == "$SWAP_PART" || $ROOT_PART == "$SWAP_PART" ]]; then
    B991_ERRORS+=('EFI, root and swap partitions must be distinct.')
  fi
  ptype=$(b991_efi_parttype) || ptype=''
  if [[ $ptype != c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]]; then
    B991_ERRORS+=("EFI partition type is not the UEFI ESP GUID (detected: ${ptype:-unknown}).")
  fi
  fs=$(b991_efi_type)
  if [[ $mode == reuse ]]; then
    [[ $fs == vfat ]] || B991_ERRORS+=("REUSE requires an existing vfat filesystem; detected: ${fs:-unknown}.")
  else
    # A blank signature is a prerequisite, not proof that a partition is empty.
    [[ -z $fs ]] || B991_ERRORS+=("CREATE requires no detected filesystem; detected: $fs. Existing filesystems are never silently overwritten.")
  fi
  ((${#B991_ERRORS[@]} == 0)) || return 1
  if [[ $mode == reuse ]]; then
    B991_PLAN+=("PRESERVE EFI $EFI_PART (reuse vfat; NEVER format)")
  else
    B991_PLAN+=("CREATE NEW EFI FILESYSTEM on $EFI_PART (DESTRUCTIVE in future release; not executed)")
  fi
  B991_PLAN+=(
    "ERASE ROOT $ROOT_PART (future action only)"
    "ERASE SWAP $SWAP_PART (future action only)"
    "MOUNT EFI $EFI_PART at /mnt/boot/efi (future action only)"
    'NO writes, no formatting, no mounting, no installation authorization'
  )
}

b991_report() {
  local mode="${1:-}" line
  printf 'B9.9.1 — EFI CREATION VS REUSE (READ ONLY)\n\n'
  if ! b991_validate "$mode"; then
    printf 'BLOCKED:\n'
    for line in "${B991_ERRORS[@]}"; do printf '  - %s\n' "$line"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI: %s\nRoot: %s\nSwap: %s\nMode: %s\n\n' "$DISK" "$EFI_PART" "$ROOT_PART" "$SWAP_PART" "$mode"
  for line in "${B991_PLAN[@]}"; do printf '[POLICY ONLY] %s\n' "$line"; done
  printf '\nWARNING: A future CREATE action could destroy EFI boot files.\n'
  printf 'Filesystem signature detection does not prove that a partition is unused.\n'
  printf 'Future writes require fresh disk identity checks and separate explicit authorization.\n'
  printf '\nREVIEW COMPLETE — no changes made. Real installation remains DISABLED.\n'
}

b991_menu() {
  local choice mode phrase
  ui_heading 'B9.9.1 — EFI Creation vs Reuse (READ ONLY)'
  choice=$(ui_choose 'Choose EFI policy to review' 'Create new EFI (empty filesystem signature only)' 'Reuse existing EFI (preserve vfat)' 'Back') || return 0
  case "$choice" in
    'Create new EFI (empty filesystem signature only)') mode=create ;;
    'Reuse existing EFI (preserve vfat)') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B9.9.1 — EFI Safety Review'
  if ! b991_report "$mode"; then ui_pause; return 0; fi
  printf '\nAcknowledgment is not permission to write.\n'
  phrase=$(gum input --header 'Type REVIEW ONLY to acknowledge') || return 0
  if [[ $phrase == 'REVIEW ONLY' ]]; then
    ui_note 'Review acknowledged. No installation authorization granted.'
  else
    ui_note 'Review canceled.'
  fi
  ui_pause
}

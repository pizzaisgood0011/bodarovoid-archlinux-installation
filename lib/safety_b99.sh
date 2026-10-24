#!/usr/bin/env bash
# B9.9 is a read-only safety review. Never authorize or execute writes.
B99_ERRORS=()
B99_PLAN=()
B99_REVIEWED=0

b99_efi_type() {
  blkid -s TYPE -o value -- "$EFI_PART" 2>/dev/null
}

b99_validate() {
  B99_ERRORS=()
  B99_PLAN=()
  B99_REVIEWED=0
  if ! declare -F b98_validate >/dev/null || ! b98_validate; then
    B99_ERRORS+=('B9.8 prerequisite gates failed.')
    if declare -p B98_ERRORS &>/dev/null; then
      local err
      for err in "${B98_ERRORS[@]}"; do B99_ERRORS+=("B9.8: $err"); done
    fi
  fi
  # EFI is ALWAYS preserved in B9.9; reformatting requires a future separate design.
  local fs=''
  if [[ -z ${EFI_PART:-} ]]; then
    B99_ERRORS+=('EFI partition is not selected.')
  else
    fs=$(b99_efi_type) || fs=''
    [[ $fs == vfat ]] || B99_ERRORS+=("EFI partition must already be FAT32/vfat; detected: ${fs:-unknown}. Never format it automatically.")
  fi
  [[ -n ${ROOT_PART:-} && -n ${SWAP_PART:-} && -n ${EFI_PART:-} ]] || B99_ERRORS+=('Root, swap and EFI must all be selected.')
  if [[ -n ${ROOT_PART:-} && -n ${SWAP_PART:-} && -n ${EFI_PART:-} ]]; then
    [[ $ROOT_PART != "$EFI_PART" && $SWAP_PART != "$EFI_PART" && $ROOT_PART != "$SWAP_PART" ]] || B99_ERRORS+=('Partitions must be distinct.')
  fi
  ((${#B99_ERRORS[@]} == 0)) || return 1
  B99_PLAN=(
    "PRESERVE EFI $EFI_PART (existing FAT filesystem; NEVER format)"
    "ERASE ROOT $ROOT_PART (ext4 creation would destroy existing data)"
    "ERASE SWAP $SWAP_PART (swap initialization would destroy existing data)"
    "MOUNT ROOT $ROOT_PART at /mnt (future stage only)"
    "MOUNT EFI $EFI_PART at /mnt/boot/efi (future stage only)"
    'NO disk partition table edits; NO EFI format; NO real installation'
  )
}

b99_report() {
  local item
  printf 'B9.9 — PARTITION SAFETY POLICY (READ ONLY)\n\n'
  if ! b99_validate; then
    printf 'BLOCKED:\n'
    for item in "${B99_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Target: %s\nEFI: %s\nRoot: %s\nSwap: %s\n\n' "$DISK" "$EFI_PART" "$ROOT_PART" "$SWAP_PART"
  for item in "${B99_PLAN[@]}"; do printf '[POLICY ONLY] %s\n' "$item"; done
  printf '\nIMPORTANT: EFI files belonging to other operating systems must be preserved.\n'
  printf 'A future real installer must back up data, check mount/swap state, revalidate\n'
  printf 'identities immediately before writes, and obtain new explicit authorization.\n'
  printf '\nREVIEW COMPLETE — no changes made. Real installation remains DISABLED.\n'
}

b99_menu() {
  ui_heading 'B9.9 — Partition Safety Policy (READ ONLY)'
  local action phrase
  action=$(ui_choose 'Choose an action' 'Review partition safety policy' 'Back') || return 0
  [[ $action == 'Review partition safety policy' ]] || return 0
  ui_heading 'B9.9 — Safety Review'
  if ! b99_report; then ui_pause; return 0; fi
  printf '\nThis is only an acknowledgment of the preview, NOT permission to write.\n'
  phrase=$(gum input --header 'Type REVIEW ONLY to acknowledge the preview') || return 0
  if [[ $phrase == 'REVIEW ONLY' ]]; then
    B99_REVIEWED=1
    ui_note 'Preview acknowledged for this screen only. No installation authorization granted.'
  else
    ui_note 'Preview acknowledgment cancelled.'
  fi
  ui_pause
}

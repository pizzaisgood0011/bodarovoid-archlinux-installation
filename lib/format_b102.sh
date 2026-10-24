#!/usr/bin/env bash
# B10.2: filesystem operation builder. NO execution path exists in this module.
B102_ERRORS=()
B102_OPERATIONS=()

b102_validate() {
  local mode=${1:-} dev fstype
  B102_ERRORS=() B102_OPERATIONS=()
  if ! declare -F b101_rehearsal_valid >/dev/null || ! b101_rehearsal_valid "$mode"; then
    B102_ERRORS+=('B10.1 rehearsal is missing or stale. Repeat B10.1 for this exact configuration.')
  fi
  if ! declare -F b95_is_approved >/dev/null || ! b95_is_approved; then
    B102_ERRORS+=('Target identity lock is missing or stale.')
  fi
  [[ $mode == create || $mode == reuse ]] || B102_ERRORS+=('Unknown EFI policy.')
  [[ ${FILESYSTEM:-} == ext4 || ${FILESYSTEM:-} == btrfs ]] || B102_ERRORS+=('Unsupported root filesystem.')
  [[ -n ${DISK:-} && -n ${EFI_PART:-} && -n ${ROOT_PART:-} && -n ${SWAP_PART:-} ]] || B102_ERRORS+=('All target partitions must be selected.')
  if ((${#B102_ERRORS[@]})); then return 1; fi
  # A dry-run must still reject targets in use. No writes occur regardless.
  for dev in "$DISK" "$EFI_PART" "$ROOT_PART" "$SWAP_PART"; do
    [[ -b $dev ]] || { B102_ERRORS+=("Missing block device: $dev"); continue; }
    if lsblk -nr -o MOUNTPOINTS -- "$dev" 2>/dev/null | grep -q '[^[:space:]]'; then
      B102_ERRORS+=("Device or descendant is mounted: $dev")
    fi
  done
  if [[ -b ${SWAP_PART:-/nonexistent} ]] && swapon --noheadings --raw --show=NAME 2>/dev/null | grep -Fxq -- "$(readlink -f -- "$SWAP_PART")"; then
    B102_ERRORS+=("Selected swap partition is active: $SWAP_PART")
  fi
  if ((${#B102_ERRORS[@]})); then return 1; fi
  if [[ $mode == create ]]; then
    B102_OPERATIONS+=("mkfs.fat -F 32 -- $EFI_PART")
  else
    B102_OPERATIONS+=("PRESERVE EFI: $EFI_PART (no mkfs)")
  fi
  case "$FILESYSTEM" in
    ext4) B102_OPERATIONS+=("mkfs.ext4 -- $ROOT_PART") ;;
    btrfs) B102_OPERATIONS+=("mkfs.btrfs -- $ROOT_PART") ;;
  esac
  B102_OPERATIONS+=("mkswap -- $SWAP_PART")
  return 0
}

b102_report() {
  local mode=${1:-} op
  printf 'B10.2 — FORMATTING EXECUTOR DESIGN (READ ONLY)\n\n'
  if ! b102_validate "$mode"; then
    printf 'BLOCKED:\n'
    for op in "${B102_ERRORS[@]}"; do printf '  - %s\n' "$op"; done
    printf '\nNo operations executed.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI policy: %s\nFilesystem: %s\n\n' "$DISK" "$mode" "$FILESYSTEM"
  for op in "${B102_OPERATIONS[@]}"; do printf '[NOT EXECUTED] %s\n' "$op"; done
  printf '\nB10.2 REVIEW COMPLETE — no writes performed. Formatting executor DISABLED.\n'
}

b102_menu() {
  local mode choice
  ui_heading 'B10.2 — Formatting Engine Design (READ ONLY)'
  choice=$(ui_choose 'Select the same EFI policy rehearsed in B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.2 — Formatting Operations Preview'
  b102_report "$mode" || true
  ui_pause
}

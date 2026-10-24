#!/usr/bin/env bash
# B10.1: ephemeral authorization rehearsal only. No write capability.
B101_ERRORS=()
B101_REHEARSAL_FINGERPRINT=''
B101_REHEARSAL_SNAPSHOT=''
B101_REHEARSAL_MODE=''

b101_snapshot() {
  printf '%s\\0' "${DISK:-}" "${EFI_PART:-}" "${ROOT_PART:-}" "${SWAP_PART:-}" "${FILESYSTEM:-}" "${BOOTLOADER:-}" "${1:-}" "$(b93_snapshot)" | sha256sum | cut -d' ' -f1
}

b101_validate() {
  local mode=${1:-} fp
  B101_ERRORS=()
  if ! declare -F b100_validate >/dev/null || ! b100_validate "$mode"; then
    B101_ERRORS+=('B10.0 installation plan validation failed.')
  fi
  if ! declare -F b95_is_approved >/dev/null || ! b95_is_approved; then
    B101_ERRORS+=('Target lock missing or stale.')
  fi
  fp=$(b95_fingerprint) || B101_ERRORS+=('Cannot recheck disk identity.')
  [[ -n $fp ]] || B101_ERRORS+=('Disk identity fingerprint unavailable.')
  ((${#B101_ERRORS[@]} == 0))
}

b101_rehearsal_valid() {
  local mode=${1:-}
  [[ -n $B101_REHEARSAL_FINGERPRINT && -n $B101_REHEARSAL_SNAPSHOT && $mode == "$B101_REHEARSAL_MODE" ]] || return 1
  b101_validate "$mode" || return 1
  [[ $(b95_fingerprint) == "$B101_REHEARSAL_FINGERPRINT" && $(b101_snapshot "$mode") == "$B101_REHEARSAL_SNAPSHOT" ]]
}

b101_rehearse() {
  local mode=${1:-} phrase=${2:-} fp snapshot
  B101_REHEARSAL_FINGERPRINT='' B101_REHEARSAL_SNAPSHOT='' B101_REHEARSAL_MODE=''
  b101_validate "$mode" || return 1
  [[ $phrase == "REHEARSE ${DISK} ONLY" ]] || return 1
  fp=$(b95_fingerprint) || return 1
  snapshot=$(b101_snapshot "$mode") || return 1
  b101_validate "$mode" || return 1
  [[ $(b95_fingerprint) == "$fp" && $(b101_snapshot "$mode") == "$snapshot" ]] || return 1
  B101_REHEARSAL_FINGERPRINT=$fp
  B101_REHEARSAL_SNAPSHOT=$snapshot
  B101_REHEARSAL_MODE=$mode
  return 0
}

b101_menu() {
  local choice mode phrase
  ui_heading 'B10.1 — Authorization Rehearsal (READ ONLY)'
  choice=$(ui_choose 'Choose EFI policy to rehearse' 'Create new EFI (no detected filesystem)' 'Reuse existing EFI (vfat)' 'Back') || return 0
  case "$choice" in
    'Create new EFI (no detected filesystem)') mode=create ;;
    'Reuse existing EFI (vfat)') mode=reuse ;;
    *) return 0 ;;
  esac
  if ! b101_validate "$mode"; then
    printf 'BLOCKED:\n'; printf '  - %s\n' "${B101_ERRORS[@]}"
    ui_pause; return 0
  fi
  ui_heading 'B10.1 — Authorization Rehearsal'
  printf 'Disk: %s\nEFI: %s (%s)\nRoot: %s (%s)\nSwap: %s\nBootloader: %s\n\n' \
    "$DISK" "$EFI_PART" "$mode" "$ROOT_PART" "$FILESYSTEM" "$SWAP_PART" "$BOOTLOADER"
  printf 'This is a NON-AUTHORIZING REHEARSAL. No disk writes are enabled.\n'
  printf 'Future formatting of root/swap and CREATE EFI would destroy data.\n\n'
  phrase=$(gum input --header "Type REHEARSE ${DISK} ONLY") || return 0
  if b101_rehearse "$mode" "$phrase" && b101_rehearsal_valid "$mode"; then
    ui_note 'REHEARSAL PASSED — no installation authorization granted. Real installation DISABLED.'
  else
    ui_error 'REHEARSAL BLOCKED — selection changed, verification failed, or confirmation incorrect.'
  fi
  ui_pause
}

#!/usr/bin/env bash
# Stage B1: rehearse exact-device approval. Absolutely no filesystem writes.
FORMAT_REVIEW_ERRORS=()
FORMAT_REVIEW_DISK=''
FORMAT_REVIEW_SNAPSHOTS=()

format_review_snapshot() {
  local dev=$1 real type size majmin partuuid parttype fs sig
  [[ -n $dev && -b $dev ]] || return 1
  real=$(readlink -f -- "$dev") || return 1
  type=$(lsblk -dn -o TYPE -- "$dev" 2>/dev/null | xargs) || return 1
  size=$(lsblk -bdn -o SIZE -- "$dev" 2>/dev/null | xargs) || return 1
  majmin=$(lsblk -dn -o MAJ:MIN -- "$dev" 2>/dev/null | xargs) || return 1
  partuuid=$(lsblk -dn -o PARTUUID -- "$dev" 2>/dev/null | xargs) || return 1
  parttype=$(lsblk -dn -o PARTTYPE -- "$dev" 2>/dev/null | xargs) || return 1
  fs=$(lsblk -dn -o FSTYPE -- "$dev" 2>/dev/null | xargs) || return 1
  command -v wipefs >/dev/null 2>&1 || return 1
  sig=$(wipefs -n --noheadings --output OFFSET,TYPE -- "$dev" 2>/dev/null) || return 1
  printf '%s|%s|%s|%s|%s|%s|%s|%s' "$real" "$type" "$size" "$majmin" "$partuuid" "$parttype" "$fs" "$sig"
}

format_review_capture() {
  FORMAT_REVIEW_ERRORS=()
  FORMAT_REVIEW_SNAPSHOTS=()
  FORMAT_REVIEW_DISK=$(safety_disk_fingerprint "$DISK") || {
    FORMAT_REVIEW_ERRORS+=('Cannot capture disk identity.')
    return 1
  }
  local dev snap
  for dev in "$EFI_PART" "$ROOT_PART" "${SWAP_PART:-}"; do
    [[ -n $dev ]] || continue
    snap=$(format_review_snapshot "$dev") || {
      FORMAT_REVIEW_ERRORS+=("Cannot inspect partition: $dev")
      return 1
    }
    FORMAT_REVIEW_SNAPSHOTS+=("$dev=$snap")
  done
}

format_review_unchanged() {
  local current snap dev expected
  current=$(safety_disk_fingerprint "$DISK") || return 1
  [[ $current == "$FORMAT_REVIEW_DISK" && $current == "${SAFETY_DISK_FINGERPRINT:-}" ]] || return 1
  for snap in "${FORMAT_REVIEW_SNAPSHOTS[@]}"; do
    dev=${snap%%=*}
    expected=${snap#*=}
    current=$(format_review_snapshot "$dev") || return 1
    [[ $current == "$expected" ]] || return 1
  done
}

format_review_menu() {
  packages_build_plan
  preflight_run
  ui_heading 'Formatting Approval Rehearsal (NO WRITES)'
  printf 'Target: %s\nEFI policy: %s\n\n' "${DISK:-none}" "$EFI_FORMAT_POLICY"
  printf '%s\n' "${FORMAT_OPERATIONS[@]}"
  printf '\nPreflight: %d blocking errors, %d warnings\n' "${#PREFLIGHT_ERRORS[@]}" "${#PREFLIGHT_WARNINGS[@]}"
  local issue
  for issue in "${PREFLIGHT_ERRORS[@]}"; do printf 'ERROR: %s\n' "$issue"; done
  if ((${#PREFLIGHT_ERRORS[@]})); then
    ui_error 'BLOCKED: fix preflight errors first.'
    ui_pause
    return 0
  fi
  if [[ $EFI_FORMAT_POLICY != preserve && $EFI_FORMAT_POLICY != new-fat32 ]]; then
    ui_error 'BLOCKED: EFI policy unresolved.'
    ui_pause
    return 0
  fi
  if ! format_review_capture; then
    printf '%s\n' "${FORMAT_REVIEW_ERRORS[@]}"
    ui_error 'BLOCKED: device identity capture failed.'
    ui_pause
    return 0
  fi
  printf '\nThis rehearses destructive approval but NEVER executes formatting.\n'
  if ! gum confirm 'Review these exact partition operations?'; then
    ui_note 'Cancelled before approval.'
    ui_pause
    return 0
  fi
  local typed
  typed=$(gum input --prompt 'Type target disk path to approve: ' --placeholder "$DISK") || return 0
  if [[ $typed != "$DISK" ]]; then
    ui_error 'Approval rejected: target disk did not match.'
    ui_pause
    return 0
  fi
  typed=$(gum input --prompt 'Type ERASE to confirm rehearsal: ') || return 0
  if [[ $typed != ERASE ]]; then
    ui_error 'Approval rejected: ERASE was not entered.'
    ui_pause
    return 0
  fi
  # Re-evaluate all policy and active-use checks after approval.
  preflight_run
  if ((${#PREFLIGHT_ERRORS[@]})) || ! format_review_unchanged; then
    ui_error 'BLOCKED: preflight or device identity changed after approval.'
    ui_pause
    return 0
  fi
  printf '\n'
  ui_note 'REHEARSAL PASSED: approval and identity recheck completed.'
  ui_error 'EXECUTION DISABLED: no mkfs, mkswap, mount, or pacstrap was called.'
  ui_pause
}

#!/usr/bin/env bash
# B10.8: independent read-only execution-readiness rehearsal.
# This module must never authorize or execute disk writes.
B108_ERRORS=()
B108_CONFIRMATION_FINGERPRINT=''
B108_CONFIRMATION_SNAPSHOT=''
B108_CONFIRMATION_MODE=''

b108_check() {
  local mode=${1:-} disk=${DISK:-} dev name mounted active ro
  local -a devices=()
  B108_ERRORS=()
  if ! declare -F b107_validate >/dev/null || ! b107_validate "$mode"; then
    B108_ERRORS+=('B10.7 planning audit is missing, blocked, or stale.')
  fi
  if ! declare -F b101_rehearsal_valid >/dev/null || ! b101_rehearsal_valid "$mode"; then
    B108_ERRORS+=('B10.1 authorization rehearsal is missing or stale.')
  fi
  if ! declare -F b95_is_approved >/dev/null || ! b95_is_approved; then
    B108_ERRORS+=('B9.5 target identity lock is missing or stale.')
  fi
  [[ -n $disk && -b $disk ]] || B108_ERRORS+=('Selected disk is not a block device.')
  if [[ -n $disk && -b $disk ]]; then
    if [[ $(lsblk -dn -o TYPE -- "$disk" 2>/dev/null) != disk ]]; then
      B108_ERRORS+=('Selected target is not a whole disk.')
    fi
    ro=$(lsblk -dn -o RO -- "$disk" 2>/dev/null) || ro=''
    [[ $ro == 0 ]] || B108_ERRORS+=('Selected disk is read-only or its state is unknown.')
    # Include all descendants, not only the three selected partitions.
    mapfile -t devices < <(lsblk -nrpo NAME -- "$disk" 2>/dev/null)
    ((${#devices[@]} > 0)) || B108_ERRORS+=('Could not enumerate disk descendants.')
    for dev in "${devices[@]}"; do
      [[ -b $dev ]] || { B108_ERRORS+=("Device disappeared: $dev"); continue; }
      # lsblk MOUNTPOINTS covers mounts not shown by a single MOUNTPOINT.
      mounted=$(lsblk -dn -o MOUNTPOINTS -- "$dev" 2>/dev/null) || mounted='UNKNOWN'
      [[ -z ${mounted//[[:space:]]/} ]] || B108_ERRORS+=("Mounted or unverifiable device: $dev")
    done
    if ! command -v swapon >/dev/null 2>&1; then
      B108_ERRORS+=('Cannot inspect active swap: swapon unavailable.')
    else
      active=$(swapon --show=NAME --noheadings --raw 2>/dev/null) || {
        B108_ERRORS+=('Cannot inspect active swap.')
        active=''
      }
      for dev in "${devices[@]}"; do
        while IFS= read -r name; do
          [[ -z $name ]] && continue
          if [[ $(readlink -f -- "$name" 2>/dev/null) == "$(readlink -f -- "$dev" 2>/dev/null)" ]]; then
            B108_ERRORS+=("Active swap on selected disk: $dev")
          fi
        done <<< "$active"
      done
    fi
  fi
  ((${#B108_ERRORS[@]} == 0))
}

b108_rehearse() {
  local mode=${1:-} phrase=${2:-} fp snap
  B108_CONFIRMATION_FINGERPRINT=''
  B108_CONFIRMATION_SNAPSHOT=''
  B108_CONFIRMATION_MODE=''
  b108_check "$mode" || return 1
  [[ $phrase == "CHECK ${DISK} ONLY" ]] || return 1
  fp=$(b95_fingerprint) || return 1
  snap=$(b101_snapshot "$mode") || return 1
  b108_check "$mode" || return 1
  [[ $(b95_fingerprint) == "$fp" && $(b101_snapshot "$mode") == "$snap" ]] || return 1
  B108_CONFIRMATION_FINGERPRINT=$fp
  B108_CONFIRMATION_SNAPSHOT=$snap
  B108_CONFIRMATION_MODE=$mode
}

b108_report() {
  local mode=${1:-} err
  printf 'B10.8 — CONTROLLED EXECUTION READINESS (READ ONLY)\n\n'
  if ! b108_check "$mode"; then
    printf 'BLOCKED:\n'
    for err in "${B108_ERRORS[@]}"; do printf '  - %s\n' "$err"; done
    printf '\nEXECUTION NOT READY. No changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI: %s (%s)\nRoot: %s\nSwap: %s\n\n' \
    "$DISK" "$EFI_PART" "$mode" "$ROOT_PART" "${SWAP_PART:-none}"
  printf '[CHECK ONLY] Planning gates and rehearsal match current selection\n'
  printf '[CHECK ONLY] Disk is writable and no descendant mountpoints or active swap were detected\n'
  printf '[CHECK ONLY] Disk identity and configuration will be checked again after confirmation\n'
  printf '[LIMITATION] This check does not detect every holder, open file, RAID/LVM dependency or firmware hazard\n'
  printf '[LIMITATION] A check-to-use race remains; a future executor needs stronger independent guards\n'
  printf '[LIMITATION] Successful rehearsal does not prove a device is safe to erase\n'
  printf '\nREADINESS CHECK PASSED — EXECUTION STILL DISABLED. No changes made.\n'
}

b108_menu() {
  local choice mode phrase
  ui_heading 'B10.8 — Execution Readiness (READ ONLY)'
  choice=$(ui_choose 'Select the same EFI policy as B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.8 — Readiness Audit'
  if ! b108_report "$mode"; then ui_pause; return 0; fi
  printf '\nThis is a READ-ONLY confirmation rehearsal. No formatting permission is granted.\n'
  phrase=$(gum input --header "Type CHECK ${DISK} ONLY") || return 0
  if b108_rehearse "$mode" "$phrase"; then
    ui_note 'B10.8 REHEARSAL PASSED — no disk-write authorization granted. Real installation DISABLED.'
  else
    ui_error 'B10.8 BLOCKED — invalid confirmation or state changed.'
  fi
  ui_pause
}

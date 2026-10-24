#!/usr/bin/env bash
# B10.9: read-only independent pre-write guard rehearsal. NEVER authorizes writes.
B109_ERRORS=()
B109_FINGERPRINT=''
B109_SNAPSHOT=''
B109_MODE=''

b109_check() {
  local mode=${1:-} disk=${DISK:-} dev key entry holder parent actual
  local -a devices=()
  B109_ERRORS=()
  if ! declare -F b108_check >/dev/null || ! b108_check "$mode"; then
    B109_ERRORS+=('B10.8 readiness is missing, blocked, or stale.')
  fi
  # Require successful B10.8 confirmation in the same running shell/session.
  if [[ -z ${B108_CONFIRMATION_FINGERPRINT:-} || -z ${B108_CONFIRMATION_SNAPSHOT:-} || ${B108_CONFIRMATION_MODE:-} != "$mode" ]]; then
    B109_ERRORS+=('B10.8 confirmation rehearsal is missing or policy differs.')
  elif ! declare -F b95_fingerprint >/dev/null || ! declare -F b101_snapshot >/dev/null ||
       [[ $(b95_fingerprint 2>/dev/null) != "$B108_CONFIRMATION_FINGERPRINT" ]] ||
       [[ $(b101_snapshot "$mode" 2>/dev/null) != "$B108_CONFIRMATION_SNAPSHOT" ]]; then
    B109_ERRORS+=('B10.8 confirmation is stale: disk or configuration changed.')
  fi
  [[ -n $disk && -b $disk ]] || { B109_ERRORS+=('No valid block disk selected.'); return 1; }
  # A failure to enumerate or inspect any device fails closed.
  if ! command -v lsblk >/dev/null 2>&1; then
    B109_ERRORS+=('lsblk unavailable.')
    return 1
  fi
  local listing
  listing=$(lsblk -nrpo NAME -- "$disk" 2>/dev/null) || {
    B109_ERRORS+=('Cannot enumerate target disk descendants.')
    return 1
  }
  mapfile -t devices <<< "$listing"
  ((${#devices[@]} > 0)) || B109_ERRORS+=('Empty target device enumeration.')
  [[ ${devices[0]:-} == "$disk" ]] || B109_ERRORS+=('Disk enumeration does not begin with selected disk.')
  [[ -r /proc/self/mountinfo && -r /proc/swaps ]] || B109_ERRORS+=('Kernel mount/swap inspection unavailable.')
  for dev in "${devices[@]}"; do
    [[ -b $dev ]] || { B109_ERRORS+=("Device vanished: $dev"); continue; }
    key=$(lsblk --raw -dn -o MAJ:MIN -- "$dev" 2>/dev/null) || key=''
    key=${key//[[:space:]]/}
    [[ $key =~ ^[0-9]+:[0-9]+$ ]] || { B109_ERRORS+=("Cannot identify device major:minor: $dev"); continue; }
    # Compare kernel mountinfo device IDs; includes bind mounts not visible in basic lsblk output.
    if [[ -r /proc/self/mountinfo ]] && awk -v id="$key" '$3 == id { found=1 } END { exit !found }' /proc/self/mountinfo; then
      B109_ERRORS+=("Device has a mount in this namespace: $dev")
    fi
    # Kernel block holders identify device-mapper, RAID and other stacked dependencies.
    entry="/sys/dev/block/$key/holders"
    if [[ ! -d $entry || ! -r $entry ]]; then
      B109_ERRORS+=("Cannot inspect kernel holders: $dev")
    else
      local -a holders=()
      local nullglob_before
      # compgen -G returns 1 for no holders (which is a safe empty result).
      while IFS= read -r holder; do [[ -n $holder ]] && holders+=("$holder"); done < <(compgen -G "$entry/*" || true)
      ((${#holders[@]} == 0)) || B109_ERRORS+=("Kernel block holders exist for $dev")
    fi
  done
  # Fail closed if swap inspection itself fails; B10.8 also checks device-matching swap.
  if ! swapon --show=NAME --noheadings --raw >/dev/null 2>&1; then
    B109_ERRORS+=('Swap inspection failed.')
  fi
  ((${#B109_ERRORS[@]} == 0))
}

b109_rehearse() {
  local mode=${1:-} phrase=${2:-} fp snap
  B109_FINGERPRINT='' B109_SNAPSHOT='' B109_MODE=''
  b109_check "$mode" || return 1
  [[ $phrase == "GUARD ${DISK} ONLY" ]] || return 1
  fp=$(b95_fingerprint) || return 1
  snap=$(b101_snapshot "$mode") || return 1
  b109_check "$mode" || return 1
  [[ $(b95_fingerprint) == "$fp" && $(b101_snapshot "$mode") == "$snap" ]] || return 1
  B109_FINGERPRINT=$fp B109_SNAPSHOT=$snap B109_MODE=$mode
}

b109_report() {
  local mode=${1:-} err
  printf 'B10.9 — INDEPENDENT PRE-WRITE GUARDS (READ ONLY)\n\n'
  if ! b109_check "$mode"; then
    printf 'BLOCKED:\n'
    for err in "${B109_ERRORS[@]}"; do printf '  - %s\n' "$err"; done
    printf '\nEXECUTION DISABLED. No changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI policy: %s\n\n' "$DISK" "$mode"
  printf '[CHECK ONLY] B10.8 confirmation remains current\n'
  printf '[CHECK ONLY] Kernel mountinfo and block-device holder directories inspected\n'
  printf '[CHECK ONLY] Swap inspection completed without error\n'
  printf '[LIMITATION] Other namespaces, hidden dependencies, open file descriptors and check-to-use races remain possible\n'
  printf '[LIMITATION] No guard can guarantee a selected disk is safe to erase\n'
  printf '\nB10.9 GUARDS PASSED — READ ONLY. Real installation DISABLED.\n'
}

b109_menu() {
  local choice mode phrase
  ui_heading 'B10.9 — Pre-Write Safety Guards (READ ONLY)'
  choice=$(ui_choose 'Select the same EFI policy as B10.8' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.9 — Independent Guard Audit'
  if ! b109_report "$mode"; then ui_pause; return 0; fi
  printf '\nThis is a READ-ONLY rehearsal, NOT disk-write authorization.\n'
  phrase=$(gum input --header "Type GUARD ${DISK} ONLY") || return 0
  if b109_rehearse "$mode" "$phrase"; then
    ui_note 'B10.9 GUARD REHEARSAL PASSED — no disk-write authorization. Real installation DISABLED.'
  else
    ui_error 'B10.9 BLOCKED — invalid phrase or state changed.'
  fi
  ui_pause
}

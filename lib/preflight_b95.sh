#!/usr/bin/env bash
# B9.5 read-only target identity approval. Never performs disk writes.
B95_APPROVED_FINGERPRINT=''
B95_APPROVED_SETTINGS=''
B95_ERRORS=()

b95_identity() {
  local disk=${DISK:-} part real type pk parent uuid
  [[ -n $disk && -b $disk ]] || return 1
  real=$(readlink -f -- "$disk") || return 1
  [[ $(lsblk -dn -o TYPE "$real" 2>/dev/null) == disk ]] || return 1
  printf 'disk\0%s\0' "$real"
  for part in "${EFI_PART:-}" "${ROOT_PART:-}" "${SWAP_PART:-}"; do
    if [[ -z $part ]]; then printf 'none\0'; continue; fi
    [[ -b $part ]] || return 1
    type=$(lsblk -dn -o TYPE "$part" 2>/dev/null) || return 1
    [[ $type == part ]] || return 1
    pk=$(lsblk -dn -o PKNAME "$part" 2>/dev/null) || return 1
    [[ -n $pk ]] || return 1
    parent=$(readlink -f -- "/dev/$pk") || return 1
    [[ $parent == "$real" ]] || return 1
    uuid=$(lsblk -dn -o PARTUUID "$part" 2>/dev/null) || return 1
    [[ -n $uuid ]] || return 1
    printf 'part\0%s\0%s\0' "$(readlink -f -- "$part")" "$uuid"
  done
  lsblk -dn -o SIZE,MODEL,SERIAL,WWN "$real" 2>/dev/null
}

b95_fingerprint() {
  local digest
  # Keep NUL separators intact by hashing the stream, not a Bash variable.
  digest=$(
    set -o pipefail
    b95_identity | sha256sum
  ) || return 1
  [[ $digest =~ ^[[:xdigit:]]{64}[[:space:]] ]] || return 1
  printf '%s\n' "${digest%% *}"
}

b95_check() {
  B95_ERRORS=()
  b94_run
  ((${#B94_ERRORS[@]} == 0)) || B95_ERRORS+=('B9.4 preflight has blocking errors.')
  b93_is_approved || B95_ERRORS+=('System settings approval is missing or stale.')
  local fp
  fp=$(b95_fingerprint) || B95_ERRORS+=('Cannot fingerprint target disk and partitions.')
  [[ -n $fp ]] || B95_ERRORS+=('Target fingerprint is empty.')
  ((${#B95_ERRORS[@]} == 0))
}

b95_is_approved() {
  [[ -n $B95_APPROVED_FINGERPRINT && -n $B95_APPROVED_SETTINGS ]] || return 1
  b95_check || return 1
  [[ $(b95_fingerprint) == "$B95_APPROVED_FINGERPRINT" && $(b93_snapshot) == "$B95_APPROVED_SETTINGS" ]]
}

b95_menu() {
  ui_heading 'B9.5 — Target Identity Lock (READ ONLY)'
  if ! b95_check; then
    local error
    for error in "${B95_ERRORS[@]}"; do ui_error "BLOCKED: $error"; done
    ui_pause
    return 0
  fi
  printf 'Selected disk: %s\nEFI: %s\nRoot: %s\nSwap: %s\n' \
    "$DISK" "$EFI_PART" "$ROOT_PART" "${SWAP_PART:-none}"
  lsblk -dn -o NAME,SIZE,MODEL,SERIAL,WWN "$DISK" || true
  printf '\nThis approval does NOT authorize formatting or installation.\n'
  local answer phrase
  answer=$(ui_choose 'Lock this exact target selection for this session?' 'Lock selection (read only)' 'Back') || return 0
  [[ $answer == 'Lock selection (read only)' ]] || return 0
  phrase=$(gum input --header 'Type LOCK TARGET to confirm (read only)') || return 0
  if [[ $phrase != 'LOCK TARGET' ]]; then
    ui_error 'Target lock cancelled: confirmation did not match.'
  else
    local locked_fp locked_settings
    locked_fp=$(b95_fingerprint) || {
      ui_error 'Target lock failed: disk identity could not be verified.'
      ui_pause
      return 0
    }
    locked_settings=$(b93_snapshot) || {
      ui_error 'Target lock failed: system settings could not be verified.'
      ui_pause
      return 0
    }
    b95_check || {
      ui_error 'Target lock failed: configuration changed during confirmation.'
      ui_pause
      return 0
    }
    [[ $locked_fp == "$(b95_fingerprint)" && $locked_settings == "$(b93_snapshot)" ]] || {
      ui_error 'Target lock failed: configuration changed during confirmation.'
      ui_pause
      return 0
    }
    B95_APPROVED_FINGERPRINT=$locked_fp
    B95_APPROVED_SETTINGS=$locked_settings
    ui_note 'Target identity locked for this session. Installation remains DISABLED.'
  fi
  ui_pause
}

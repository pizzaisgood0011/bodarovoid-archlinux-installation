#!/usr/bin/env bash
# A human-readable intent summary, never a shell script or execution manifest.
plan_partition() {
  local label=$1 path=$2 purpose=$3 uuid fstype size model
  if [[ -z $path ]]; then
    printf '%s: Not selected\n' "$label"
    return
  fi
  uuid=$(lsblk -dn -o UUID "$path" 2>/dev/null || true)
  fstype=$(lsblk -dn -o FSTYPE "$path" 2>/dev/null || true)
  size=$(lsblk -dn -o SIZE "$path" 2>/dev/null || true)
  printf '%s: %s | %s | %s | UUID: %s\n' "$label" "$path" "${size:-unknown size}" "${fstype:-unformatted}" "${uuid:-none}"
  printf '  Intended policy: %s\n' "$purpose"
}

plan_menu() {
  packages_build_plan
  preflight_run
  ui_heading 'Installation Plan & Preflight (READ ONLY)'
  printf 'Disk: %s\n' "${DISK:-Not selected}"
  if [[ -n ${DISK:-} && -b $DISK ]]; then
    lsblk -dn -o MODEL,SERIAL,SIZE "$DISK" 2>/dev/null || true
  fi
  printf '\nPARTITIONS / INTENT\n'
  plan_partition 'EFI' "${EFI_PART:-}" "Policy: $EFI_FORMAT_POLICY (read-only preview)."
  plan_partition 'Root' "${ROOT_PART:-}" "Future installer would create $FILESYSTEM here, destroying existing root data. NOT IMPLEMENTED."
  plan_partition 'Swap' "${SWAP_PART:-}" 'Future installer may initialize swap; destructive. NOT IMPLEMENTED.'
  printf '\nFORMATTING POLICY (NOT EXECUTED)\n'
  if ((${#FORMAT_OPERATIONS[@]})); then printf '  %s\n' "${FORMAT_OPERATIONS[@]}"; fi
  printf '\nSYSTEM\n'
  printf 'Kernel: %s | Filesystem: %s | Bootloader: %s | Encryption: %s\n' "$KERNEL" "$FILESYSTEM" "$BOOTLOADER" "$ENCRYPTION"
  printf 'CPU: %s | GPU: %s | Desktop: %s\n' "$CPU" "$GPU" "$DESKTOP"
  printf 'Hostname: %s | Username: %s | Locale: %s | Keymap: %s | Timezone: %s\n' "$HOSTNAME" "${USERNAME:-unset}" "$LOCALE" "$KEYMAP" "$TIMEZONE"
  printf '\nPACKAGES (%d, preview only)\n' "${#PACKAGE_PLAN[@]}"
  printf '  %s\n' "${PACKAGE_PLAN[@]}"
  printf '\nPACKAGE NOTES\n'
  local item
  for item in "${PACKAGE_NOTES[@]}"; do printf '  - %s\n' "$item"; done
  printf '\nPREFLIGHT: %d blocking error(s), %d warning(s)\n' "${#PREFLIGHT_ERRORS[@]}" "${#PREFLIGHT_WARNINGS[@]}"
  for item in "${PREFLIGHT_ERRORS[@]}"; do printf '  ERROR: %s\n' "$item"; done
  for item in "${PREFLIGHT_WARNINGS[@]}"; do printf '  WARN: %s\n' "$item"; done
  for item in "${PREFLIGHT_INFO[@]}"; do printf '  INFO: %s\n' "$item"; done
  printf '\n'
  ui_error 'NO INSTALL ACTION IS AVAILABLE. DO NOT USE THIS REPORT TO FORMAT DISKS.'
  ui_pause
}

#!/usr/bin/env bash

# Read-only checks. No partition, filesystem, or mount changes.
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()
VALIDATION_INFO=()

validation_error() { VALIDATION_ERRORS+=("$1"); }
validation_warn() { VALIDATION_WARNINGS+=("$1"); }
validation_info() { VALIDATION_INFO+=("$1"); }

validation_is_partition_on_disk() {
  local candidate=$1 parent disk_real candidate_real parent_real
  [[ -n $candidate && -n $DISK && -b $candidate && -b $DISK ]] || return 1
  [[ $(lsblk -dn -o TYPE "$candidate" 2>/dev/null) == part ]] || return 1
  parent=$(lsblk -dn -o PKNAME "$candidate" 2>/dev/null) || return 1
  [[ -n $parent ]] || return 1
  disk_real=$(readlink -f -- "$DISK") || return 1
  candidate_real=$(readlink -f -- "$candidate") || return 1
  parent_real=$(readlink -f -- "/dev/$parent") || return 1
  [[ -b $candidate_real && $parent_real == "$disk_real" ]]
}

validation_check_partition() {
  local label=$1 path=$2 required=$3 fstype mountpoints
  if [[ -z $path ]]; then
    [[ $required == yes ]] && validation_error "$label partition is not assigned."
    return 0
  fi
  if ! validation_is_partition_on_disk "$path"; then
    validation_error "$label ($path) is not a partition on the selected disk."
    return 0
  fi
  fstype=$(lsblk -dn -o FSTYPE "$path" 2>/dev/null || true)
  mountpoints=$(lsblk -nr -o MOUNTPOINTS "$path" 2>/dev/null | sed '/^[[:space:]]*$/d' || true)
  if [[ -n $mountpoints ]]; then
    validation_error "$label ($path) is mounted at: $(printf '%s' "$mountpoints" | tr '\n' ' ')."
  fi
  if command -v swapon >/dev/null 2>&1 && swapon --noheadings --raw --output NAME 2>/dev/null | grep -Fxq -- "$path"; then
    validation_error "$label ($path) is active swap."
  fi
  validation_info "$label: $path; detected filesystem: ${fstype:-none}."
}

validation_run() {
  VALIDATION_ERRORS=()
  VALIDATION_WARNINGS=()
  VALIDATION_INFO=()

  if [[ ! -d /sys/firmware/efi ]]; then
    validation_error 'Live environment is not booted in UEFI mode; current installer supports UEFI only.'
  fi

  if [[ -z $DISK || ! -b $DISK ]]; then
    validation_error 'Select an existing installation disk.'
    return 0
  fi
  if [[ $(lsblk -dn -o TYPE "$DISK" 2>/dev/null) != disk ]]; then
    validation_error "Selected device ($DISK) is not a whole disk."
    return 0
  fi

  validation_check_partition 'EFI' "$EFI_PART" yes
  validation_check_partition 'Root' "$ROOT_PART" yes
  validation_check_partition 'Swap' "$SWAP_PART" no

  if [[ -n $EFI_PART && -n $ROOT_PART && $EFI_PART == "$ROOT_PART" ]]; then
    validation_error 'EFI and Root must be different partitions.'
  fi
  if [[ -n $SWAP_PART && ( $SWAP_PART == "$EFI_PART" || $SWAP_PART == "$ROOT_PART" ) ]]; then
    validation_error 'Swap must be different from EFI and Root.'
  fi

  if validation_is_partition_on_disk "$EFI_PART"; then
    local efi_type efi_fs
    efi_type=$(lsblk -dn -o PARTTYPE "$EFI_PART" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
    efi_fs=$(lsblk -dn -o FSTYPE "$EFI_PART" 2>/dev/null || true)
    if [[ $efi_type != c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]]; then
      validation_error 'EFI partition does not have the GPT EFI System partition type.'
    fi
    if [[ $efi_fs != vfat ]]; then
      validation_warn 'EFI partition is not detected as FAT (vfat); future installation needs an explicit EFI formatting policy.'
    else
      validation_warn 'Existing EFI filesystem detected. It must be preserved by default, especially for dual boot.'
    fi
  fi

  if validation_is_partition_on_disk "$ROOT_PART"; then
    local root_fs
    root_fs=$(lsblk -dn -o FSTYPE "$ROOT_PART" 2>/dev/null || true)
    if [[ -n $root_fs ]]; then
      validation_warn "Root contains an existing $root_fs signature; a future format would erase its contents."
    fi
  fi

  if validation_is_partition_on_disk "$SWAP_PART"; then
    local swap_fs
    swap_fs=$(lsblk -dn -o FSTYPE "$SWAP_PART" 2>/dev/null || true)
    if [[ -n $swap_fs && $swap_fs != swap ]]; then
      validation_warn "Swap selection contains $swap_fs data, not a swap signature."
    fi
  fi

  if [[ -z $USERNAME ]] || ! system_valid_username "$USERNAME"; then
    validation_error 'Set a valid non-root username.'
  fi
  if ! system_valid_hostname "$HOSTNAME"; then
    validation_error 'Hostname is invalid.'
  fi
  if [[ -z $TIMEZONE || ! -f /usr/share/zoneinfo/$TIMEZONE ]]; then
    validation_error 'Timezone does not exist in /usr/share/zoneinfo.'
  fi
  if [[ -z $KEYMAP || ! $KEYMAP =~ ^[a-zA-Z0-9_+.-]+$ ]]; then
    validation_error 'Console keymap selection is invalid.'
  fi
  if [[ -z $LOCALE || ! $LOCALE =~ ^[a-zA-Z0-9_@.-]+$ ]]; then
    validation_error 'Locale selection is invalid.'
  fi
  validation_warn 'Installation engine is not implemented. This report is not permission to format disks.'
}

validation_menu() {
  validation_run
  ui_heading 'Safety & Validation'
  printf 'Disk: %s\nEFI:  %s\nRoot: %s\nSwap: %s\n\n' \
    "${DISK:-Not selected}" "${EFI_PART:-Not selected}" \
    "${ROOT_PART:-Not selected}" "${SWAP_PART:-None}"
  printf 'Errors: %d  |  Warnings: %d\n\n' "${#VALIDATION_ERRORS[@]}" "${#VALIDATION_WARNINGS[@]}"
  local item
  if ((${#VALIDATION_ERRORS[@]})); then
    ui_error 'BLOCKING ERRORS'
    for item in "${VALIDATION_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\n'
  fi
  if ((${#VALIDATION_WARNINGS[@]})); then
    ui_note 'WARNINGS'
    for item in "${VALIDATION_WARNINGS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\n'
  fi
  if ((${#VALIDATION_ERRORS[@]} == 0)); then
    gum style --foreground '#8FBCBB' 'Read-only checks passed; installation is still disabled.'
  else
    ui_error 'Configuration is not ready for installation.'
  fi
  printf '\n'
  ui_pause
}

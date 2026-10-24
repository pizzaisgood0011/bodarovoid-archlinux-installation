#!/usr/bin/env bash
# Read-only identity and device-in-use checks. This module never modifies block devices.
SAFETY_ERRORS=()
SAFETY_WARNINGS=()
SAFETY_INFO=()
SAFETY_DISK_FINGERPRINT=''

safety_field() {
  local device=$1 field=$2
  [[ -n $device && -b $device ]] || return 1
  lsblk -dn -o "$field" -- "$device" 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

safety_disk_fingerprint() {
  local disk=$1 real size majmin serial wwn model
  [[ -n $disk && -b $disk ]] || return 1
  real=$(readlink -f -- "$disk") || return 1
  [[ $(safety_field "$disk" TYPE) == disk ]] || return 1
  size=$(safety_field "$disk" SIZE) || return 1
  # SIZE is human-readable; use bytes for stable comparisons.
  size=$(lsblk -bdn -o SIZE -- "$disk" 2>/dev/null | tr -d '[:space:]') || return 1
  [[ $size =~ ^[0-9]+$ ]] || return 1
  majmin=$(safety_field "$disk" MAJ:MIN) || return 1
  serial=$(safety_field "$disk" SERIAL || true)
  wwn=$(safety_field "$disk" WWN || true)
  model=$(safety_field "$disk" MODEL || true)
  printf '%s|%s|%s|%s|%s|%s' "$real" "$size" "$majmin" "$serial" "$wwn" "$model"
}

safety_capture_disk() {
  SAFETY_DISK_FINGERPRINT=''
  [[ -n ${DISK:-} ]] || return 0
  SAFETY_DISK_FINGERPRINT=$(safety_disk_fingerprint "$DISK") || return 1
}

safety_check_device() {
  local label=$1 device=$2 canonical active swaps holders descendants
  [[ -n $device && -b $device ]] || return 0
  canonical=$(readlink -f -- "$device") || return 0
  active=$(lsblk -nr -o MOUNTPOINTS -- "$device" 2>/dev/null | sed '/^[[:space:]]*$/d' || true)
  if [[ -n $active ]]; then
    SAFETY_ERRORS+=("$label ($device) has mounted filesystems: $(echo "$active" | tr '\n' ' ')")
  fi
  if command -v swapon >/dev/null 2>&1; then
    swaps=$(swapon --noheadings --raw --output NAME 2>/dev/null || true)
    while IFS= read -r entry; do
      [[ -n $entry ]] || continue
      if [[ $(readlink -f -- "$entry" 2>/dev/null || true) == "$canonical" ]]; then
        SAFETY_ERRORS+=("$label ($device) is active swap.")
        break
      fi
    done <<< "$swaps"
  fi
  # /sys/class/block/<name>/holders lists active direct users (dm-crypt, LVM, MD, etc.).
  local blockname=${canonical##*/}
  if [[ -d /sys/class/block/$blockname/holders ]]; then
    holders=$(find "/sys/class/block/$blockname/holders" -mindepth 1 -maxdepth 1 -printf '%f ' 2>/dev/null || true)
    if [[ -n $holders ]]; then
      SAFETY_ERRORS+=("$label ($device) has active block-device holders: $holders")
    fi
  else
    SAFETY_WARNINGS+=("Cannot inspect block-device holders for $label ($device).")
  fi
  # lsblk's tree includes child mapper devices; do not proceed if the partition has children.
  descendants=$(lsblk -nr -o NAME -- "$device" 2>/dev/null | sed '1d' || true)
  if [[ -n $descendants ]]; then
    SAFETY_ERRORS+=("$label ($device) has dependent block devices: $(echo "$descendants" | tr '\n' ' ')")
  fi
}

safety_run() {
  SAFETY_ERRORS=()
  SAFETY_WARNINGS=()
  SAFETY_INFO=()
  if [[ -z ${DISK:-} || ! -b $DISK ]]; then
    SAFETY_ERRORS+=('Cannot verify disk identity: select a valid disk.')
    return 0
  fi
  local current
  current=$(safety_disk_fingerprint "$DISK") || {
    SAFETY_ERRORS+=('Unable to read current disk fingerprint.')
    return 0
  }
  if [[ -z $SAFETY_DISK_FINGERPRINT ]]; then
    SAFETY_WARNINGS+=('Disk identity baseline not captured. Reselect the disk to establish one.')
  elif [[ $current != "$SAFETY_DISK_FINGERPRINT" ]]; then
    SAFETY_ERRORS+=('Selected disk identity changed since selection. Reselect the disk and review partitions.')
  else
    SAFETY_INFO+=('Disk fingerprint matches the captured selection.')
  fi
  local disk_serial disk_wwn
  disk_serial=$(safety_field "$DISK" SERIAL || true)
  disk_wwn=$(safety_field "$DISK" WWN || true)
  if [[ -z $disk_serial && -z $disk_wwn ]]; then
    SAFETY_WARNINGS+=('Disk has no exposed serial or WWN. Fingerprint is weaker; device names may change.')
  fi
  local label path
  for label in EFI Root Swap; do
    case "$label" in
      EFI) path=${EFI_PART:-} ;;
      Root) path=${ROOT_PART:-} ;;
      Swap) path=${SWAP_PART:-} ;;
    esac
    safety_check_device "$label" "$path"
  done
}

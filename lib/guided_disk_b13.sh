#!/usr/bin/env bash
# B13: read-only guided disk layout preview. Never partitions or formats disks.
B13_EFI_MIB=1024
B13_SWAP_MIB=4096
B13_RESERVED_MIB=8
B13_MIN_ROOT_MIB=16384

b13_layout_mib() {
  local total=$1 swap=${2:-$B13_SWAP_MIB}
  [[ $total =~ ^[0-9]+$ && $swap =~ ^[0-9]+$ ]] || return 1
  (( total >= B13_EFI_MIB + swap + B13_RESERVED_MIB + B13_MIN_ROOT_MIB )) || return 1
  printf '%s %s %s\n' "$B13_EFI_MIB" "$swap" "$((total-B13_EFI_MIB-swap-B13_RESERVED_MIB))"
}

b13_disk_info() {
  local disk=$1 type size parent
  [[ -n $disk && -b $disk ]] || return 1
  [[ $(lsblk -dnro TYPE -- "$disk" 2>/dev/null) == disk ]] || return 1
  # Read the selected whole-disk size; no write operations are performed.
  size=$(blockdev --getsize64 "$disk") || return 1
  [[ $size =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$((size/1048576))"
}

b13_preview() {
  local disk=${1:-} swap=${2:-$B13_SWAP_MIB} size efi root
  [[ -n $disk ]] || { printf 'Select a disk in Disk & Partitions first.\n'; return 1; }
  size=$(b13_disk_info "$disk") || { printf 'Cannot safely inspect selected disk.\n'; return 1; }
  local layout
  layout=$(b13_layout_mib "$size" "$swap") || { printf 'Disk too small for this layout (16 GiB minimum root).\n'; return 1; }
  read -r efi swap root <<< "$layout"
  printf 'SELECTED DISK: %s (%s MiB)\n' "$disk" "$size"
  printf '\nPROPOSED GPT LAYOUT (NOT APPLIED)\n'
  printf '  EFI System     %6s MiB  FAT32  /boot/efi\n' "$efi"
  printf '  Linux swap     %6s MiB  swap   [swap]\n' "$swap"
  printf '  Linux root     %6s MiB  ext4   /\n' "$root"
  printf '  Alignment gap: %s MiB reserved in estimate\n' "$B13_RESERVED_MIB"
  printf '\nEXISTING PARTITIONS (READ ONLY):\n'
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS -- "$disk" || return 1
  printf '\nWARNING: Applying this layout in a future release would ERASE ALL\n'
  printf 'existing partitions and data on %s. No changes were made.\n' "$disk"
  printf 'B13 DOES NOT CREATE, DELETE, FORMAT, OR MOUNT PARTITIONS.\n'
}

b13_menu() {
  local choice swap=$B13_SWAP_MIB
  while true; do
    ui_heading 'B13 — Guided Partition Layout (READ ONLY)'
    printf 'Target: %s\nSwap size: %s MiB\n\n' "${DISK:-Not selected}" "$swap"
    ui_note 'Preview only: the B11 real installation path is unchanged.'
    choice=$(ui_choose 'Choose action' 'Preview proposed layout' 'Swap: 4 GiB' 'Swap: 8 GiB' 'Swap: none' 'Back') || return 0
    case "$choice" in
      'Preview proposed layout') ui_heading 'B13 — Disk Layout Preview'; b13_preview "${DISK:-}" "$swap" || true; ui_pause ;;
      'Swap: 4 GiB') swap=4096 ;;
      'Swap: 8 GiB') swap=8192 ;;
      'Swap: none') swap=0 ;;
      Back) return 0 ;;
    esac
  done
}

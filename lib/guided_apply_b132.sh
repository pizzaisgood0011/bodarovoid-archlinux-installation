#!/usr/bin/env bash
# B13.2: destructive GPT creation, protected by per-disk safety checks and physical-disk opt-in.
# This stage ONLY partitions. B11 handles filesystem creation after fresh approvals.
b132_guard() {
  local disk=${1:-} node typ model tran size name
  B132_ERRORS=()
  [[ $EUID -eq 0 ]] || B132_ERRORS+=('Root required.')
  [[ -d /sys/firmware/efi ]] || B132_ERRORS+=('UEFI boot required.')
  if ! bv_disk_guard "$disk"; then B132_ERRORS+=("${BV_ERRORS[@]}"); fi
  [[ $(blockdev --getro "$disk" 2>/dev/null) == 0 ]] || B132_ERRORS+=('Disk is read-only.')
  for node in sfdisk partprobe udevadm lsblk findmnt blockdev wipefs; do
    command -v "$node" >/dev/null 2>&1 || B132_ERRORS+=("Missing: $node")
  done
  # Reject active mounts, swap, and block-device holders on any descendant.
  while IFS= read -r name; do
    [[ -b $name ]] || continue
    if findmnt -rn -S "$name" >/dev/null 2>&1; then B132_ERRORS+=("Mounted: $name"); fi
    if swapon --noheadings --raw --show=NAME 2>/dev/null | grep -Fxq -- "$name"; then B132_ERRORS+=("Active swap: $name"); fi
    if [[ -d /sys/class/block/${name##*/}/holders ]] && compgen -G "/sys/class/block/${name##*/}/holders/*" >/dev/null; then
      B132_ERRORS+=("Device in use: $name")
    fi
  done < <(lsblk -rnpo NAME -- "$disk")
  ((${#B132_ERRORS[@]} == 0))
}

b132_apply() {
  local disk=${DISK:-} swap=${1:-4096} size layout efi swap_mib root identity now answer
  [[ $swap == 4096 || $swap == 8192 ]] || { ui_error 'Real partitioning requires 4 or 8 GiB swap for B11 compatibility.'; return 1; }
  b132_guard "$disk" || { printf 'BLOCKED:\n'; printf ' - %s\n' "${B132_ERRORS[@]}"; return 1; }
  size=$(b13_disk_info "$disk") || return 1
  layout=$(b13_layout_mib "$size" "$swap") || { ui_error 'Disk too small.'; return 1; }
  read -r efi swap_mib root <<< "$layout"
  identity=$(lsblk -dnro MAJ:MIN,SIZE,MODEL -- "$disk") || return 1
  ui_heading 'B13.2 — ERASE WHOLE SELECTED DISK'
  printf "TARGET: %s\n" "$disk"
  printf "PROPOSED: EFI %s MiB, swap %s MiB, root approximately %s MiB\n" "$efi" "$swap_mib" "$root"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS -- "$disk"
  printf '\nTHIS WILL DELETE THE ENTIRE PARTITION TABLE AND ALL DATA ON %s.\n' "$disk"
  printf 'Other disks will not be passed to sfdisk, but verify the target carefully.\n'
  answer=$(gum input --header "Type WIPE ${disk} GPT to authorize") || return 1
  [[ $answer == "WIPE ${disk} GPT" ]] || { printf 'Cancelled.\n'; return 1; }
  b132_guard "$disk" || { printf 'Disk safety checks changed; abort.\n'; return 1; }
  now=$(lsblk -dnro MAJ:MIN,SIZE,MODEL -- "$disk") || return 1
  [[ $identity == "$now" ]] || { printf 'Disk identity changed; abort.\n'; return 1; }
  # Sizes are in MiB; the final partition takes the remaining usable space.
  # No filesystem creation here. sfdisk only receives the selected disk.
  printf 'label: gpt\n\nsize=%sMiB, type=U\nsize=%sMiB, type=S\ntype=L\n' "$efi" "$swap_mib" | sfdisk --wipe always --wipe-partitions always -- "$disk" || return 1
  partprobe -- "$disk" || return 1
  udevadm settle || return 1
  local p1 p2 p3
  p1=$(bv_partition_path "$disk" 1)
  p2=$(bv_partition_path "$disk" 2)
  p3=$(bv_partition_path "$disk" 3)
  [[ -b $p1 && -b $p2 && -b $p3 ]] || { printf 'Partitions not visible after write. STOP.\n'; return 1; }
  [[ $(lsblk -dnro PARTTYPE -- "$p1" | tr '[:upper:]' '[:lower:]') == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] || return 1
  [[ $(lsblk -dnro PARTTYPE -- "$p3" | tr '[:upper:]' '[:lower:]') == 0fc63daf-8483-4772-8e79-3d69d8477de4 ]] || return 1
  EFI_PART=$p1 SWAP_PART=$p2 ROOT_PART=$p3
  # Invalidate every prior approval: the partition table is now different.
  B109_FINGERPRINT='' B109_SNAPSHOT='' B109_MODE=''
  B95_FINGERPRINT='' B95_SNAPSHOT=''
  printf '\nGPT CREATED. No filesystems formatted.\n'
  printf 'EFI=%s  SWAP=%s  ROOT=%s\n' "$EFI_PART" "$SWAP_PART" "$ROOT_PART"
  printf 'Restart all B9/B10 approvals before B11 real installation.\n'
}

b132_menu() {
  local choice swap=4096
  while true; do
    ui_heading 'B13.2 — Guided GPT Partitioning (supported disks) (DESTRUCTIVE)'
    printf 'Disk: %s\nSwap: %s MiB\n\n' "${DISK:-not selected}" "$swap"
    ui_note 'This deletes the ENTIRE selected disk partition table. B11 formats later.'
    choice=$(ui_choose 'Action' 'Preview exact layout' 'Use 4 GiB swap' 'Use 8 GiB swap' 'ERASE selected disk and create GPT' 'Back') || return 0
    case "$choice" in
      'Preview exact layout') b13_preview "${DISK:-}" "$swap" || true; ui_pause ;;
      'Use 4 GiB swap') swap=4096 ;;
      'Use 8 GiB swap') swap=8192 ;;
      'ERASE selected disk and create GPT') b132_apply "$swap" || true; ui_pause; return 0 ;;
      Back) return 0 ;;
    esac
  done
}

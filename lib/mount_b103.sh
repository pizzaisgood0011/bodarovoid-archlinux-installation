#!/usr/bin/env bash
# B10.3: read-only mount sequence and cleanup design; never invokes mount utilities.
B103_ERRORS=()
B103_STEPS=()

b103_validate() {
  local mode=${1:-} target=${B103_TARGET:-/mnt} dev
  B103_ERRORS=() B103_STEPS=()
  if ! declare -F b102_validate >/dev/null || ! b102_validate "$mode"; then
    B103_ERRORS+=("B10.2 formatting safety gates failed or authorization rehearsal is stale.")
    if declare -p B102_ERRORS >/dev/null 2>&1; then
      for dev in "${B102_ERRORS[@]}"; do B103_ERRORS+=("B10.2: $dev"); done
    fi
  fi
  [[ $target == /mnt ]] || B103_ERRORS+=("Mount target must be /mnt for this preview.")
  [[ ${FILESYSTEM:-} == ext4 || ${FILESYSTEM:-} == btrfs ]] || B103_ERRORS+=("Unsupported root filesystem.")
  [[ ${BOOTLOADER:-} == GRUB || ${BOOTLOADER:-} == Limine ]] || B103_ERRORS+=("Unsupported bootloader.")
  ((${#B103_ERRORS[@]} == 0)) || return 1

  if [[ $FILESYSTEM == btrfs ]]; then
    B103_STEPS+=("After separately authorized formatting: temporarily mount root $ROOT_PART at /mnt")
    B103_STEPS+=("Create Btrfs subvolumes @ and @home on the empty root filesystem")
    B103_STEPS+=("Unmount temporary root mount /mnt")
    B103_STEPS+=("Mount $ROOT_PART with subvol=@ at /mnt")
    B103_STEPS+=("Create /mnt/home and mount $ROOT_PART with subvol=@home at /mnt/home")
  else
    B103_STEPS+=("Mount ext4 root $ROOT_PART at /mnt")
  fi
  B103_STEPS+=("Create EFI mount directory /mnt/boot/efi")
  B103_STEPS+=("Mount EFI $EFI_PART at /mnt/boot/efi (policy: $mode; no EFI formatting in mounting stage)")
  B103_STEPS+=("Activate swap $SWAP_PART only after independent validation")
  B103_STEPS+=("Verify root and EFI mountpoints, swap identity, and expected filesystem types")
  B103_STEPS+=("On failure: deactivate only swap activated by this run")
  B103_STEPS+=("On failure: unmount only mounts created by this run, in reverse order")
  B103_STEPS+=("Never recursively unmount pre-existing mounts or alter other disks")
  return 0
}

b103_report() {
  local mode=${1:-} item
  printf 'B10.3 — MOUNTING AND CLEANUP PLAN (READ ONLY)\n\n'
  if ! b103_validate "$mode"; then
    printf 'BLOCKED:\n'
    for item in "${B103_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nRoot filesystem: %s\nBootloader: %s\nEFI policy: %s\n\n' "$DISK" "$FILESYSTEM" "$BOOTLOADER" "$mode"
  for item in "${B103_STEPS[@]}"; do printf '[PLAN ONLY] %s\n' "$item"; done
  printf '\nB10.3 PLAN COMPLETE — no mounting or swap activation performed. Real installation DISABLED.\n'
}

b103_menu() {
  local choice mode
  ui_heading 'B10.3 — Mounting and Cleanup (READ ONLY)'
  choice=$(ui_choose 'Select the same EFI policy as B10.1/B10.2' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.3 — Mount Plan'
  b103_report "$mode" || true
  ui_pause
}

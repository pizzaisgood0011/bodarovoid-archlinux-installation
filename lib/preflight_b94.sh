#!/usr/bin/env bash
# B9.4 read-only gate. This module never mounts, formats or installs.
B94_ERRORS=()
B94_WARNINGS=()
B94_INFO=()

b94_run() {
  B94_ERRORS=(); B94_WARNINGS=(); B94_INFO=()
  if ! b93_is_approved; then
    B94_ERRORS+=('System settings require current B9.2 approval.')
  fi
  if [[ ! -d /sys/firmware/efi ]]; then
    B94_ERRORS+=('Live ISO is not booted in UEFI mode.')
  fi
  local tool
  for tool in lsblk findmnt blkid pacstrap genfstab arch-chroot grub-install; do
    command -v "$tool" >/dev/null 2>&1 || B94_ERRORS+=("Missing installation tool: $tool")
  done
  if [[ -z ${DISK:-} || ! -b ${DISK:-/nonexistent} || $(lsblk -dn -o TYPE "$DISK" 2>/dev/null) != disk ]]; then
    B94_ERRORS+=('Choose a valid whole installation disk.')
  else
    local disk_real part parent
    disk_real=$(readlink -f -- "$DISK")
    for part in "${EFI_PART:-}" "${ROOT_PART:-}"; do
      if [[ -z $part || ! -b $part || $(lsblk -dn -o TYPE "$part" 2>/dev/null) != part ]]; then
        B94_ERRORS+=("Missing or invalid required partition: ${part:-unset}")
        continue
      fi
      parent=$(lsblk -dn -o PKNAME "$part" 2>/dev/null || true)
      if [[ -z $parent || $(readlink -f -- "/dev/$parent") != "$disk_real" ]]; then
        B94_ERRORS+=("Partition is not on the selected disk: $part")
      fi
    done
    if [[ -n ${SWAP_PART:-} ]]; then
      if [[ ! -b $SWAP_PART || $(lsblk -dn -o TYPE "$SWAP_PART" 2>/dev/null) != part ]]; then
        B94_ERRORS+=('Invalid swap partition.')
      else
        parent=$(lsblk -dn -o PKNAME "$SWAP_PART" 2>/dev/null || true)
        [[ -n $parent && $(readlink -f -- "/dev/$parent") == "$disk_real" ]] || B94_ERRORS+=('Swap partition is not on selected disk.')
      fi
    fi
    B94_INFO+=("Disk: $DISK")
    local serial model
    serial=$(lsblk -dn -o SERIAL "$DISK" 2>/dev/null | xargs || true)
    model=$(lsblk -dn -o MODEL "$DISK" 2>/dev/null | xargs || true)
    B94_INFO+=("Model: ${model:-unknown}; Serial: ${serial:-unavailable}")
    [[ -n $serial ]] || B94_WARNINGS+=('Disk serial unavailable; require extra care identifying the target.')
  fi
  if [[ -n ${EFI_PART:-} && -n ${ROOT_PART:-} && $EFI_PART == "$ROOT_PART" ]]; then
    B94_ERRORS+=('EFI and root must be different partitions.')
  fi
  if [[ -n ${SWAP_PART:-} && ( $SWAP_PART == "${EFI_PART:-}" || $SWAP_PART == "${ROOT_PART:-}" ) ]]; then
    B94_ERRORS+=('Swap must not overlap EFI or root.')
  fi
  local part mounts
  for part in "${EFI_PART:-}" "${ROOT_PART:-}" "${SWAP_PART:-}"; do
    [[ -n $part && -b $part ]] || continue
    mounts=$(lsblk -nr -o MOUNTPOINTS "$part" 2>/dev/null | sed '/^[[:space:]]*$/d' || true)
    [[ -z $mounts ]] || B94_ERRORS+=("Selected partition is mounted: $part")
    if command -v swapon >/dev/null 2>&1 && swapon --noheadings --raw --output NAME 2>/dev/null | grep -Fxq -- "$part"; then
      B94_ERRORS+=("Selected partition is active swap: $part")
    fi
  done
  [[ ${FILESYSTEM:-} == ext4 || ${FILESYSTEM:-} == btrfs ]] || B94_ERRORS+=('Unsupported filesystem.')
  [[ ${BOOTLOADER:-} == GRUB || ${BOOTLOADER:-} == Limine ]] || B94_ERRORS+=('Unsupported bootloader.')
  [[ ${ENCRYPTION:-none} == none || ${ENCRYPTION:-none} == luks2 ]] || B94_ERRORS+=('Unsupported encryption.')
  [[ ${DESKTOP:-} == none ]] || B94_WARNINGS+=('Desktop installation is not integrated; use none for upcoming execution tests.')
  if command -v getent >/dev/null 2>&1 && getent hosts archlinux.org >/dev/null 2>&1; then
    B94_INFO+=('DNS resolves archlinux.org (downloads not verified).')
  else
    B94_WARNINGS+=('DNS lookup for archlinux.org failed.')
  fi
  if ((${#B94_ERRORS[@]} == 0)); then
    B94_INFO+=('Read-only gate passed. Installation is STILL DISABLED.')
  fi
  return 0
}

b94_menu() {
  ui_heading 'B9.4 — Installation Execution Preflight (READ ONLY)'
  b94_run
  local item
  for item in "${B94_INFO[@]}"; do printf 'INFO: %s\n' "$item"; done
  for item in "${B94_WARNINGS[@]}"; do ui_note "WARN: $item"; done
  for item in "${B94_ERRORS[@]}"; do ui_error "BLOCKED: $item"; done
  printf '\nBlocking errors: %d | Warnings: %d\n' "${#B94_ERRORS[@]}" "${#B94_WARNINGS[@]}"
  printf 'No installation, disk changes, or mounts are performed.\n'
  ui_pause
}

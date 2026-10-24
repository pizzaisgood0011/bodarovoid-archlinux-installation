#!/usr/bin/env bash
# Stage B3: VirtualBox-only mount testing. Disabled unless explicitly enabled.
MOUNT_EXEC_ENABLED=${LUCIOLE_ENABLE_VM_MOUNT:-0}
MOUNT_CHECK_ERROR=''

mount_exec_fail() {
  MOUNT_CHECK_ERROR=$1
  return 1
}

mount_exec_check() {
  MOUNT_CHECK_ERROR=''
  local dev type mountpoint

  [[ ${DISK:-} == /dev/sdc &&
     ${EFI_PART:-} == /dev/sdc1 &&
     ${ROOT_PART:-} == /dev/sdc3 &&
     ${SWAP_PART:-} == /dev/sdc2 ]] ||
    { mount_exec_fail 'Only the approved /dev/sdc VM partition layout is allowed.'; return 1; }

  format_exec_vm_guard ||
    { mount_exec_fail 'Approved VirtualBox disk identity check failed.'; return 1; }

  [[ ${ENCRYPTION:-none} == none ]] ||
    { mount_exec_fail 'Encrypted mounts are not supported in B3.'; return 1; }

  for dev in "$EFI_PART" "$ROOT_PART" "$SWAP_PART"; do
    validation_is_partition_on_disk "$dev" ||
      { mount_exec_fail "Partition is not on the approved disk: $dev"; return 1; }
    [[ -d /sys/class/block/${dev##*/}/holders ]] ||
      { mount_exec_fail "Cannot inspect device holders: $dev"; return 1; }
    [[ -z $(find "/sys/class/block/${dev##*/}/holders" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]] ||
      { mount_exec_fail "Device has active holders: $dev"; return 1; }
    [[ -z $(lsblk -nr -o MOUNTPOINTS -- "$dev" 2>/dev/null | sed '/^[[:space:]]*$/d') ]] ||
      { mount_exec_fail "Partition already mounted: $dev"; return 1; }
  done

  for dev in "$ROOT_PART" "$EFI_PART" "$SWAP_PART"; do
    type=$(blkid -p -s TYPE -o value -- "$dev" 2>/dev/null) ||
      { mount_exec_fail "Cannot identify filesystem: $dev"; return 1; }
    case "$dev" in
      "$ROOT_PART") [[ $type == ext4 ]] || { mount_exec_fail 'Root must be ext4.'; return 1; } ;;
      "$EFI_PART") [[ $type == vfat ]] || { mount_exec_fail 'EFI must be FAT.'; return 1; } ;;
      "$SWAP_PART") [[ $type == swap ]] || { mount_exec_fail 'Swap signature missing.'; return 1; } ;;
    esac
  done

  [[ $(lsblk -dn -o FSVER -- "$EFI_PART" 2>/dev/null | xargs) == FAT32 ]] ||
    { mount_exec_fail 'EFI must be FAT32.'; return 1; }

  [[ -z $(swapon --noheadings --raw --output NAME 2>/dev/null) ]] ||
    { mount_exec_fail 'Swap is already active.'; return 1; }

  [[ -z $(findmnt -rn -M /mnt 2>/dev/null) &&
     -z $(findmnt -rn -M /mnt/boot 2>/dev/null) ]] ||
    { mount_exec_fail '/mnt or /mnt/boot is already mounted.'; return 1; }

  # Avoid mounting over pre-existing files or another installation tree.
  if [[ -d /mnt ]] && [[ -n $(find /mnt -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]]; then
    mount_exec_fail '/mnt is not empty; inspect it before mounting.'
    return 1
  fi
}

mount_exec_menu() {
  ui_heading 'Stage B3 / VirtualBox Mount Engine'
  printf 'Disk: %s\nRoot: %s -> /mnt\nEFI: %s -> /mnt/boot\nSwap: %s -> swapon\n\n' \
    "${DISK:-none}" "${ROOT_PART:-none}" "${EFI_PART:-none}" "${SWAP_PART:-none}"
  printf 'Mounting changes filesystem metadata. This is not a formatting operation.\n\n'

  if ! mount_exec_check; then
    ui_error "BLOCKED: $MOUNT_CHECK_ERROR"
    ui_pause
    return 0
  fi

  if [[ $MOUNT_EXEC_ENABLED != 1 ]]; then
    ui_note 'READ ONLY: mount execution is disabled.'
    ui_note 'For VM testing only: LUCIOLE_ENABLE_VM_MOUNT=1'
    ui_pause
    return 0
  fi

  if ! gum confirm 'Mount /dev/sdc3, /dev/sdc1 and activate /dev/sdc2 swap?'; then
    ui_note 'Cancelled; no mounts performed.'
    ui_pause
    return 0
  fi

  local typed original current
  typed=$(gum input --prompt 'Type exact disk path: ') || return 0
  [[ $typed == "$DISK" ]] || { ui_error 'Disk confirmation mismatch.'; ui_pause; return 0; }
  typed=$(gum input --prompt 'Type MOUNT-VM: ') || return 0
  [[ $typed == MOUNT-VM ]] || { ui_error 'Confirmation mismatch.'; ui_pause; return 0; }

  mount_exec_check || { ui_error "BLOCKED: $MOUNT_CHECK_ERROR"; ui_pause; return 0; }
  original=$(safety_disk_fingerprint "$DISK") ||
    { ui_error 'Cannot capture disk identity.'; ui_pause; return 0; }
  [[ $original == "${SAFETY_DISK_FINGERPRINT:-}" ]] ||
    { ui_error 'Disk identity baseline does not match.'; ui_pause; return 0; }

  mkdir -p -- /mnt || { ui_error 'Cannot create /mnt.'; ui_pause; return 0; }
  if ! mount -- "$ROOT_PART" /mnt; then
    ui_error 'Root mount failed.'
    ui_pause
    return 0
  fi

  if ! mkdir -p -- /mnt/boot || ! mount -- "$EFI_PART" /mnt/boot; then
    umount -- /mnt || ui_error 'Rollback failed: /mnt remains mounted.'
    ui_error 'EFI mount failed; rollback attempted.'
    ui_pause
    return 0
  fi

  if ! swapon -- "$SWAP_PART"; then
    umount -- /mnt/boot || ui_error 'Rollback failed: /mnt/boot remains mounted.'
    umount -- /mnt || ui_error 'Rollback failed: /mnt remains mounted.'
    ui_error 'Swap activation failed; rollback attempted.'
    ui_pause
    return 0
  fi

  current=$(safety_disk_fingerprint "$DISK") || current=''
  if [[ -z $current || $current != "$original" ]]; then
    swapoff -- "$SWAP_PART" || ui_error 'Rollback failed: swap remains active.'
    umount -- /mnt/boot || ui_error 'Rollback failed: /mnt/boot remains mounted.'
    umount -- /mnt || ui_error 'Rollback failed: /mnt remains mounted.'
    ui_error 'Disk identity changed; rollback attempted.'
    ui_pause
    return 0
  fi

  ui_note 'Stage B3 mounts active. These mounts persist after exiting Luciole.'
  findmnt -M /mnt || true
  findmnt -M /mnt/boot || true
  swapon --show || true
  ui_pause
}

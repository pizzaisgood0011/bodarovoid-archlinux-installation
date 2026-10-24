#!/usr/bin/env bash
# Stage B3.1: safely undo only the known VirtualBox test mounts.
MOUNT_CLEANUP_ENABLED=${LUCIOLE_ENABLE_VM_CLEANUP:-0}
MOUNT_CLEANUP_ERROR=''

mount_cleanup_fail() {
  MOUNT_CLEANUP_ERROR=$1
  return 1
}

mount_cleanup_source_is() {
  local target=$1 expected=$2 actual expected_real actual_real
  actual=$(findmnt -rn -M "$target" -o SOURCE 2>/dev/null) || return 1
  [[ -n $actual ]] || return 1
  expected_real=$(readlink -f -- "$expected") || return 1
  actual_real=$(readlink -f -- "$actual") || return 1
  [[ $actual_real == "$expected_real" ]]
}

mount_cleanup_swap_active() {
  local active expected_real actual_real
  expected_real=$(readlink -f -- "$SWAP_PART") || return 1
  while IFS= read -r active; do
    [[ -n $active ]] || continue
    actual_real=$(readlink -f -- "$active") || return 1
    [[ $actual_real == "$expected_real" ]] && return 0
  done < <(swapon --noheadings --raw --output NAME)
  return 1
}

mount_cleanup_check() {
  MOUNT_CLEANUP_ERROR=''
  [[ ${DISK:-} == /dev/sdc && ${ROOT_PART:-} == /dev/sdc3 &&
     ${EFI_PART:-} == /dev/sdc1 && ${SWAP_PART:-} == /dev/sdc2 ]] ||
    { mount_cleanup_fail 'Only the approved /dev/sdc VM layout is supported.'; return 1; }
  format_exec_vm_guard ||
    { mount_cleanup_fail 'VirtualBox disk identity guard failed.'; return 1; }
  local dev
  for dev in "$EFI_PART" "$ROOT_PART" "$SWAP_PART"; do
    validation_is_partition_on_disk "$dev" ||
      { mount_cleanup_fail "Invalid partition: $dev"; return 1; }
  done
  local root_source='' boot_source='' other_swap
  root_source=$(findmnt -rn -M /mnt -o SOURCE 2>/dev/null) || true
  boot_source=$(findmnt -rn -M /mnt/boot -o SOURCE 2>/dev/null) || true
  if [[ -n $root_source ]] && ! mount_cleanup_source_is /mnt "$ROOT_PART"; then
    mount_cleanup_fail '/mnt is mounted from an unexpected device.'; return 1
  fi
  if [[ -n $boot_source ]] && ! mount_cleanup_source_is /mnt/boot "$EFI_PART"; then
    mount_cleanup_fail '/mnt/boot is mounted from an unexpected device.'; return 1
  fi
  # Reject any other nested mount under /mnt, rather than unmounting it.
  local target
  while IFS= read -r target; do
    [[ -n $target ]] || continue
    [[ $target == /mnt || $target == /mnt/boot ]] ||
      { mount_cleanup_fail "Unexpected nested mount: $target"; return 1; }
  done < <(findmnt -rn -o TARGET 2>/dev/null | grep -E '^/mnt(/|$)' || true)
  # Do not turn off swap belonging to another device.
  local active real expected
  expected=$(readlink -f -- "$SWAP_PART") || return 1
  while IFS= read -r active; do
    [[ -n $active ]] || continue
    real=$(readlink -f -- "$active") ||
      { mount_cleanup_fail 'Cannot resolve active swap.'; return 1; }
    [[ $real == "$expected" ]] ||
      { mount_cleanup_fail "Unexpected active swap: $active"; return 1; }
  done < <(swapon --noheadings --raw --output NAME)
  return 0
}

mount_cleanup_menu() {
  ui_heading 'Stage B3.1 / VirtualBox Unmount & Cleanup'
  printf 'Disk: %s\nSwap: %s -> swapoff (if active)\nEFI: %s -> unmount /mnt/boot\nRoot: %s -> unmount /mnt\n\n' \
    "${DISK:-none}" "${SWAP_PART:-none}" "${EFI_PART:-none}" "${ROOT_PART:-none}"
  if ! mount_cleanup_check; then
    ui_error "BLOCKED: ${MOUNT_CLEANUP_ERROR:-Unknown safety failure.}"
    ui_pause; return 0
  fi
  printf 'Current state:\n'
  findmnt -M /mnt || true
  findmnt -M /mnt/boot || true
  swapon --show || true
  printf '\n'
  if [[ $MOUNT_CLEANUP_ENABLED != 1 ]]; then
    ui_note 'READ ONLY: cleanup execution is disabled.'
    ui_note 'VM test only: LUCIOLE_ENABLE_VM_CLEANUP=1'
    ui_pause; return 0
  fi
  if ! gum confirm 'Deactivate test swap and unmount only the approved VM mounts?'; then
    ui_note 'Cancelled; no changes.'; ui_pause; return 0
  fi
  local typed
  typed=$(gum input --prompt 'Type exact disk path: ') || return 0
  [[ $typed == "$DISK" ]] || { ui_error 'Disk confirmation mismatch.'; ui_pause; return 0; }
  typed=$(gum input --prompt 'Type CLEANUP-VM: ') || return 0
  [[ $typed == CLEANUP-VM ]] || { ui_error 'Confirmation mismatch.'; ui_pause; return 0; }
  if ! mount_cleanup_check; then
    ui_error "BLOCKED: $MOUNT_CLEANUP_ERROR"; ui_pause; return 0
  fi
  # Stop on any failure; never force or recursively unmount.
  if mount_cleanup_swap_active; then
    swapoff -- "$SWAP_PART" || { ui_error 'swapoff failed; stopped.'; ui_pause; return 0; }
  fi
  if findmnt -rn -M /mnt/boot >/dev/null 2>&1; then
    umount -- /mnt/boot || { ui_error 'EFI unmount failed; stopped.'; ui_pause; return 0; }
  fi
  if findmnt -rn -M /mnt >/dev/null 2>&1; then
    umount -- /mnt || { ui_error 'Root unmount failed; stopped.'; ui_pause; return 0; }
  fi
  ui_note 'Cleanup completed. Verify that /mnt and swap are inactive.'
  ui_pause
}

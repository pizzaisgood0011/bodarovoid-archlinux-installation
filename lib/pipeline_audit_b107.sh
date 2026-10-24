#!/usr/bin/env bash
# B10.7: read-only cross-stage audit. Never authorizes installation.
B107_ERRORS=()
B107_FINDINGS=()
B107_MATRIX=(
  'ext4 + GRUB: plan only; execution and reboot not verified'
  'btrfs + GRUB: plan only; subvolume execution and reboot not verified'
  'ext4 + Limine: plan only; boot config and reboot not verified'
  'btrfs + Limine: plan only; boot config and reboot not verified'
)

b107_validate() {
  local mode=${1:-} selected_fs=${FILESYSTEM:-} selected_loader=${BOOTLOADER:-}
  B107_ERRORS=() B107_FINDINGS=()
  if ! declare -F b106_validate >/dev/null || ! b106_validate "$mode"; then
    B107_ERRORS+=('B10.6 bootloader plan prerequisites failed or rehearsal/target lock is stale.')
  fi
  case "$mode" in create|reuse) ;; *) B107_ERRORS+=('Invalid EFI policy.') ;; esac
  case "$selected_fs:$selected_loader" in
    ext4:GRUB|btrfs:GRUB|ext4:Limine|btrfs:Limine) ;;
    *) B107_ERRORS+=('Unsupported filesystem and bootloader combination.') ;;
  esac
  ((${#B107_ERRORS[@]} == 0)) || return 1
  B107_FINDINGS=(
    'B9.2/B9.4/B9.5 and B10.1-B10.6 planning gates accepted the current selection'
    'B10.1 rehearsal is not real authorization; it cannot permit disk writes'
    'EFI create and reuse must remain separate; reuse must never format EFI'
    'Formatting executor and independent pre-write authorization are not enabled or proven'
    'Mounting, cleanup, pacstrap, fstab, system configuration and bootloader execution remain unverified'
    'Btrfs subvolume setup and Limine package-version-specific syntax require live verification'
    'Failure recovery and reboot success are not established by read-only plans'
    'DO NOT enable installation based on this audit'
  )
}

b107_report() {
  local mode=${1:-} item
  printf 'B10.7 — FULL PIPELINE SAFETY AUDIT (READ ONLY)\n\n'
  if ! b107_validate "$mode"; then
    printf 'BLOCKED:\n'
    for item in "${B107_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI: %s (%s)\nRoot: %s (%s)\nSwap: %s\nKernel: %s\nBootloader: %s\n\n' \
    "$DISK" "$EFI_PART" "$mode" "$ROOT_PART" "$FILESYSTEM" "${SWAP_PART:-none}" "$KERNEL" "$BOOTLOADER"
  printf 'CONFIGURATION MATRIX (DESIGN TARGETS):\n'
  for item in "${B107_MATRIX[@]}"; do printf '  - %s\n' "$item"; done
  printf '\nSAFETY AUDIT FINDINGS:\n'
  for item in "${B107_FINDINGS[@]}"; do printf '[AUDIT ONLY] %s\n' "$item"; done
  printf '\nAUDIT COMPLETE — PLANNING GATES PASSED; EXECUTION NOT READY.\nReal installation DISABLED. No changes made.\n'
}

b107_menu() {
  local choice mode
  ui_heading 'B10.7 — Full Pipeline Safety Audit (READ ONLY)'
  choice=$(ui_choose 'Select the same EFI policy as B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.7 — Full Pipeline Audit'
  b107_report "$mode" || true
  ui_pause
}

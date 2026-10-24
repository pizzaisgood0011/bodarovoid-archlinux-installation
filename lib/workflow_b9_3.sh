#!/usr/bin/env bash
# B9.3: approved-settings handoff, preview only.
B93_APPROVED_SNAPSHOT=''
B93_PLAN_READY=0

b93_snapshot() {
  printf '%s\0' "${KERNEL:-}" "${FILESYSTEM:-}" "${BOOTLOADER:-}" "${ENCRYPTION:-none}" "${CPU:-}" "${GPU:-}" "${DESKTOP:-}" "${HOSTNAME:-}" "${USERNAME:-}" "${TIMEZONE:-}" "${KEYMAP:-}" "${LOCALE:-}" | sha256sum | cut -d' ' -f1
}

b93_capture_approval() {
  [[ ${CONFIG_REVIEW_APPROVED:-0} == 1 ]] || return 1
  config_review_validate || return 1
  B93_APPROVED_SNAPSHOT=$(b93_snapshot)
  B93_PLAN_READY=0
}

b93_is_approved() {
  [[ ${CONFIG_REVIEW_APPROVED:-0} == 1 && -n $B93_APPROVED_SNAPSHOT ]] || return 1
  [[ $(b93_snapshot) == "$B93_APPROVED_SNAPSHOT" ]] || return 1
  config_review_validate
}

b93_preview() {
  B93_PLAN_READY=0
  if ! b93_is_approved; then
    printf 'BLOCKED: Review and approve the current system settings first.\n'
    return 1
  fi
  printf 'B9.3 SYSTEM HANDOFF (READ ONLY)\n'
  printf 'Hostname: %s\nUsername: %s\nTimezone: %s\nKeymap: %s\nLocale: %s\n' "$HOSTNAME" "$USERNAME" "$TIMEZONE" "$KEYMAP" "$LOCALE"
  printf 'Kernel: %s | Filesystem: %s | Bootloader: %s | Desktop: %s\n' "$KERNEL" "$FILESYSTEM" "$BOOTLOADER" "$DESKTOP"
  printf '\nINSTALLATION DISABLED: no disk writes, pacstrap, chroot, passwords, or bootloader actions.\n'
  B93_PLAN_READY=1
}

b93_menu() {
  ui_heading 'B9.3 — Approved Settings Handoff (READ ONLY)'
  if b93_preview; then
    ui_note 'Preview prepared. No installation was performed.'
  else
    ui_error 'Settings approval is missing, invalid, or outdated.'
  fi
  ui_pause
}

#!/usr/bin/env bash
# B10.5: system configuration plan only. No target writes or chroot execution.
B105_ERRORS=()
B105_STEPS=()

b105_validate() {
  local mode=${1:-} locale_line
  B105_ERRORS=() B105_STEPS=()
  if ! declare -F b104_validate >/dev/null || ! b104_validate "$mode"; then
    B105_ERRORS+=('B10.4 base installation plan prerequisites failed or rehearsal is stale.')
  fi
  if ! declare -F system_valid_hostname >/dev/null || ! system_valid_hostname "${HOSTNAME:-}"; then
    B105_ERRORS+=('Hostname is missing or invalid.')
  fi
  if ! declare -F system_valid_username >/dev/null || ! system_valid_username "${USERNAME:-}"; then
    B105_ERRORS+=('Username is missing or invalid.')
  fi
  if [[ -z ${TIMEZONE:-} || $TIMEZONE == /* || $TIMEZONE == *'..'* || ! -f /usr/share/zoneinfo/${TIMEZONE:-__missing__} ]]; then
    B105_ERRORS+=('Timezone is missing or unavailable.')
  fi
  if [[ ! ${KEYMAP:-} =~ ^[A-Za-z0-9_+.-]+$ ]]; then
    B105_ERRORS+=('Console keymap is missing or invalid.')
  elif command -v localectl >/dev/null 2>&1 && localectl list-keymaps --no-pager 2>/dev/null | grep -Fxq -- "$KEYMAP"; then
    :
  elif [[ -d /usr/share/kbd/keymaps ]] && ! find /usr/share/kbd/keymaps -type f \( -name "${KEYMAP}.map" -o -name "${KEYMAP}.map.gz" -o -name "${KEYMAP}.map.xz" \) -print -quit 2>/dev/null | grep -q .; then
    B105_ERRORS+=('Console keymap not found in installed keymap catalog.')
  fi
  if [[ ! ${LOCALE:-} =~ ^[A-Za-z][A-Za-z0-9_@.-]*$ ]]; then
    B105_ERRORS+=('Locale is missing or invalid.')
  elif [[ ! -f /etc/locale.gen ]] || ! grep -Eq "^[#[:space:]]*${LOCALE//./\.}[[:space:]]" /etc/locale.gen; then
    B105_ERRORS+=('Locale is not listed in /etc/locale.gen.')
  fi
  ((${#B105_ERRORS[@]} == 0)) || return 1
  B105_STEPS+=(
    "Set /etc/hostname from approved hostname"
    "Generate /etc/hosts loopback entries for approved hostname"
    "Link /etc/localtime to approved zoneinfo entry and set hardware clock to UTC"
    "Enable selected locale in /etc/locale.gen; run locale-gen; set LANG in /etc/locale.conf"
    "Write selected console keymap to /etc/vconsole.conf"
    "Create approved unprivileged user and configure wheel group sudo access with validated sudoers permissions"
    "Prompt securely for root and user passwords during real installation; never store them in logs or plans"
    "Enable NetworkManager service in the installed system"
    "Check resulting files, accounts, services and permissions before bootloader stage"
    "On failure, stop; never claim transactional rollback of user or system configuration"
  )
}

b105_report() {
  local mode=${1:-} item
  printf 'B10.5 — SYSTEM CONFIGURATION PLAN (READ ONLY)\n\n'
  if ! b105_validate "$mode"; then
    printf 'BLOCKED:\n'
    for item in "${B105_ERRORS[@]}"; do printf '  - %s\n' "$item"; done
    printf '\nNo changes made.\n'
    return 1
  fi
  printf 'Disk: %s\nEFI policy: %s\nHostname: %s\nUsername: %s\nTimezone: %s\nKeymap: %s\nLocale: %s\nFilesystem: %s\nBootloader: %s\n\n' \
    "$DISK" "$mode" "$HOSTNAME" "$USERNAME" "$TIMEZONE" "$KEYMAP" "$LOCALE" "$FILESYSTEM" "$BOOTLOADER"
  for item in "${B105_STEPS[@]}"; do printf '[PLAN ONLY] %s\n' "$item"; done
  printf '\nB10.5 PLAN COMPLETE — no files written, no accounts created, no passwords changed. Real installation DISABLED.\n'
}

b105_menu() {
  local choice mode
  ui_heading 'B10.5 — System Configuration Plan (READ ONLY)'
  choice=$(ui_choose 'Select same EFI policy as B10.1' 'Create new EFI' 'Reuse existing EFI' 'Back') || return 0
  case "$choice" in
    'Create new EFI') mode=create ;;
    'Reuse existing EFI') mode=reuse ;;
    *) return 0 ;;
  esac
  ui_heading 'B10.5 — System Configuration Plan'
  b105_report "$mode" || true
  ui_pause
}

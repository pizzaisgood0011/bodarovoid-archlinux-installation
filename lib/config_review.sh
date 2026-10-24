#!/usr/bin/env bash
# B9.2: read-only review and explicit approval; never executes installation.
CONFIG_REVIEW_APPROVED=0
config_review_reset() { CONFIG_REVIEW_APPROVED=0; }
config_review_validate() {
  system_valid_hostname "${HOSTNAME:-}" || { printf 'Invalid hostname\n' >&2; return 1; }
  system_valid_username "${USERNAME:-}" || { printf 'Invalid username\n' >&2; return 1; }
  [[ -n ${TIMEZONE:-} && $TIMEZONE != /* && $TIMEZONE != *'..'* && -f /usr/share/zoneinfo/$TIMEZONE ]] || { printf 'Invalid timezone\n' >&2; return 1; }
  [[ -n ${KEYMAP:-} && $KEYMAP =~ ^[a-zA-Z0-9_+.-]+$ ]] || { printf 'Invalid keymap\n' >&2; return 1; }
  [[ -n ${LOCALE:-} && $LOCALE =~ ^[a-zA-Z0-9_@.-]+$ ]] || { printf 'Invalid locale\n' >&2; return 1; }
  [[ -r /etc/locale.gen ]] && grep -Eq "^[[:space:]]*#?[[:space:]]*${LOCALE//./\.}[[:space:]]+UTF-8([[:space:]]*)$" /etc/locale.gen || { printf 'Locale not present in locale.gen\n' >&2; return 1; }
}
config_review_menu() {
  config_review_reset
  ui_heading 'B9.2 — System Settings Review (READ ONLY)'
  system_status
  printf '\n'
  if ! config_review_validate; then
    ui_error 'Please correct system settings before approval.'
    ui_pause
    return 0
  fi
  ui_note 'No disk formatting, package installation, user creation, or password changes will occur.'
  printf '\n'
  local selection phrase
  selection=$(ui_choose 'Approve these system settings?' 'Approve settings (preview only)' 'Back without approval') || return 0
  [[ $selection == 'Approve settings (preview only)' ]] || return 0
  phrase=$(gum input --header 'Type APPROVE SETTINGS to confirm (no installation)' --placeholder 'APPROVE SETTINGS') || return 0
  if [[ $phrase == 'APPROVE SETTINGS' ]]; then
    CONFIG_REVIEW_APPROVED=1
    if declare -F b93_capture_approval >/dev/null; then b93_capture_approval || CONFIG_REVIEW_APPROVED=0; fi
    ui_note 'Settings approved for this session. Installation is NOT enabled.'
  else
    ui_error 'Approval canceled; settings unchanged.'
  fi
  ui_pause
}

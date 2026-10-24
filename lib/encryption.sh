#!/usr/bin/env bash
# Planning only. Encryption is not yet supported by the installation engine.
ENCRYPTION=${ENCRYPTION:-none}

encryption_menu() {
  local choice
  while true; do
    ui_heading 'Encryption (Root Encryption)'
    printf 'Root encryption: %s\n\n' "$ENCRYPTION"
    ui_note 'LUKS2 requires a passphrase during installation and at boot. EFI remains unencrypted.'
    ui_note 'No passwords or encryption keys are collected or stored.'
    printf '\n'
    choice=$(ui_choose 'Choose encryption' 'None (unencrypted)' 'LUKS2 (encrypted root)' 'Back') || return 0
    case "$choice" in
      'None (unencrypted)') ENCRYPTION=${ENCRYPTION:-none} ;;
      'LUKS2 (encrypted root)') ENCRYPTION='luks2' ;;
      Back) return 0 ;;
    esac
  done
}

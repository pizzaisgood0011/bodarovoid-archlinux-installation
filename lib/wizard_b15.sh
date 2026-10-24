#!/usr/bin/env bash
# Guided interface over the existing audited VirtualBox installation path.
b15_disk_summary() {
  printf 'Target disk: %s\n' "${DISK:-not selected}"
  if [[ -n ${DISK:-} && -b $DISK ]]; then
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS -- "$DISK"
  fi
  printf '\nEFI: %s | Swap: %s | Root: %s\n' "${EFI_PART:-unset}" "${SWAP_PART:-unset}" "${ROOT_PART:-unset}"
  printf 'Desktop: %s (%s)\n' "${DESKTOP:-none}" "${DESKTOP_INSTALL_TYPE:-Minimal}"
  printf 'Boot: %s | Filesystem: %s | Encryption: %s\n' "${BOOTLOADER:-unset}" "${FILESYSTEM:-unset}" "${ENCRYPTION:-none}"
}

b15_review() {
  ui_heading 'Review Installation'
  b15_disk_summary
  ui_install_warning
  printf '\nAll three partitions will be formatted by the installation engine.\n'
  printf 'The guided disk action erases the ENTIRE selected disk, if you choose to run it.\n'
  printf 'Physical disks require explicit opt-in and will be ENTIRELY ERASED. Back up first.\n\n'
  profile_show
  printf "\nSystem packages and AUR requests:\n"
  b17_show
  ui_pause
}

b15_guided_disk() {
  local action
  [[ -n ${DISK:-} ]] || { disk_select; [[ -n ${DISK:-} ]] || return 0; }
  ui_heading 'Partition Setup'
  b15_disk_summary
  printf '\nIf the three partitions already exist, ASSIGN them. Do not recreate GPT.\n'
  action=$(ui_choose 'Choose partition workflow' 'Use existing partitions (assign)' 'Erase selected disk and create GPT' 'Back') || return 0
  case "$action" in
    'Use existing partitions (assign)') partition_menu ;;
    'Erase selected disk and create GPT')
      b132_menu
      if [[ -n ${EFI_PART:-} && -n ${ROOT_PART:-} && -n ${SWAP_PART:-} ]]; then
        ui_note 'Partitions assigned. Complete all approvals again before installation.'
        ui_pause
      fi ;;
  esac
}

b15_desktop() {
  local choice
  choice=$(ui_choose 'Choose desktop' 'KDE Plasma' GNOME Hyprland 'No desktop' 'Back') || return 0
  [[ $choice == Back ]] && return 0
  if [[ $choice == 'No desktop' ]]; then DESKTOP=none; else DESKTOP=$choice; fi
  DESKTOP_INSTALL_TYPE=Minimal
  DESKTOP_EXTRA_SELECTED=()
  [[ $DESKTOP == none ]] || profile_menu
}

b15_safety() {
  local action
  while true; do
    ui_heading 'Safety Checks — Required Before Install'
    printf 'Complete the approvals in the order shown.\n'
    printf 'After changing partitions or system settings, repeat the checks.\n\n'
    action=$(ui_choose 'Choose next check' \
      '1. Review & approve settings' \
      '2. Approved settings handoff' \
      '3. Installation preflight' \
      '4. Target identity lock' \
      '5. Authorization rehearsal' \
      '6. Controlled execution readiness' \
      '7. Independent pre-write guards' \
      'Back') || return 0
    case "$action" in
      '1.'*) config_review_menu ;;
      '2.'*) b93_menu ;;
      '3.'*) b94_menu ;;
      '4.'*) b95_menu ;;
      '5.'*) b101_menu ;;
      '6.'*) b108_menu ;;
      '7.'*) b109_menu ;;
      Back) return 0 ;;
    esac
  done
}

b15_wizard() {
  local action
  while true; do
    ui_heading 'Bodarovoid — Fast Arch Installer (RC1)'
    b15_disk_summary
    printf '\nVM guests or explicitly opted-in physical disks. ALL target data will be lost.\n'
    action=$(ui_choose 'Installation steps' \
      '1. Select target disk' \
      '2. Prepare or assign partitions' \
      '3. Configure system' \
      '4. Choose desktop and packages' \
      '5. Customize system packages / online search' \
      '6. Review installation' \
      '7. Required safety approvals' \
      '8. Install Arch Linux' \
      'Advanced / legacy menu' \
      'Exit') || return 0
    case "$action" in
      '1.'*) disk_select ;;
      '2.'*) b15_guided_disk ;;
      '3.'*) system_menu ;;
      '4.'*) b15_desktop ;;
      '5.'*) b17_menu ;;
      '6.'*) b15_review ;;
      '7.'*) b15_safety ;;
      '8.'*) vm_install_menu ;;
      'Advanced / legacy menu') return 0 ;;
      Exit) exit 0 ;;
    esac
  done
}

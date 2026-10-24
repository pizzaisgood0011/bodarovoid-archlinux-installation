#!/usr/bin/env bash

# Read-only package planning. Never runs pacstrap or pacman -S.
PACKAGE_SELECTED_RECOMMENDED=("${PACKAGE_RECOMMENDED[@]}")
PACKAGE_SELECTED_OPTIONAL=()
PACKAGE_PLAN=()
PACKAGE_NOTES=()

packages_contains() {
  local sought=$1 item
  shift
  for item in "$@"; do [[ $item == "$sought" ]] && return 0; done
  return 1
}

packages_add() {
  local item
  for item in "$@"; do
    [[ -n $item ]] || continue
    if ! packages_contains "$item" "${PACKAGE_PLAN[@]}"; then
      PACKAGE_PLAN+=("$item")
    fi
  done
}

packages_note() { PACKAGE_NOTES+=("$1"); }

packages_build_plan() {
  PACKAGE_PLAN=()
  PACKAGE_NOTES=()
  packages_add base "$KERNEL" linux-firmware
  case "$FILESYSTEM" in
    ext4) packages_add e2fsprogs ;;
    btrfs) packages_add btrfs-progs ;;
    *) packages_note "Unsupported filesystem: $FILESYSTEM" ;;
  esac
  case "$BOOTLOADER" in
    GRUB) packages_add grub efibootmgr ;;
    Limine) packages_add limine efibootmgr ;;
    *) packages_note "Unsupported bootloader: $BOOTLOADER" ;;
  esac
  local cpu_vendor=$CPU
  if [[ $cpu_vendor == Auto ]]; then cpu_vendor=$(hardware_cpu_vendor); fi
  case "$cpu_vendor" in
    AMD) packages_add amd-ucode ;;
    Intel) packages_add intel-ucode ;;
    *) packages_note "CPU microcode requires review: $cpu_vendor" ;;
  esac
  case "$GPU" in
    AMD) packages_add mesa vulkan-radeon ;;
    Intel) packages_add mesa vulkan-intel ;;
    NVIDIA)
      packages_add nvidia-utils
      packages_note 'NVIDIA kernel-module package must be selected for the chosen kernel; automatic driver setup is not implemented.'
      ;;
    Auto) packages_note 'GPU Auto detection is not yet mapped to driver packages; review graphics drivers manually.' ;;
    None) ;;
    *) packages_note "Unknown graphics selection: $GPU" ;;
  esac
  case "$DESKTOP" in
    Hyprland|'KDE Plasma'|GNOME)
      local -a profile_list=()
      mapfile -t profile_list < <(profile_packages)
      packages_add "${profile_list[@]}"
      packages_note "Desktop preset: ${DESKTOP_INSTALL_TYPE:-Minimal}. This is a preview, NOT part of B11 real installation."
      ;;
    none) ;;
    *) packages_note "Unsupported desktop: $DESKTOP" ;;
  esac
  packages_add "${PACKAGE_SELECTED_RECOMMENDED[@]}" "${PACKAGE_SELECTED_OPTIONAL[@]}"
  packages_note 'Package plan only: bootloader, network, desktop, and encryption configuration are not performed.'
}

packages_select_recommended() {
  local selected entry
  local -a new_selection=()
  local csv=''
  local IFS=,
  csv="${PACKAGE_SELECTED_RECOMMENDED[*]}"
  selected=$(printf '%s\n' "${PACKAGE_RECOMMENDED[@]}" |
    gum choose --no-limit --selected "$csv" --header 'Recommended (Space toggle, Enter save, Esc cancel)' --height 18) || return 0
  if [[ -n $selected ]]; then
    while IFS= read -r entry; do [[ -n $entry ]] && new_selection+=("$entry"); done <<< "$selected"
  fi
  PACKAGE_SELECTED_RECOMMENDED=("${new_selection[@]}")
}

packages_select_optional() {
  local selected entry
  local -a new_selection=()
  local csv=''
  local IFS=,
  csv="${PACKAGE_SELECTED_OPTIONAL[*]}"
  selected=$(printf '%s\n' "${PACKAGE_OPTIONAL[@]}" |
    gum choose --no-limit --selected "$csv" --header 'Optional (Space toggle, Enter save, Esc cancel)' --height 18) || return 0
  if [[ -n $selected ]]; then
    while IFS= read -r entry; do [[ -n $entry ]] && new_selection+=("$entry"); done <<< "$selected"
  fi
  PACKAGE_SELECTED_OPTIONAL=("${new_selection[@]}")
}

packages_search_optional() {
  local choice
  choice=$(printf '%s\n' "${PACKAGE_OPTIONAL[@]}" |
    gum filter --placeholder 'Search optional packages...' --header 'Select one package (Esc cancel)' --height 18) || return 0
  [[ -n $choice ]] || return 0
  if packages_contains "$choice" "${PACKAGE_SELECTED_OPTIONAL[@]}"; then
    ui_note "$choice is already selected."
  else
    PACKAGE_SELECTED_OPTIONAL+=("$choice")
    ui_note "Added $choice."
  fi
  ui_pause
}

packages_show_plan() {
  packages_build_plan
  ui_heading 'Package Plan (Preview Only)'
  printf 'Kernel: %s | Bootloader: %s | Desktop: %s\n\n' "$KERNEL" "$BOOTLOADER" "$DESKTOP"
  printf 'Total: %d unique package names\n\n' "${#PACKAGE_PLAN[@]}"
  printf 'PACKAGES\n'
  printf '  %s\n' "${PACKAGE_PLAN[@]}"
  printf '\nNOTES\n'
  printf '  - %s\n' "${PACKAGE_NOTES[@]}"
  printf '\n'
  ui_note 'No packages have been installed.'
  ui_pause
}

packages_menu() {
  local action
  while true; do
    ui_heading 'Package Selection'
    printf 'Recommended: %d/%d selected\nOptional: %d selected\n\n' \
      "${#PACKAGE_SELECTED_RECOMMENDED[@]}" "${#PACKAGE_RECOMMENDED[@]}" "${#PACKAGE_SELECTED_OPTIONAL[@]}"
    action=$(ui_choose 'Choose package action' \
      'Recommended Packages' 'Optional Packages (Multi-select)' \
      'Search & Add Optional Package' 'Install Optional Later (Clear)' \
      'Restore Recommended Defaults' 'Review Package Plan' 'Back') || return 0
    case "$action" in
      'Recommended Packages') packages_select_recommended ;;
      'Optional Packages (Multi-select)') packages_select_optional ;;
      'Search & Add Optional Package') packages_search_optional ;;
      'Install Optional Later (Clear)') PACKAGE_SELECTED_OPTIONAL=() ;;
      'Restore Recommended Defaults') PACKAGE_SELECTED_RECOMMENDED=("${PACKAGE_RECOMMENDED[@]}") ;;
      'Review Package Plan') packages_show_plan ;;
      Back) return 0 ;;
    esac
  done
}

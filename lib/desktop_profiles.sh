#!/usr/bin/env bash
# B14 desktop profiles: locked essentials, optional recommended and full packages.
DESKTOP_INSTALL_TYPE='Minimal'
DESKTOP_EXTRA_SELECTED=()

profile_required() {
  case "${DESKTOP:-none}" in
    'KDE Plasma') printf '%s\n' plasma-desktop plasma-workspace sddm xorg-xwayland plasma-nm konsole dolphin pipewire pipewire-pulse wireplumber ;; 
    GNOME) printf '%s\n' gnome-shell gnome-session gdm gnome-control-center nautilus gnome-console gnome-keyring gvfs xdg-desktop-portal-gnome networkmanager pipewire pipewire-pulse wireplumber ;; 
    Hyprland) printf '%s\n' hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk kitty foot polkit waybar wofi network-manager-applet pipewire pipewire-pulse wireplumber mesa ;; 
    none) return 0 ;; *) return 1 ;;
  esac
}
profile_recommended() {
  case "${DESKTOP:-none}" in
    'KDE Plasma') printf '%s\n' ark spectacle kate ;; 
    GNOME) printf '%s\n' gnome-text-editor loupe file-roller ;; 
    Hyprland) printf '%s\n' mako grim slurp thunar pavucontrol ;; 
    none) return 0 ;; *) return 1 ;;
  esac
}
profile_full_extras() {
  case "${DESKTOP:-none}" in
    'KDE Plasma') printf '%s\n' firefox gwenview okular ;; 
    GNOME) printf '%s\n' firefox evince gnome-calculator ;; 
    Hyprland) printf '%s\n' firefox brightnessctl playerctl ;; 
    none) return 0 ;; *) return 1 ;;
  esac
}
profile_optional_catalog() { { profile_recommended; profile_full_extras; } | sed '/^$/d' | sort -u; }
profile_packages() {
  [[ ${DESKTOP:-none} == none ]] && return 0
  profile_required || return 1
  if [[ ${DESKTOP_INSTALL_TYPE:-Minimal} == Full ]]; then profile_recommended; profile_full_extras; fi
  printf '%s\n' "${DESKTOP_EXTRA_SELECTED[@]}" | sed '/^$/d'
}
profile_validate() {
  [[ ${DESKTOP:-none} == none || ${DESKTOP:-none} == 'KDE Plasma' || ${DESKTOP:-none} == GNOME || ${DESKTOP:-none} == Hyprland ]] || return 1
  [[ ${DESKTOP_INSTALL_TYPE:-Minimal} == Minimal || ${DESKTOP_INSTALL_TYPE:-Minimal} == Full ]] || return 1
  local item
  for item in "${DESKTOP_EXTRA_SELECTED[@]}"; do
    [[ $item =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || return 1
    profile_optional_catalog | grep -Fxq -- "$item" || return 1
  done
}
profile_describe() {
  case "$1" in
    sddm|gdm) printf 'Graphical login manager' ;;
    pipewire|pipewire-pulse|wireplumber) printf 'Audio service' ;;
    networkmanager|plasma-nm|network-manager-applet) printf 'Network connection controls' ;;
    firefox) printf 'Web browser' ;;
    kitty|konsole|gnome-console|foot) printf 'Terminal emulator' ;;
    dolphin|nautilus|thunar) printf 'File manager' ;;
    waybar) printf 'Wayland status bar' ;;
    wofi) printf 'Application launcher' ;;
    mako) printf 'Notifications' ;;
    grim|slurp|spectacle) printf 'Screenshots' ;;
    *) printf 'Desktop component or application' ;;
  esac
}
profile_show() {
  local pkg
  printf 'Desktop: %s | Preset: %s\n\n' "${DESKTOP:-none}" "$DESKTOP_INSTALL_TYPE"
  printf 'REQUIRED (locked)\n'
  while IFS= read -r pkg; do [[ -z $pkg ]] || printf '  + %-30s %s\n' "$pkg" "$(profile_describe "$pkg")"; done < <(profile_required)
  printf '\nOPTIONAL (selected by preset and customization)\n'
  while IFS= read -r pkg; do [[ -z $pkg ]] || printf '  + %-30s %s\n' "$pkg" "$(profile_describe "$pkg")"; done < <(profile_packages | sort -u | comm -23 - <(profile_required | sort -u))
  printf '\nDependencies are resolved by pacman at install time.\n'
}
profile_menu() {
  local choice selected item csv
  local -a options=() new=()
  while true; do
    ui_heading 'B14 — Desktop Package Configuration'
    profile_show
    choice=$(ui_choose 'Choose action' 'Minimal preset' 'Full preset' 'Customize optional packages' 'Show exact install list' 'Back') || return 0
    case "$choice" in
      'Minimal preset') DESKTOP_INSTALL_TYPE=Minimal; DESKTOP_EXTRA_SELECTED=() ;;
      'Full preset') DESKTOP_INSTALL_TYPE=Full; DESKTOP_EXTRA_SELECTED=() ;;
      'Customize optional packages')
        mapfile -t options < <(profile_optional_catalog)
        ((${#options[@]})) || { ui_note 'No optional packages.'; ui_pause; continue; }
        csv=$(IFS=,; echo "${DESKTOP_EXTRA_SELECTED[*]}")
        selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected "$csv" --header 'Space toggles, Enter saves' --height 16) || continue
        new=()
        while IFS= read -r item; do [[ -z $item ]] || new+=("$item"); done <<< "$selected"
        DESKTOP_EXTRA_SELECTED=("${new[@]}") ;;
      'Show exact install list') ui_heading 'Exact desktop packages'; profile_packages | sed '/^$/d' | sort -u; ui_pause ;;
      Back) return 0 ;;
    esac
  done
}

#!/usr/bin/env bash
# Read-only preflight. No formatting, mounting, installation or network mutation.
PREFLIGHT_ERRORS=()
PREFLIGHT_WARNINGS=()
PREFLIGHT_INFO=()
preflight_error() { PREFLIGHT_ERRORS+=("$1"); }
preflight_warn() { PREFLIGHT_WARNINGS+=("$1"); }
preflight_info() { PREFLIGHT_INFO+=("$1"); }

preflight_run() {
  PREFLIGHT_ERRORS=()
  PREFLIGHT_WARNINGS=()
  PREFLIGHT_INFO=()
  validation_run
  format_policy_build
  local format_issue
  for format_issue in "${FORMAT_ERRORS[@]}"; do preflight_error "$format_issue"; done
  for format_issue in "${FORMAT_WARNINGS[@]}"; do preflight_warn "$format_issue"; done
  if declare -F safety_run >/dev/null; then
    safety_run
    local issue
    for issue in "${SAFETY_ERRORS[@]}"; do preflight_error "$issue"; done
    for issue in "${SAFETY_WARNINGS[@]}"; do preflight_warn "$issue"; done
    for issue in "${SAFETY_INFO[@]}"; do preflight_info "$issue"; done
  fi
  local entry
  for entry in "${VALIDATION_ERRORS[@]}"; do preflight_error "$entry"; done
  for entry in "${VALIDATION_WARNINGS[@]}"; do
    if [[ $entry == 'EFI partition is not detected as FAT (vfat); future installation needs an explicit EFI formatting policy.' && $EFI_FORMAT_POLICY == new-fat32 ]]; then
      preflight_info 'New EFI is unformatted; the plan explicitly calls for FAT32 creation.'
    else
      preflight_warn "$entry"
    fi
  done

  if [[ ${ENCRYPTION:-none} != none ]]; then
    preflight_error 'LUKS2 is not implemented. Choose None; package selection alone cannot enable encrypted boot.'
  fi
  if [[ $BOOTLOADER == Limine ]]; then
    preflight_warn 'Limine boot-entry installation and update hooks have not been implemented or tested.'
  fi
  if [[ $GPU == NVIDIA || $GPU == Auto ]]; then
    preflight_warn 'Graphics driver and kernel compatibility require further verification.'
  fi
  if [[ $DESKTOP != none ]]; then
    preflight_warn 'Desktop login, audio, seat and session services are not configured yet.'
  fi
  if [[ -n ${ROOT_PART:-} && -b $ROOT_PART ]]; then
    local bytes
    bytes=$(lsblk -bdn -o SIZE "$ROOT_PART" 2>/dev/null || true)
    if [[ $bytes =~ ^[0-9]+$ ]]; then
      preflight_info "Root partition capacity: $((bytes / 1024 / 1024 / 1024)) GiB (raw partition size, not free space)."
      if (( bytes < 8 * 1024 * 1024 * 1024 )); then
        preflight_warn 'Root partition is under 8 GiB; a full desktop installation may not fit.'
      fi
    else
      preflight_warn 'Unable to determine root partition size.'
    fi
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    preflight_warn 'pacman is unavailable; package repository verification cannot run.'
  elif [[ ! -d /var/lib/pacman/sync ]] || ! compgen -G '/var/lib/pacman/sync/*.db' >/dev/null; then
    preflight_warn 'Local pacman sync databases are unavailable; package names cannot be verified offline.'
  else
    local -A known=()
    local name
    while IFS= read -r name; do [[ -n $name ]] && known["$name"]=1; done < <(pacman -Slq 2>/dev/null || true)
    if ((${#known[@]} == 0)); then
      preflight_warn 'Unable to read configured repository package lists.'
    else
      for name in "${PACKAGE_PLAN[@]}"; do
        [[ -n ${known[$name]+x} ]] || preflight_error "Package not found in enabled local repository databases: $name"
      done
      preflight_info 'Package names checked against local pacman repository databases (not a live download test).'
    fi
  fi
  if command -v ping >/dev/null 2>&1; then
    if ping -n -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
      preflight_info 'ICMP connectivity to 1.1.1.1 succeeded (repository access not guaranteed).'
    else
      preflight_warn 'ICMP connectivity test failed or is blocked; repository access remains unverified.'
    fi
  else
    preflight_warn 'ping is unavailable; network connectivity was not checked.'
  fi
  preflight_warn 'Installer execution is disabled; preflight passing does not authorize disk changes.'
}

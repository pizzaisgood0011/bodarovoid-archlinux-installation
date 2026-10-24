#!/usr/bin/env bash

# Read-only hardware detection. Does not install drivers.
hardware_cpu_vendor() {
  local vendor=''
  if [[ -r /proc/cpuinfo ]]; then
    vendor=$(awk -F: '/^vendor_id[[:space:]]*:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
  fi
  case "$vendor" in
    GenuineIntel) printf 'Intel\n' ;;
    AuthenticAMD) printf 'AMD\n' ;;
    *) printf 'Unknown (%s)\n' "${vendor:-unavailable}" ;;
  esac
}

hardware_cpu_model() {
  local model=''
  if command -v lscpu >/dev/null 2>&1; then
    model=$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -n 1)
  fi
  if [[ -z $model && -r /proc/cpuinfo ]]; then
    model=$(awk -F: '/^model name[[:space:]]*:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
  fi
  printf '%s\n' "${model:-Unavailable}"
}

hardware_gpu_list() {
  if ! command -v lspci >/dev/null 2>&1; then
    printf 'Unavailable (lspci is not installed)\n'
    return 0
  fi
  local result
  result=$(LC_ALL=C lspci 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)
  printf '%s\n' "${result:-No graphics controller detected}"
}

hardware_menu() {
  ui_heading 'Detected Hardware (read-only)'
  printf 'CPU vendor: %s\n' "$(hardware_cpu_vendor)"
  printf 'CPU model:  %s\n\n' "$(hardware_cpu_model)"
  printf 'Graphics devices:\n'
  hardware_gpu_list
  printf '\n'
  ui_note 'VirtualBox may report virtual graphics hardware.'
  ui_note 'Auto driver selection is not implemented yet.'
  ui_pause
}

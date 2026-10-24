#!/usr/bin/env bash

# Only whole physical disks are offered; optical and loop devices are excluded.
disk_select() {
  ui_heading 'Installation Disk'
  ui_note 'Select a physical disk. No changes will be made by selecting it.'
  printf '\n'

  local -a paths=() labels=()
  local name type size model choice i
  while read -r name type; do
    [[ $type == disk && -b $name ]] || continue
    size=$(lsblk -dn -o SIZE "$name" 2>/dev/null) || continue
    model=$(lsblk -dn -o MODEL "$name" 2>/dev/null) || model=''
    paths+=("$name")
    labels+=("$name  |  $size  |  ${model:-Unknown model}")
  done < <(lsblk -dn -p -o NAME,TYPE)

  if ((${#paths[@]} == 0)); then
    ui_error 'No physical disks detected.'
    ui_pause
    return 0
  fi
  choice=$(ui_choose 'Select installation disk' "${labels[@]}") || return 0
  for i in "${!labels[@]}"; do
    if [[ ${labels[$i]} == "$choice" ]]; then
      if [[ $DISK != "${paths[$i]}" ]]; then
        DISK=${paths[$i]}
        EFI_PART=''
        ROOT_PART=''
        SWAP_PART=''
      fi
      if declare -F safety_capture_disk >/dev/null; then
        safety_capture_disk || true
      fi
      return 0
    fi
  done
}

disk_open_cfdisk() {
  if [[ -z $DISK ]]; then
    ui_error 'Select an installation disk first.'
    ui_pause
    return 0
  fi
  ui_heading 'Partition Editor'
  ui_note "cfdisk will open for $DISK. Writing changes in cfdisk modifies the disk immediately."
  printf 'In cfdisk: ↑/↓ partitions  •  ←/→ actions  •  Enter select  •  Write save  •  Quit return\n\n'
  if gum confirm 'Open cfdisk?'; then
    cfdisk "$DISK" || { ui_error 'cfdisk returned an error.'; ui_pause; }
    partprobe "$DISK" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
    EFI_PART=''
    ROOT_PART=''
    SWAP_PART=''
  fi
}

disk_menu() {
  local action
  while true; do
    ui_heading 'Disk & Partitions'
    ui_status
    action=$(ui_choose 'Select an action' 'Change Disk' 'Open cfdisk' 'Assign Partitions' 'Back') || return 0
    case "$action" in
      'Change Disk') disk_select ;;
      'Open cfdisk') disk_open_cfdisk ;;
      'Assign Partitions') partition_menu ;;
      'Back') return 0 ;;
    esac
  done
}

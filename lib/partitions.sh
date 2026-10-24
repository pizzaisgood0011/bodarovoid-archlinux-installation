#!/usr/bin/env bash

partition_belongs_to_disk() {
  local candidate=$1 parent
  [[ -b $candidate && -n $DISK ]] || return 1
  parent=$(lsblk -dn -o PKNAME "$candidate" 2>/dev/null) || return 1
  [[ /dev/$parent == "$DISK" ]]
}

partition_select() {
  local purpose=$1 exclude1=${2:-} exclude2=${3:-}
  local -a paths=() labels=()
  local name type size fstype selected i

  # NAME and TYPE have no spaces; metadata is queried separately.
  while read -r name type; do
    [[ $type == part ]] || continue
    partition_belongs_to_disk "$name" || continue
    [[ $name != "$exclude1" && $name != "$exclude2" ]] || continue
    size=$(lsblk -dn -o SIZE "$name" 2>/dev/null) || continue
    fstype=$(lsblk -dn -o FSTYPE "$name" 2>/dev/null) || fstype=''
    paths+=("$name")
    labels+=("$name  |  $size  |  ${fstype:-Unformatted}")
  done < <(lsblk -ln -p -o NAME,TYPE "$DISK")

  if ((${#paths[@]} == 0)); then
    ui_error 'No available partitions. Create partitions in cfdisk first.'
    ui_pause
    return 1
  fi
  selected=$(ui_choose "Select $purpose" "${labels[@]}") || return 1
  for i in "${!labels[@]}"; do
    if [[ ${labels[$i]} == "$selected" ]]; then
      printf '%s' "${paths[$i]}"
      return 0
    fi
  done
  return 1
}

partition_menu() {
  if [[ -z $DISK ]]; then
    ui_error 'Select an installation disk first.'
    ui_pause
    return 0
  fi
  local action result
  while true; do
    ui_heading 'Assign Partitions'
    ui_status
    ui_note 'Assignments are saved in memory only. This prototype never formats partitions.'
    printf '\n'
    action=$(ui_choose 'Select an action' 'EFI System Partition' 'Root Partition (/)' 'Swap Partition' 'Clear Assignments' 'Back') || return 0
    case "$action" in
      'EFI System Partition')
        result=$(partition_select 'EFI System Partition' "$ROOT_PART" "$SWAP_PART") && EFI_PART=$result || true
        ;;
      'Root Partition (/)')
        result=$(partition_select 'Root Partition (/)' "$EFI_PART" "$SWAP_PART") && ROOT_PART=$result || true
        ;;
      'Swap Partition')
        result=$(ui_choose 'Swap partition' 'None' 'Select partition') || continue
        if [[ $result == None ]]; then
          SWAP_PART=''
        else
          result=$(partition_select 'Swap Partition' "$EFI_PART" "$ROOT_PART") && SWAP_PART=$result || true
        fi
        ;;
      'Clear Assignments') EFI_PART=''; ROOT_PART=''; SWAP_PART='' ;;
      'Back') return 0 ;;
    esac
  done
}

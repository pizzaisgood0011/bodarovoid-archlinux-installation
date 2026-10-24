#!/usr/bin/env bash
# v0.8 Stage A: classify formatting intent only. No writes, ever.
FORMAT_ERRORS=()
FORMAT_WARNINGS=()
FORMAT_OPERATIONS=()
EFI_FORMAT_POLICY='unresolved'
EFI_GPT_GUID='c12a7328-f81f-11d2-ba4b-00a0c93ec93b'

format_read_field() {
  local device=$1 field=$2
  [[ -n $device && -b $device ]] || return 1
  lsblk -dn -o "$field" -- "$device" 2>/dev/null | sed -n '1{s/^[[:space:]]*//;s/[[:space:]]*$//;p;}'
}

format_policy_build() {
  FORMAT_ERRORS=()
  FORMAT_WARNINGS=()
  FORMAT_OPERATIONS=()
  EFI_FORMAT_POLICY='unresolved'
  local fs type label
  if [[ -n ${EFI_PART:-} && -b ${EFI_PART:-} ]]; then
    fs=$(format_read_field "$EFI_PART" FSTYPE || true)
    type=$(format_read_field "$EFI_PART" PARTTYPE || true)
    type=${type,,}
    if [[ -z $type ]]; then
      FORMAT_ERRORS+=("Cannot verify EFI partition type for $EFI_PART; require GPT EFI System Partition.")
    elif [[ $type != "$EFI_GPT_GUID" ]]; then
      FORMAT_ERRORS+=("$EFI_PART is not GPT EFI System Partition type ($type).")
    fi
    if [[ $fs == vfat ]]; then
      EFI_FORMAT_POLICY='preserve'
      FORMAT_OPERATIONS+=("KEEP   Existing EFI FAT filesystem: $EFI_PART (NO FORMAT)")
    elif [[ -z $fs ]]; then
      # blkid probes signatures beyond what lsblk cached, fail closed on unknowns.
      if ! command -v wipefs >/dev/null 2>&1; then
        FORMAT_ERRORS+=("Cannot inspect EFI signatures: wipefs unavailable.")
      elif [[ -n $(wipefs -n --noheadings --output TYPE -- "$EFI_PART" 2>/dev/null) ]]; then
        FORMAT_ERRORS+=("EFI has an unrecognized signature despite empty FSTYPE: $EFI_PART")
      else
        EFI_FORMAT_POLICY='new-fat32'
        FORMAT_OPERATIONS+=("FORMAT New EFI FAT32 filesystem: $EFI_PART (DESTRUCTIVE, FUTURE ONLY)")
      fi
    else
      FORMAT_ERRORS+=("EFI $EFI_PART contains $fs, not FAT32; refusing to guess formatting policy.")
    fi
  fi
  if [[ -n ${ROOT_PART:-} && -b ${ROOT_PART:-} ]]; then
    case ${FILESYSTEM:-} in
      ext4|btrfs) FORMAT_OPERATIONS+=("FORMAT Root as $FILESYSTEM: $ROOT_PART (ERASE ALL DATA, FUTURE ONLY)") ;;
      *) FORMAT_ERRORS+=("Unsupported root filesystem: ${FILESYSTEM:-unset}") ;;
    esac
  fi
  if [[ -n ${SWAP_PART:-} && -b ${SWAP_PART:-} ]]; then
    FORMAT_OPERATIONS+=("FORMAT Initialize swap: $SWAP_PART (ERASE ALL DATA, FUTURE ONLY)")
  fi
  FORMAT_WARNINGS+=("Formatting is not implemented; this is a read-only policy preview.")
}

format_policy_menu() {
  format_policy_build
  ui_heading 'Formatting Policy (READ ONLY)'
  printf 'Target disk: %s\nEFI policy: %s\n\n' "${DISK:-Not selected}" "$EFI_FORMAT_POLICY"
  if ((${#FORMAT_OPERATIONS[@]})); then printf '%s\n' "${FORMAT_OPERATIONS[@]}"; fi
  printf '\nErrors: %d | Warnings: %d\n' "${#FORMAT_ERRORS[@]}" "${#FORMAT_WARNINGS[@]}"
  local issue
  for issue in "${FORMAT_ERRORS[@]}"; do printf 'ERROR: %s\n' "$issue"; done
  for issue in "${FORMAT_WARNINGS[@]}"; do printf 'WARN: %s\n' "$issue"; done
  printf '\n'
  ui_error 'READ ONLY: NO FORMATTING OR INSTALLATION COMMANDS EXECUTED.'
  ui_pause
}

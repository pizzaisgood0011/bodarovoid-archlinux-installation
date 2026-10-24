#!/usr/bin/env bash
# Stage B2: destructive VM-only executor; opt-in is required for every run.
FORMAT_EXEC_ENABLED=${LUCIOLE_ENABLE_VM_FORMAT:-0}

format_exec_vm_guard() {
  local vendor product diskbytes
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  # Conservative allowlist: only VirtualBox test guests.
  [[ $vendor == *innotek* || $vendor == *Oracle* || $product == *VirtualBox* ]] || return 1
  [[ $(lsblk -dn -o TRAN -- "$DISK" 2>/dev/null | tr -d '[:space:]') != usb ]] || return 1
  diskbytes=$(lsblk -bdn -o SIZE -- "$DISK" 2>/dev/null | tr -d '[:space:]') || return 1
  [[ $diskbytes =~ ^[0-9]+$ ]] && ((diskbytes > 0 && diskbytes <= 16*1024*1024*1024))
}

format_exec_dependencies() {
  local cmd
  for cmd in lsblk readlink wipefs findmnt swapon mkfs.fat mkfs.ext4 mkfs.btrfs mkswap blkid; do
    command -v "$cmd" >/dev/null 2>&1 || { ui_error "Missing required command: $cmd"; return 1; }
  done
}

format_exec_check() {
  FORMAT_CHECK_ERROR=""

  format_exec_fail() {
    FORMAT_CHECK_ERROR="$1"
    return 1
  }

  [[ $FORMAT_EXEC_ENABLED == 1 ]] ||
    { format_exec_fail "Real formatting is not enabled."; return 1; }

  format_exec_vm_guard ||
    { format_exec_fail "VirtualBox or disposable disk safety check failed."; return 1; }

  packages_build_plan ||
    { format_exec_fail "Could not build the package plan."; return 1; }

  preflight_run ||
    { format_exec_fail "Installation preflight could not complete."; return 1; }

  if (( ${#PREFLIGHT_ERRORS[@]} > 0 )); then
    FORMAT_CHECK_ERROR="Preflight errors:"
    local error
    for error in "${PREFLIGHT_ERRORS[@]}"; do
      FORMAT_CHECK_ERROR+=$'\n'"- $error"
    done
    return 1
  fi

  [[ $EFI_FORMAT_POLICY == preserve ||
     $EFI_FORMAT_POLICY == new-fat32 ]] ||
    { format_exec_fail "EFI formatting policy is invalid."; return 1; }

  [[ ${FILESYSTEM:-} == ext4 ||
     ${FILESYSTEM:-} == btrfs ]] ||
    { format_exec_fail "Filesystem must be ext4 or btrfs."; return 1; }

  [[ ${ENCRYPTION:-none} == none ]] ||
    { format_exec_fail "Encryption is not supported in Stage B2."; return 1; }

  [[ -n $DISK && -n $EFI_PART && -n $ROOT_PART ]] ||
    { format_exec_fail "Disk, EFI, or root partition is missing."; return 1; }

  [[ $DISK != "$EFI_PART" &&
     $EFI_PART != "$ROOT_PART" &&
     $ROOT_PART != "${SWAP_PART:-}" ]] ||
    { format_exec_fail "Partition selections overlap."; return 1; }

  [[ -z ${SWAP_PART:-} ||
     ( $SWAP_PART != "$EFI_PART" && $SWAP_PART != "$ROOT_PART" ) ]] ||
    { format_exec_fail "Swap partition overlaps another partition."; return 1; }

  local dev

  for dev in "$EFI_PART" "$ROOT_PART" "${SWAP_PART:-}"; do
    [[ -z $dev ]] && continue

    validation_is_partition_on_disk "$dev" ||
      { format_exec_fail "$dev is not on the selected disk."; return 1; }

    [[ -z $(lsblk -nr -o MOUNTPOINTS -- "$dev" 2>/dev/null |
      sed '/^[[:space:]]*$/d') ]] ||
      { format_exec_fail "$dev is mounted."; return 1; }

    [[ -z $(lsblk -nr -o NAME -- "$dev" 2>/dev/null |
      sed '1d') ]] ||
      { format_exec_fail "$dev contains child devices."; return 1; }

    [[ -d /sys/class/block/${dev##*/}/holders ]] ||
      { format_exec_fail "$dev holder information is unavailable."; return 1; }

    [[ -z $(find "/sys/class/block/${dev##*/}/holders" \
      -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]] ||
      { format_exec_fail "$dev has active device holders."; return 1; }
  done

  [[ -z $(swapon --noheadings --raw --output NAME 2>/dev/null) ]] ||
    { format_exec_fail "Swap is currently active."; return 1; }

  [[ $(lsblk -dn -o PTTYPE -- "$DISK" 2>/dev/null |
    tr -d '[:space:]') == gpt ]] ||
    { format_exec_fail "Selected disk must use GPT."; return 1; }

  [[ -z $(lsblk -nr -o MOUNTPOINTS -- "$DISK" 2>/dev/null |
    sed '/^[[:space:]]*$/d') ]] ||
    { format_exec_fail "Selected disk has mounted filesystems."; return 1; }

  return 0
}

format_exec_menu() {
  ui_heading 'Stage B2 / VirtualBox Formatting (DESTRUCTIVE)'
  printf 'Disk: %s\nEFI: %s\nRoot: %s (%s)\nSwap: %s\n\n' "${DISK:-none}" "${EFI_PART:-none}" "${ROOT_PART:-none}" "${FILESYSTEM:-unset}" "${SWAP_PART:-none}"
  if [[ $FORMAT_EXEC_ENABLED != 1 ]]; then
    ui_error 'LOCKED: real formatting is disabled.'
    ui_note 'For a disposable VirtualBox VM only, launch with LUCIOLE_ENABLE_VM_FORMAT=1.'
    ui_pause; return 0
  fi
  if ! format_exec_dependencies; then
  	ui_pause
  	return 0
  fi

  if ! format_exec_check; then
  	ui_error "BLOCKED: ${FORMAT_CHECK_ERROR:-Unknown validation failure.}"
  	ui_pause
  	return 0
  fi
  if ! format_review_capture; then
    ui_error 'BLOCKED: could not snapshot devices.'
    ui_pause; return 0
  fi
  printf '%s\n' "${FORMAT_OPERATIONS[@]}"
  printf '\nWARNING: These commands WILL DESTROY DATA on selected partitions.\n'
  if ! gum confirm 'Proceed with destructive formatting of the displayed partitions?'; then
    ui_note 'Cancelled; no writes.'; ui_pause; return 0
  fi
  local typed
  typed=$(gum input --prompt 'Type exact disk path: ') || return 0
  if [[ $typed != "$DISK" ]]; then ui_error 'Disk confirmation mismatch.'; ui_pause; return 0; fi
  typed=$(gum input --prompt 'Type FORMAT-VM to authorize real writes: ') || return 0
  if [[ $typed != FORMAT-VM ]]; then ui_error 'Confirmation mismatch.'; ui_pause; return 0; fi
  if ! format_exec_check || ! format_review_unchanged; then
    ui_error 'BLOCKED: device identity or safety state changed.'; ui_pause; return 0
  fi
  local logdir logfile
  logdir=/run/luciole
  mkdir -p -- "$logdir" || { ui_error 'Cannot create execution log.'; ui_pause; return 0; }
  logfile="$logdir/format-$(date +%Y%m%d-%H%M%S)-$$.log"
  printf 'BEGIN disk=%s efi=%s root=%s swap=%s filesystem=%s\n' "$DISK" "$EFI_PART" "$ROOT_PART" "${SWAP_PART:-none}" "$FILESYSTEM" > "$logfile"
  local action result=0
  # Snapshot comparisons must be refreshed after each successful write: formatting changes signatures.
  for action in efi root swap; do
    if ! format_exec_check || ! format_review_unchanged; then
      printf 'STOP safety revalidation failed before %s\n' "$action" >> "$logfile"
      result=1; break
    fi
    local -a command_args=()
    local target=''
    case $action in
      efi)
        [[ $EFI_FORMAT_POLICY == new-fat32 ]] || continue
        target=$EFI_PART; command_args=(mkfs.fat -F 32 "$target") ;;
      root)
        target=$ROOT_PART
        if [[ $FILESYSTEM == ext4 ]]; then command_args=(mkfs.ext4 -F -- "$target"); else command_args=(mkfs.btrfs -f -- "$target"); fi ;;
      swap)
        [[ -n ${SWAP_PART:-} ]] || continue
        target=$SWAP_PART; command_args=(mkswap -- "$target") ;;
    esac
    printf 'START %s target=%s\n' "$action" "$target" >> "$logfile"
    if "${command_args[@]}" >> "$logfile" 2>&1; then
      printf 'OK %s\n' "$action" >> "$logfile"
      # Refresh identity baseline after our own deliberate signature changes.
      format_review_capture || { result=1; break; }
    else
      printf 'FAILED %s\n' "$action" >> "$logfile"
      result=1; break
    fi
  done
  if ((result == 0)); then
    ui_note 'Formatting commands completed. Verify signatures before proceeding.'
  else
    ui_error 'STOPPED: one or more operations may already have changed the disk.'
  fi
  printf 'Execution log: %s\n' "$logfile"
  ui_pause
}

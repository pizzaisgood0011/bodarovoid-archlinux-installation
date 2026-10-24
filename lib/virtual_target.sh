#!/usr/bin/env bash
# VM and physical-disk safety checks; physical installation requires explicit opt-in.
bv_hypervisor() {
  local vendor product
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  case "$vendor:$product" in
    *innotek*:*VirtualBox*|*Oracle*:*VirtualBox*) printf 'virtualbox\n' ;;
    *VMware*:*|*:*VMware\ Virtual\ Platform*) printf 'vmware\n' ;;
    *) return 1 ;;
  esac
}
# Physical hardware is supported only with explicit, per-run opt-in.
# This guard rejects disks currently used by the live environment.
bv_disk_guard() {
  local disk=${1:-} hyper model tran name canonical parent
  BV_ERRORS=()
  hyper=$(bv_hypervisor 2>/dev/null || true)
  [[ -n $disk && -b $disk ]] || { BV_ERRORS+=('Invalid block disk.'); return 1; }
  canonical=$(readlink -f -- "$disk") || return 1
  [[ $canonical == "$disk" ]] || BV_ERRORS+=('Use canonical disk path.')
  [[ $(lsblk -dnro TYPE -- "$disk" 2>/dev/null) == disk ]] || BV_ERRORS+=('Whole disk required.')
  [[ $(blockdev --getro "$disk" 2>/dev/null) == 0 ]] || BV_ERRORS+=('Read-only disk.')
  tran=$(lsblk -dnro TRAN -- "$disk" 2>/dev/null | tr -d '[:space:]')
  model=$(cat "/sys/class/block/${disk##*/}/device/model" 2>/dev/null || true)
  case $hyper in
    virtualbox)
      [[ $model == *'VBOX HARDDISK'* ]] || BV_ERRORS+=('Not a VirtualBox virtual disk.') ;;
    vmware)
      [[ $model == *'VMware'*'Virtual'* || $model == *'VMware'*'Disk'* ]] || BV_ERRORS+=("Not a VMware virtual disk: $model") ;;
    *)
      [[ ${BODAROVOID_PHYSICAL_INSTALL:-} == I_UNDERSTAND_THIS_ERASES_A_REAL_DISK ]] || BV_ERRORS+=('Physical installation requires explicit opt-in: export BODAROVOID_PHYSICAL_INSTALL=I_UNDERSTAND_THIS_ERASES_A_REAL_DISK') ;;
  esac
  [[ $tran != usb ]] || BV_ERRORS+=('USB target disks are blocked.')
  [[ $(lsblk -dnro RM -- "$disk" 2>/dev/null | tr -d '[:space:]') == 0 ]] || BV_ERRORS+=('Removable disk blocked.')
  # Reject disks with any mounted descendant, active swap, or device-mapper holders.
  while IFS= read -r name; do
    [[ -b $name ]] || { BV_ERRORS+=("Missing descendant: $name"); continue; }
    if findmnt -rn -S "$name" >/dev/null 2>&1; then BV_ERRORS+=("Mounted: $name"); fi
    if swapon --noheadings --raw --show=NAME 2>/dev/null | grep -Fxq -- "$name"; then BV_ERRORS+=("Active swap: $name"); fi
    if [[ -d /sys/class/block/${name##*/}/holders ]] && compgen -G "/sys/class/block/${name##*/}/holders/*" >/dev/null; then
      BV_ERRORS+=("Device in use: $name")
    fi
  done < <(lsblk -rnpo NAME -- "$disk")
  ((${#BV_ERRORS[@]} == 0))
}
bv_partition_path() {
  local disk=$1 number=$2
  if [[ $disk =~ [0-9]$ ]]; then printf '%sp%s\n' "$disk" "$number"; else printf '%s%s\n' "$disk" "$number"; fi
}

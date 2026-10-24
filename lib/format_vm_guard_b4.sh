#!/usr/bin/env bash
# Source after lib/format_executor.sh to override only the VM disk guard.
format_exec_vm_guard() {
  local vendor product real_disk model serial diskbytes transport type
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) || return 1
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null) || return 1
  [[ $vendor == *innotek* || $vendor == *Oracle* || $product == *VirtualBox* ]] || return 1
  [[ -n ${DISK:-} && -b $DISK ]] || return 1
  real_disk=$(readlink -f -- "$DISK") || return 1
  transport=$(lsblk -dn -o TRAN -- "$real_disk" 2>/dev/null | xargs) || return 1
  [[ $transport != usb ]] || return 1
  type=$(lsblk -dn -o TYPE -- "$real_disk" 2>/dev/null | xargs) || return 1
  [[ $type == disk ]] || return 1
  model=$(lsblk -dn -o MODEL -- "$real_disk" 2>/dev/null | xargs) || return 1
  serial=$(lsblk -dn -o SERIAL -- "$real_disk" 2>/dev/null | xargs) || return 1
  diskbytes=$(lsblk -bdn -o SIZE -- "$real_disk" 2>/dev/null | xargs) || return 1
  [[ $model == 'VBOX HARDDISK' && $diskbytes =~ ^[0-9]+$ ]] || return 1
  case "$real_disk:$serial" in
    /dev/sdc:VBdbae79dc-71d4fb1a)
      (( diskbytes > 0 && diskbytes <= 16*1024*1024*1024 )) ;;
    /dev/sdb:VBf22ef975-eb672eca)
      (( diskbytes >= 70*1024*1024*1024 && diskbytes <= 80*1024*1024*1024 )) ;;
    *) return 1 ;;
  esac
}

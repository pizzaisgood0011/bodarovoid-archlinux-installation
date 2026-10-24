#!/usr/bin/env bash
# Read-only installation readiness check for the approved VirtualBox target.
set -u
errors=0
warnings=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; errors=$((errors+1)); }
warn() { printf 'WARN: %s\n' "$1"; warnings=$((warnings+1)); }
check_mount() {
  local path=$1 expected=$2 type=$3 actual fs
  actual=$(findmnt -rn -M "$path" -o SOURCE 2>/dev/null) || actual=''
  fs=$(findmnt -rn -M "$path" -o FSTYPE 2>/dev/null) || fs=''
  if [[ $actual == "$expected" && $fs == "$type" ]]; then pass "$path is $expected ($type)"; else fail "$path expected $expected ($type), found ${actual:-none} (${fs:-none})"; fi
}
printf '\nLuciole B4.0 | READ-ONLY preflight\n\n'
[[ $(id -u) -eq 0 ]] && pass 'Running as root' || fail 'Must run as root'
for tool in lsblk findmnt blkid swapon pacstrap genfstab; do
  command -v "$tool" >/dev/null 2>&1 && pass "Available: $tool" || fail "Missing: $tool"
done
vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [[ $vendor == *innotek* || $vendor == *Oracle* || $product == *VirtualBox* ]]; then pass 'VirtualBox guest detected'; else fail 'Not an approved VirtualBox guest'; fi
model=$(lsblk -dn -o MODEL -- /dev/sdb 2>/dev/null | xargs)
serial=$(lsblk -dn -o SERIAL -- /dev/sdb 2>/dev/null | xargs)
size=$(lsblk -bdn -o SIZE -- /dev/sdb 2>/dev/null | xargs)
transport=$(lsblk -dn -o TRAN -- /dev/sdb 2>/dev/null | xargs)
if [[ $model == 'VBOX HARDDISK' && $serial == 'VBf22ef975-eb672eca' && $size =~ ^[0-9]+$ ]] && (( size >= 70*1024*1024*1024 && size <= 80*1024*1024*1024 )) && [[ $transport != usb ]]; then
  pass 'Approved /dev/sdb model, serial, size and transport'
else fail 'Disk identity does not match approved /dev/sdb'; fi
for pair in 'sdb1:vfat' 'sdb2:swap' 'sdb3:ext4'; do
  dev=${pair%%:*}; expected=${pair#*:}
  actual=$(blkid -p -s TYPE -o value -- "/dev/$dev" 2>/dev/null) || actual=''
  [[ $actual == "$expected" ]] && pass "/dev/$dev filesystem $expected" || fail "/dev/$dev expected $expected, found ${actual:-none}"
done
check_mount /mnt /dev/sdb3 ext4
check_mount /mnt/boot /dev/sdb1 vfat
active=$(swapon --show=NAME --noheadings --raw 2>/dev/null) || { fail 'Cannot inspect active swap'; active=''; }
if [[ $active == /dev/sdb2 ]]; then pass 'Only /dev/sdb2 swap active'; else fail "Expected only /dev/sdb2 active swap, found ${active:-none}"; fi
if [[ -d /mnt/etc && -e /mnt/etc/os-release ]]; then warn 'Existing OS detected in /mnt; review before installing'; else pass 'No existing /mnt/etc/os-release detected'; fi
if [[ -d /mnt/var/lib/pacman/local && -n $(find /mnt/var/lib/pacman/local -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]]; then warn 'Pacman package database already exists under /mnt'; fi
if command -v ping >/dev/null 2>&1 && ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then pass 'Network ICMP check'; else warn 'Ping to archlinux.org failed (ICMP may be blocked); verify connectivity separately'; fi
printf '\nRESULT: %s error(s), %s warning(s).\n' "$errors" "$warnings"
if (( errors == 0 )); then printf 'B4.0 PREFLIGHT PASSED. NO INSTALLATION PERFORMED.\n'; else printf 'B4.0 PREFLIGHT BLOCKED. NO INSTALLATION PERFORMED.\n'; fi
exit "$((errors > 0))"

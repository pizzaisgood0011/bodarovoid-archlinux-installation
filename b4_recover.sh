#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
fail() { printf 'BLOCKED: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
[[ $EUID -eq 0 ]] || fail 'Run as root in the Arch ISO.'
[[ ${LUCIOLE_ENABLE_VM_RECOVERY:-0} == 1 ]] || fail 'Recovery disabled; set LUCIOLE_ENABLE_VM_RECOVERY=1.'
[[ -f ./luciole-b4-preflight-patch/b4_preflight.sh ]] || fail 'Run from repository root with B4.0 present.'
for cmd in pacstrap genfstab findmnt blkid lsblk swapon tee gum pacman-key readlink find grep awk mktemp; do
  command -v "$cmd" >/dev/null || fail "Missing command: $cmd"
done
packages=(base linux linux-firmware e2fsprogs grub efibootmgr networkmanager sudo base-devel git nano)
check_target() {
  local root_src efi_src swaps entries unexpected
  [[ $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == *innotek* || $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == *Oracle* || $(cat /sys/class/dmi/id/product_name 2>/dev/null) == *VirtualBox* ]] || fail 'Not a VirtualBox guest.'
  [[ $(readlink -f /dev/sdb) == /dev/sdb ]] || fail 'Unexpected disk path.'
  [[ $(lsblk -dn -o TYPE /dev/sdb | xargs) == disk ]] || fail 'Target not a disk.'
  [[ $(lsblk -dn -o MODEL /dev/sdb | xargs) == 'VBOX HARDDISK' ]] || fail 'Disk model mismatch.'
  [[ $(lsblk -dn -o SERIAL /dev/sdb | xargs) == 'VBf22ef975-eb672eca' ]] || fail 'Disk serial mismatch.'
  local size
  size=$(lsblk -bdn -o SIZE /dev/sdb | xargs)
  [[ $size =~ ^[0-9]+$ ]] && (( size >= 70*1024*1024*1024 && size <= 80*1024*1024*1024 )) || fail 'Disk size mismatch.'
  [[ $(lsblk -dn -o TRAN /dev/sdb | xargs) != usb ]] || fail 'USB disk blocked.'
  root_src=$(findmnt -rn -M /mnt -o SOURCE) || fail 'Root not mounted.'
  efi_src=$(findmnt -rn -M /mnt/boot -o SOURCE) || fail 'EFI not mounted.'
  [[ $(readlink -f -- "$root_src") == /dev/sdb3 ]] || fail 'Wrong root mount.'
  [[ $(readlink -f -- "$efi_src") == /dev/sdb1 ]] || fail 'Wrong EFI mount.'
  [[ $(findmnt -rn -M /mnt -o FSTYPE) == ext4 ]] || fail 'Root must be ext4.'
  [[ $(findmnt -rn -M /mnt/boot -o FSTYPE) == vfat ]] || fail 'EFI must be vfat.'
  [[ $(blkid -p -s TYPE -o value /dev/sdb2) == swap ]] || fail 'Wrong swap filesystem.'
  swaps=$(swapon --show=NAME --noheadings --raw) || fail 'Cannot inspect swap.'
  [[ $swaps == /dev/sdb2 ]] || fail 'Unexpected active swap.'
  [[ ! -e /mnt/etc/os-release && ! -e /mnt/usr/bin/pacman && ! -e /mnt/etc/fstab ]] || fail 'Target may already be installed.'
  [[ -d /mnt/var/lib/pacman/local ]] || fail 'Expected interrupted pacstrap database missing.'
  unexpected=$(find /mnt/var/lib/pacman/local -mindepth 1 -maxdepth 1 ! -name ALPM_DB_VERSION -print -quit) || fail 'Cannot inspect package database.'
  [[ -z $unexpected ]] || fail 'Installed package records exist; refusing recovery.'
  unexpected=$(find /mnt -mindepth 1 -maxdepth 1 ! -name boot ! -name lost+found ! -name proc ! -name var ! -name etc ! -name run ! -name sys ! -name tmp ! -name dev ! -name root -print -quit) || fail 'Cannot inspect root directory.'
  [[ -z $unexpected ]] || fail "Unexpected root entry: $unexpected"
  [[ ! -e /mnt/usr && ! -e /mnt/bin && ! -e /mnt/lib && ! -e /mnt/sbin ]] || fail 'Target contains system binaries; manual inspection required.'
  [[ -d /mnt/etc/pacman.d/gnupg ]] || fail 'Target keyring missing.'
  [[ -z $(find /mnt/boot -mindepth 1 -maxdepth 1 ! -name 'System Volume Information' -print -quit) ]] || fail 'EFI is not empty.'
  pacman-key --gpgdir /mnt/etc/pacman.d/gnupg --list-keys '991F6E3F0765CF6295888586139B09DA5BF0D338' >/dev/null 2>&1 || fail 'Current David Runge key missing from target keyring.'
}
info 'Luciole B4.2 | INTERRUPTED PACSTRAP RECOVERY'
info 'ONLY for the approved /dev/sdb VirtualBox VM; does not format or clear caches.'
info 'Running read-only B4.0 checks (existing pacman DB warning expected)...'
bash ./luciole-b4-preflight-patch/b4_preflight.sh || fail 'B4.0 failed.'
check_target
printf 'Packages: %s\n' "${packages[*]}"
gum confirm 'Resume pacstrap on the approved /dev/sdb target?' || fail 'Cancelled.'
typed=$(gum input --prompt 'Type exact disk path (/dev/sdb): ') || fail 'Cancelled.'
[[ $typed == /dev/sdb ]] || fail 'Disk confirmation mismatch.'
typed=$(gum input --prompt 'Type RECOVER-VM: ') || fail 'Cancelled.'
[[ $typed == RECOVER-VM ]] || fail 'Authorization mismatch.'
bash ./luciole-b4-preflight-patch/b4_preflight.sh || fail 'B4.0 recheck failed.'
check_target
mkdir -p ./luciole-install-logs
log="./luciole-install-logs/b4-recovery-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
info "Recovery log: $log"
info 'Starting pacstrap with the repaired target keyring; package signatures remain enforced.'
set +e
pacstrap -K /mnt "${packages[@]}" 2>&1 | tee -a "$log"
result=${PIPESTATUS[0]}
set -e
(( result == 0 )) || fail "pacstrap failed ($result). Do not retry blindly. Inspect $log."
[[ $(readlink -f -- "$(findmnt -rn -M /mnt -o SOURCE)") == /dev/sdb3 ]] || fail 'Root mount changed.'
[[ $(readlink -f -- "$(findmnt -rn -M /mnt/boot -o SOURCE)") == /dev/sdb1 ]] || fail 'EFI mount changed.'
[[ -f /mnt/usr/bin/pacman && -f /mnt/etc/os-release ]] || fail 'Base installation not detected.'
[[ ! -e /mnt/etc/fstab ]] || fail 'fstab exists; refusing overwrite.'
tmp=$(mktemp /mnt/etc/.fstab.luciole.XXXXXX) || fail 'Cannot create fstab temp file.'
if ! genfstab -U /mnt > "$tmp"; then rm -f -- "$tmp"; fail 'genfstab failed.'; fi
root_uuid=$(blkid -s UUID -o value /dev/sdb3) || fail 'Root UUID unavailable.'
efi_uuid=$(blkid -s UUID -o value /dev/sdb1) || fail 'EFI UUID unavailable.'
[[ -n $root_uuid && -n $efi_uuid ]] || fail 'Missing UUID.'
grep -Fq "UUID=$root_uuid" "$tmp" || fail 'Root UUID missing from fstab.'
grep -Fq "UUID=$efi_uuid" "$tmp" || fail 'EFI UUID missing from fstab.'
awk '$1 !~ /^#/ && NF>=2 {print $2}' "$tmp" | grep -Fxq / || fail 'Root entry missing.'
awk '$1 !~ /^#/ && NF>=2 {print $2}' "$tmp" | grep -Fxq /boot || fail 'EFI entry missing.'
chmod 644 "$tmp"
[[ ! -e /mnt/etc/fstab ]] || fail 'fstab appeared unexpectedly.'
mv -n -- "$tmp" /mnt/etc/fstab
[[ -s /mnt/etc/fstab ]] || fail 'fstab not created.'
info 'B4.2 PASSED: Arch base installed and fstab generated. NOT BOOTABLE YET; DO NOT REBOOT.'

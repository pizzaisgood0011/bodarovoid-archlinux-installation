#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

fail() { printf 'BLOCKED: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

[[ $EUID -eq 0 ]] || fail 'Run as root in the Arch ISO.'
[[ ${LUCIOLE_ENABLE_VM_INSTALL:-0} == 1 ]] || fail 'Execution disabled. Set LUCIOLE_ENABLE_VM_INSTALL=1 explicitly.'
[[ -f ./luciole-b4-preflight-patch/b4_preflight.sh ]] || fail 'Run from repository root with B4.0 preflight patch present.'
for cmd in pacstrap genfstab findmnt blkid lsblk swapon tee gum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"
done

# Install a conservative base only; desktop and bootloader setup are later stages.
packages=(base linux linux-firmware e2fsprogs grub efibootmgr networkmanager sudo base-devel git nano)

check_target() {
  local src boot swaps fstype bootfs
  src=$(findmnt -rn -M /mnt -o SOURCE) || fail 'Root mount is missing.'
  boot=$(findmnt -rn -M /mnt/boot -o SOURCE) || fail 'EFI mount is missing.'
  [[ $(readlink -f -- "$src") == /dev/sdb3 ]] || fail "Unexpected root source: $src"
  [[ $(readlink -f -- "$boot") == /dev/sdb1 ]] || fail "Unexpected EFI source: $boot"
  fstype=$(findmnt -rn -M /mnt -o FSTYPE) || fail 'Cannot read root filesystem.'
  bootfs=$(findmnt -rn -M /mnt/boot -o FSTYPE) || fail 'Cannot read EFI filesystem.'
  [[ $fstype == ext4 && $bootfs == vfat ]] || fail 'Unexpected filesystem types.'
  swaps=$(swapon --show=NAME --noheadings --raw) || fail 'Cannot inspect swap.'
  [[ $swaps == /dev/sdb2 ]] || fail "Unexpected active swap: $swaps"
  [[ ! -e /mnt/etc/os-release && ! -e /mnt/etc/fstab && ! -e /mnt/usr/bin/pacman && ! -e /mnt/var/lib/pacman/local ]] || fail 'Target appears to have an existing or partial installation.'
  [[ -z $(find /mnt -mindepth 1 -maxdepth 1 ! -name boot -print -quit) ]] || fail 'Root filesystem is not empty apart from boot.'
  [[ -z $(find /mnt/boot -mindepth 1 -maxdepth 1 ! -name 'System Volume Information' -print -quit) ]] || fail 'EFI filesystem is not empty.'
}

info 'Luciole B4.1 | GUARDED INSTALLATION'
info 'Target: /dev/sdb (VirtualBox approved test disk)'
info 'Root: /dev/sdb3 -> /mnt; EFI: /dev/sdb1 -> /mnt/boot; swap: /dev/sdb2'
printf 'Packages: %s\n' "${packages[*]}"
info 'No formatting will be performed. Pacstrap writes an Arch system to /mnt.'
info 'Running B4.0 preflight...'
bash ./luciole-b4-preflight-patch/b4_preflight.sh || fail 'B4.0 preflight failed.'
check_target

gum confirm 'Install the Arch base system to the mounted /dev/sdb target?' || fail 'Cancelled.'
typed=$(gum input --prompt 'Type exact disk path (/dev/sdb): ') || fail 'Cancelled.'
[[ $typed == /dev/sdb ]] || fail 'Disk confirmation mismatch.'
typed=$(gum input --prompt 'Type INSTALL-VM: ') || fail 'Cancelled.'
[[ $typed == INSTALL-VM ]] || fail 'Authorization mismatch.'

# Revalidate after interactive confirmation.
bash ./luciole-b4-preflight-patch/b4_preflight.sh || fail 'B4.0 preflight failed on recheck.'
check_target

logdir=./luciole-install-logs
mkdir -p -- "$logdir"
log="$logdir/b4-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
info "Installation log: $log"
info 'Starting pacstrap. If interrupted, DO NOT rerun without inspecting the target.'
set +e
pacstrap -K /mnt "${packages[@]}" 2>&1 | tee -a "$log"
result=${PIPESTATUS[0]}
set -e
((result == 0)) || fail "pacstrap failed (exit $result). Partial installation may exist. Inspect $log."

# Ensure EFI/root still refer to the approved mounted partitions before fstab.
[[ $(readlink -f -- "$(findmnt -rn -M /mnt -o SOURCE)") == /dev/sdb3 ]] || fail 'Root mount changed after pacstrap.'
[[ $(readlink -f -- "$(findmnt -rn -M /mnt/boot -o SOURCE)") == /dev/sdb1 ]] || fail 'EFI mount changed after pacstrap.'
[[ ! -e /mnt/etc/fstab ]] || fail 'fstab already exists; refusing overwrite.'
[[ -d /mnt/etc ]] || fail 'pacstrap did not create /mnt/etc.'
tmp=$(mktemp /mnt/etc/.fstab.luciole.XXXXXX) || fail 'Cannot create temporary fstab.'
if ! genfstab -U /mnt > "$tmp"; then
  rm -f -- "$tmp"
  fail 'genfstab failed.'
fi
root_uuid=$(blkid -s UUID -o value /dev/sdb3) || fail 'Cannot read root UUID.'
efi_uuid=$(blkid -s UUID -o value /dev/sdb1) || fail 'Cannot read EFI UUID.'
[[ -n $root_uuid && -n $efi_uuid ]] || fail 'Missing partition UUID.'
grep -Fq "UUID=$root_uuid" "$tmp" || fail 'Generated fstab missing root UUID.'
grep -Fq "UUID=$efi_uuid" "$tmp" || fail 'Generated fstab missing EFI UUID.'
awk '$1 !~ /^#/ && NF >= 2 {print $2}' "$tmp" | grep -Fxq / || fail 'Generated fstab missing / mount.'
awk '$1 !~ /^#/ && NF >= 2 {print $2}' "$tmp" | grep -Fxq /boot || fail 'Generated fstab missing /boot mount.'
chmod 644 "$tmp"
mv -n -- "$tmp" /mnt/etc/fstab || fail 'Cannot install fstab.'
[[ -f /mnt/etc/fstab ]] || fail 'fstab not created.'
info 'B4.1 PASSED: base packages installed and UUID fstab generated.'
info 'System is NOT bootable yet. Do not reboot; continue with chroot and bootloader stages.'

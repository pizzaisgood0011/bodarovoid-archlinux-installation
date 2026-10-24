#!/usr/bin/env bash
# B11: explicitly destructive, VirtualBox/VMware virtual machine installation path.
# Experimental ext4/Btrfs and GRUB/Limine UEFI paths, optional LUKS2 root.
VM_INSTALL_MOUNTS=()
VM_INSTALL_SWAP=''
VM_INSTALL_STARTED=0
VM_INSTALL_FINISHED=0
VM_CRYPT_OPEN=0
VM_ROOT_DEVICE=''

vm_install_is_virtualbox() {
  [[ $(cat /sys/class/dmi/id/product_name 2>/dev/null) == 'VirtualBox' ]] &&
    [[ $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == 'innotek GmbH' ||
       $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == 'Oracle Corporation' ]]
}

vm_install_check() {
  local dev parttype fstype fp snap k name
  VM_INSTALL_ERRORS=()
  [[ $EUID -eq 0 ]] || VM_INSTALL_ERRORS+=('Requires root.')
  if ! bv_disk_guard "${DISK:-}"; then VM_INSTALL_ERRORS+=("${BV_ERRORS[@]}"); fi
  [[ -d /sys/firmware/efi ]] || VM_INSTALL_ERRORS+=('UEFI live boot required.')
  [[ ${FILESYSTEM:-} == ext4 || ${FILESYSTEM:-} == btrfs ]] || VM_INSTALL_ERRORS+=('Filesystem must be ext4 or btrfs.')
  [[ ${BOOTLOADER:-} == GRUB || ${BOOTLOADER:-} == Limine ]] || VM_INSTALL_ERRORS+=('Bootloader must be GRUB or Limine.')
  [[ ${ENCRYPTION:-none} == none || ${ENCRYPTION:-none} == luks2 ]] || VM_INSTALL_ERRORS+=('Encryption must be none or luks2.')
  b17_validate || VM_INSTALL_ERRORS+=('Invalid system package selection.')
  if ! curl -fsSL --connect-timeout 4 --max-time 12 --range 0-1023 https://archlinux.org/ -o /dev/null >/dev/null 2>&1; then
    VM_INSTALL_ERRORS+=('Network or HTTPS unavailable. Check DNS, clock, and internet before retrying.')
  fi
  local pkg
  while IFS= read -r pkg; do
    [[ -n $pkg ]] || continue
    if ! pacman -Si -- "$pkg" >/dev/null 2>&1; then
      VM_INSTALL_ERRORS+=("Official package unavailable in local repositories: $pkg")
    fi
  done < <(b17_official_packages)

  profile_validate || VM_INSTALL_ERRORS+=('Invalid desktop profile or optional package selection.')
  [[ ${KERNEL:-} == linux || ${KERNEL:-} == linux-lts || ${KERNEL:-} == linux-zen ]] || VM_INSTALL_ERRORS+=('Unsupported kernel.')
  [[ -n ${SWAP_PART:-} ]] || VM_INSTALL_ERRORS+=('A separate swap partition is required by this release.')
  if ! declare -F b109_check >/dev/null || ! b109_check create; then
    VM_INSTALL_ERRORS+=('B10.9 safety guards are blocked or stale.')
  fi
  [[ -n ${B109_FINGERPRINT:-} && ${B109_MODE:-} == create && -n ${B109_SNAPSHOT:-} ]] || VM_INSTALL_ERRORS+=('Complete B10.9 confirmation in this session.')
  fp=$(b95_fingerprint 2>/dev/null) || fp=''
  snap=$(b101_snapshot create 2>/dev/null) || snap=''
  [[ -n $fp && $fp == "${B109_FINGERPRINT:-}" && -n $snap && $snap == "${B109_SNAPSHOT:-}" ]] || VM_INSTALL_ERRORS+=('Target or settings changed after guard rehearsal.')
  for k in pacstrap genfstab arch-chroot mkfs.fat mkfs.ext4 mkswap mount umount swapon swapoff blkid lsblk findmnt; do
    command -v "$k" >/dev/null 2>&1 || VM_INSTALL_ERRORS+=("Missing command: $k")
  done
  # Ensure every selected partition belongs to the selected disk and no two roles overlap.
  if [[ -n ${DISK:-} ]]; then
    local role device parent
    local -a selected=("${EFI_PART:-}" "${ROOT_PART:-}" "${SWAP_PART:-}")
    [[ ${selected[0]} != "${selected[1]}" && ${selected[0]} != "${selected[2]}" && ${selected[1]} != "${selected[2]}" ]] || VM_INSTALL_ERRORS+=('EFI, root and swap must be distinct partitions.')
    for role in EFI ROOT SWAP; do
      case $role in EFI) device=${EFI_PART:-} ;; ROOT) device=${ROOT_PART:-} ;; SWAP) device=${SWAP_PART:-} ;; esac
      [[ -n $device && -b $device ]] || { VM_INSTALL_ERRORS+=("$role partition is missing or not a block device."); continue; }
      parent=$(lsblk -dnro PKNAME -- "$device" 2>/dev/null) || parent=''
      [[ -n $parent && /dev/$parent == "$DISK" ]] || VM_INSTALL_ERRORS+=("$role partition does not belong directly to the selected disk.")
    done
  fi
  [[ ! -e /mnt/etc/fstab ]] || VM_INSTALL_ERRORS+=('/mnt contains an existing installation; refuse to overwrite.')
  [[ ! -e /dev/mapper/bodarovoid-root ]] || VM_INSTALL_ERRORS+=('Existing bodarovoid-root mapper is open. Close it safely before retrying.')
  [[ -z $(findmnt -rn --target /mnt 2>/dev/null | awk '$1=="/mnt" {print}') ]] || VM_INSTALL_ERRORS+=('/mnt is mounted.')
  if [[ -n ${EFI_PART:-} ]]; then
    parttype=$(lsblk -dn -o PARTTYPE -- "$EFI_PART" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    [[ $parttype == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] || VM_INSTALL_ERRORS+=('EFI partition type invalid.')
    fstype=$(blkid -p -s TYPE -o value -- "$EFI_PART" 2>/dev/null || true)
    [[ -z $fstype ]] || VM_INSTALL_ERRORS+=('EFI partition already has a filesystem; CREATE policy refuses to overwrite it.')
  fi
  if [[ -n ${ROOT_PART:-} ]]; then
    parttype=$(lsblk -dn -o PARTTYPE -- "$ROOT_PART" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    [[ $parttype == 0fc63daf-8483-4772-8e79-3d69d8477de4 ]] || VM_INSTALL_ERRORS+=('Root partition must have Linux filesystem GPT type.')
  fi
  if [[ ${FILESYSTEM:-} == btrfs ]]; then command -v mkfs.btrfs >/dev/null || VM_INSTALL_ERRORS+=('btrfs-progs missing on ISO.'); fi
  if [[ ${ENCRYPTION:-none} == luks2 ]]; then command -v cryptsetup >/dev/null || VM_INSTALL_ERRORS+=('cryptsetup missing on ISO.'); fi
  ((${#VM_INSTALL_ERRORS[@]} == 0))
}

vm_install_cleanup() {
  local i
  if [[ -n $VM_INSTALL_SWAP ]]; then swapoff -- "$VM_INSTALL_SWAP" || true; VM_INSTALL_SWAP=''; fi
  for ((i=${#VM_INSTALL_MOUNTS[@]}-1; i>=0; i--)); do
    umount -- "${VM_INSTALL_MOUNTS[i]}" || true
  done
  VM_INSTALL_MOUNTS=()
  if [[ $VM_CRYPT_OPEN == 1 ]]; then cryptsetup close bodarovoid-root || true; VM_CRYPT_OPEN=0; fi
}

vm_install_write_config() {
  local microcode=$1
  printf '%s\n' "$HOSTNAME" > /mnt/etc/hostname
  printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME" "$HOSTNAME" > /mnt/etc/hosts
  ln -sfn -- "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
  printf 'LANG=%s\n' "$LOCALE" > /mnt/etc/locale.conf
  printf 'KEYMAP=%s\n' "$KEYMAP" > /mnt/etc/vconsole.conf
  # Match the exact locale identifier rather than constructing a sed expression from it.
  awk -v locale="$LOCALE" '{ line=$0; sub(/^[[:space:]]*#[[:space:]]*/, "", line); split(line, fields, /[[:space:]]+/); if (fields[1]==locale && fields[2]=="UTF-8") print line; else print $0 }' /mnt/etc/locale.gen > /mnt/etc/locale.gen.new
  mv -- /mnt/etc/locale.gen.new /mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  arch-chroot /mnt hwclock --systohc --utc
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash -- "$USERNAME"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' > /mnt/etc/sudoers.d/10-bodarovoid-wheel
  chmod 0440 /mnt/etc/sudoers.d/10-bodarovoid-wheel
  arch-chroot /mnt visudo -cf /etc/sudoers
  arch-chroot /mnt systemctl enable NetworkManager
  case ${DESKTOP:-none} in
    'KDE Plasma') arch-chroot /mnt systemctl enable sddm ;;
    GNOME) arch-chroot /mnt systemctl enable gdm ;;
    Hyprland)
      # No display manager: start a Hyprland session after TTY login.
      install -d -m 0755 /mnt/etc/skel
      printf '%s\n' '# Run Hyprland from a TTY after logging in.' > /mnt/etc/skel/README-hyprland.txt
      ;;
  esac
  printf '\nSet ROOT password (input hidden by passwd):\n'
  arch-chroot /mnt passwd root
  printf '\nSet password for %s (input hidden by passwd):\n' "$USERNAME"
  arch-chroot /mnt passwd -- "$USERNAME"
  if ! vm_install_configure_bootloader; then
    echo "Bodarovoid: $BOOTLOADER bootloader setup failed; see diagnostics above." >&2
    return 1
  fi
  [[ -s /mnt/boot/vmlinuz-$KERNEL ]] || { echo "Missing installed kernel: /boot/vmlinuz-$KERNEL" >&2; return 1; }
}

vm_install_configure_bootloader() {
  local root_uuid crypt_uuid kernel_path initrd_path opts efi_file microcode_file
  root_uuid=$(blkid -s UUID -o value -- "$VM_ROOT_DEVICE") || return 1
  opts="root=UUID=$root_uuid rw"
  if [[ ${FILESYSTEM} == btrfs ]]; then opts+=" rootflags=subvol=@"; fi
  if [[ ${ENCRYPTION:-none} == luks2 ]]; then
    crypt_uuid=$(blkid -s UUID -o value -- "$ROOT_PART") || return 1
    [[ -n $crypt_uuid ]] || { echo 'LUKS ERROR: encrypted partition UUID missing' >&2; return 1; }
    # The default Arch mkinitcpio preset uses systemd. sd-encrypt requires
    # rd.luks.name, not the BusyBox encrypt hook's cryptdevice parameter.
    opts="rd.luks.name=${crypt_uuid}=bodarovoid-root root=/dev/mapper/bodarovoid-root rw"
    if [[ ${FILESYSTEM} == btrfs ]]; then opts+=" rootflags=subvol=@"; fi
    local hooks_line
    hooks_line=$(grep -E '^HOOKS=' /mnt/etc/mkinitcpio.conf | head -n 1) || return 1
    [[ $hooks_line == *systemd* ]] || { echo 'LUKS ERROR: expected systemd mkinitcpio hooks' >&2; return 1; }
    # Replace any legacy encrypt hook, then place sd-encrypt before filesystems.
    sed -i -E '/^HOOKS=/ { s/(^|[[:space:]])sd-encrypt([[:space:]]|\))/\1\2/g; s/(^|[[:space:]])encrypt([[:space:]]|\))/\1\2/g; s/[[:space:]]+filesystems/ sd-encrypt filesystems/; }' /mnt/etc/mkinitcpio.conf
    grep -Eq '^HOOKS=.*[[:space:]]sd-encrypt[[:space:]]filesystems' /mnt/etc/mkinitcpio.conf || {
      echo 'LUKS ERROR: sd-encrypt hook not configured' >&2; return 1;
    }
    arch-chroot /mnt mkinitcpio -P || { echo 'LUKS ERROR: initramfs generation failed' >&2; return 1; }
    [[ -s /mnt/boot/initramfs-$KERNEL.img ]] || { echo 'LUKS ERROR: initramfs missing' >&2; return 1; }
  fi
  if [[ $BOOTLOADER == GRUB ]]; then
    # Do not append duplicate GRUB_CMDLINE_LINUX assignments: replace the
    # existing value so grub-mkconfig actually embeds the unlock parameters.
    if grep -q '^GRUB_CMDLINE_LINUX=' /mnt/etc/default/grub; then
      sed -i '/^GRUB_CMDLINE_LINUX=/d' /mnt/etc/default/grub
    fi
    printf 'GRUB_CMDLINE_LINUX="%s"\n' "$opts" >> /mnt/etc/default/grub
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory="$( [[ ${ENCRYPTION:-none} == luks2 ]] && printf /boot || printf /boot/efi )" --bootloader-id=Bodarovoid --recheck || return 1
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || return 1
    [[ -s /mnt/boot/grub/grub.cfg ]] || return 1
    if [[ ${ENCRYPTION:-none} == luks2 ]]; then
      grep -Fq "rd.luks.name=${crypt_uuid}=bodarovoid-root" /mnt/boot/grub/grub.cfg || {
        echo 'LUKS ERROR: generated GRUB config lacks rd.luks.name' >&2; return 1;
      }
      grep -Fq 'root=/dev/mapper/bodarovoid-root' /mnt/boot/grub/grub.cfg || {
        echo 'LUKS ERROR: generated GRUB config lacks mapper root' >&2; return 1;
      }
    fi
  else
    # Limine's Linux boot protocol loads files from the EFI System Partition.
    local esp_type boot_uuid limine_conf
    limine_conf=/mnt/boot/limine.conf
    if [[ ! -s /mnt/boot/vmlinuz-$KERNEL || ! -s /mnt/boot/initramfs-$KERNEL.img ]]; then
      echo "LIMINE ERROR: kernel or initramfs missing under /mnt/boot" >&2; return 1
    fi
    esp_type=$(findmnt -rn -o FSTYPE --mountpoint /mnt/boot) || {
      echo 'LIMINE ERROR: /mnt/boot is not a mounted filesystem' >&2; return 1;
    }
    if [[ $esp_type != vfat ]]; then
      echo "LIMINE ERROR: /mnt/boot must be FAT EFI partition, found $esp_type" >&2; return 1
    fi
    efi_file=/mnt/usr/share/limine/BOOTX64.EFI
    if [[ ! -s $efi_file ]]; then
      echo "LIMINE ERROR: EFI executable missing: $efi_file" >&2; return 1
    fi
    if ! install -Dm0644 -- "$efi_file" /mnt/boot/EFI/BOOT/BOOTX64.EFI; then
      echo 'LIMINE ERROR: could not copy EFI boot executable' >&2; return 1
    fi
    # Write a new initramfs file, ensuring FAT directory entries are finalized.
    if ! cp -- /mnt/boot/initramfs-$KERNEL.img /mnt/boot/bodarovoid-initramfs-$KERNEL.img; then
      echo 'LIMINE ERROR: could not copy initramfs to ESP' >&2; return 1
    fi
    kernel_path="boot():/vmlinuz-$KERNEL"
    initrd_path="boot():/bodarovoid-initramfs-$KERNEL.img"
    if [[ -z $root_uuid ]]; then
      echo 'LIMINE ERROR: root filesystem UUID is empty' >&2; return 1
    fi
    {
      printf 'timeout: 5\n\n/Bodarovoid Arch Linux\n'
      printf '    protocol: linux\n    path: %s\n    cmdline: %s\n' "$kernel_path" "$opts"
      for microcode_file in intel-ucode.img amd-ucode.img; do
        if [[ -s /mnt/boot/$microcode_file ]]; then
          printf '    module_path: boot():/%s\n' "$microcode_file"
        fi
      done
      printf '    module_path: %s\n' "$initrd_path"
    } > "$limine_conf" || { echo 'LIMINE ERROR: cannot write limine.conf' >&2; return 1; }
    if [[ ! -s $limine_conf || ! -s /mnt/boot/EFI/BOOT/BOOTX64.EFI ]]; then
      echo 'LIMINE ERROR: generated EFI boot files are missing' >&2; return 1
    fi
    if [[ ${ENCRYPTION:-none} != luks2 ]] && ! grep -Fq "root=UUID=$root_uuid" "$limine_conf"; then
      echo "LIMINE ERROR: root UUID mismatch (expected $root_uuid)" >&2; return 1
    fi
    if ! sync "$limine_conf" /mnt/boot/EFI/BOOT/BOOTX64.EFI /mnt/boot/bodarovoid-initramfs-$KERNEL.img; then
      echo 'LIMINE ERROR: EFI partition sync failed' >&2; return 1
    fi
    echo "LIMINE OK: EFI loader, config, and initramfs installed; root UUID $root_uuid"

  fi
}

b18_aur_install() {
  local pkg workdir=/var/tmp/bodarovoid-aur-build
  local -a files=()
  # Build dependencies are resolved through makepkg. Never run makepkg as root.
  arch-chroot /mnt useradd -m -s /bin/bash -- bv-aur-builder
  install -d -m 0755 /mnt/var/tmp
  arch-chroot /mnt install -d -o bv-aur-builder -g bv-aur-builder -m 0700 "$workdir"
  for pkg in "${AUR_SEARCH_SELECTED[@]}"; do
    b17_valid_name "$pkg" || return 1
    # Explicit URL validation: package names contain only permitted characters.
    arch-chroot /mnt runuser -u bv-aur-builder -- \
      git clone --depth 1 -- "https://aur.archlinux.org/${pkg}.git" "$workdir/$pkg" || return 1
    # makepkg can run arbitrary community PKGBUILD code as the build user.
    # --syncdeps requires elevated pacman privileges, which are deliberately NOT granted.
    # Missing dependencies stop the build; never bypass dependency checks.
    arch-chroot /mnt runuser -u bv-aur-builder -- \
      bash -c 'cd -- "$1" && makepkg --noconfirm --cleanbuild' _ "$workdir/$pkg" || return 1
    mapfile -d '' -t files < <(find "/mnt$workdir/$pkg" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
    ((${#files[@]})) || return 1
    local -a chroot_files=() file
    for file in "${files[@]}"; do chroot_files+=("${file#/mnt}"); done
    arch-chroot /mnt pacman -U --noconfirm --needed -- "${chroot_files[@]}" || return 1
  done
  arch-chroot /mnt userdel -r -- bv-aur-builder || true
  return 0
}

vm_install_execute() {
  (
  set -Eeuo pipefail
  local fp snap cpu microcode=''
  local -a pkgs desktop_pkgs system_pkgs
  vm_install_check || return 1
  fp=$(b95_fingerprint) || return 1
  snap=$(b101_snapshot create) || return 1
  ui_install_warning
  printf '\nFINAL DESTRUCTIVE ACTION: ERASE FILESYSTEMS ON %s %s %s\n' "$EFI_PART" "$ROOT_PART" "$SWAP_PART"
  printf 'This cannot be undone. The selected disk may be PHYSICAL. Its partitions will be formatted.\n'
  local phrase profile_before
  profile_before=$(profile_packages | sort -u) || return 1
  phrase=$(gum input --header "Type ERASE ${DISK} AND INSTALL") || return 1
  [[ $phrase == "ERASE ${DISK} AND INSTALL" ]] || { printf 'Cancelled.\n'; return 1; }
  if ((${#AUR_SEARCH_SELECTED[@]})); then
    printf '\nAUR packages contain third-party build scripts that will run automatically as a non-root user.\n'
    printf 'Selected AUR packages: %s\n' "${AUR_SEARCH_SELECTED[*]}"
    local aur_consent
    aur_consent=$(gum input --header 'Type BUILD AUR to accept executing unreviewed community PKGBUILDs') || return 1
    [[ $aur_consent == 'BUILD AUR' ]] || { printf 'AUR installation cancelled.\n'; return 1; }
  fi
  vm_install_check || return 1
  [[ $(profile_packages | sort -u) == "$profile_before" ]] || return 1
  [[ $(b95_fingerprint) == "$fp" && $(b101_snapshot create) == "$snap" ]] || return 1
  b12_log_init || return 1
  b12_log INFO "Target $DISK; EFI $EFI_PART; root $ROOT_PART; swap $SWAP_PART"
  VM_INSTALL_STARTED=1
  trap 'if (( VM_INSTALL_STARTED )); then vm_install_cleanup; fi' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  # The caller must keep this function in a context where errexit is effective.
  trap 'status=$?; b12_log ERROR "Installation failed (exit $status); cleaning up"; printf "\nINSTALL FAILED (exit %s). Owned mounts and swap will be cleaned up.\n" "$status" >&2' ERR
  ui_step 1 5 'Formatting selected partitions'
  b12_log INFO "Formatting EFI, root and swap partitions"
  mkfs.fat -F 32 -- "$EFI_PART"
  VM_ROOT_DEVICE=$ROOT_PART
  if [[ ${ENCRYPTION:-none} == luks2 ]]; then
    printf 'LUKS2 will encrypt ROOT only; EFI and separate swap remain UNENCRYPTED.\n'
    cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 -- "$ROOT_PART"
    cryptsetup open -- "$ROOT_PART" bodarovoid-root
    VM_CRYPT_OPEN=1
    VM_ROOT_DEVICE=/dev/mapper/bodarovoid-root
  fi
  if [[ $FILESYSTEM == ext4 ]]; then
    mkfs.ext4 -F -- "$VM_ROOT_DEVICE"
  else
    mkfs.btrfs -f -- "$VM_ROOT_DEVICE"
  fi
  mkswap -- "$SWAP_PART"
  b12_log OK "Filesystems formatted"
  ui_step 2 5 'Mounting target filesystems'
  b12_log INFO "Mounting target filesystems"
  if [[ $FILESYSTEM == btrfs ]]; then
    mount -- "$VM_ROOT_DEVICE" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    umount /mnt
    mount -o subvol=@,compress=zstd -- "$VM_ROOT_DEVICE" /mnt
    VM_INSTALL_MOUNTS+=(/mnt)
    mkdir -p /mnt/home
    mount -o subvol=@home,compress=zstd -- "$VM_ROOT_DEVICE" /mnt/home
    VM_INSTALL_MOUNTS+=(/mnt/home)
  else
    mount -- "$VM_ROOT_DEVICE" /mnt
    VM_INSTALL_MOUNTS+=(/mnt)
  fi
  if [[ $BOOTLOADER == Limine || ${ENCRYPTION:-none} == luks2 ]]; then
    mkdir -p /mnt/boot
    mount -- "$EFI_PART" /mnt/boot
    VM_INSTALL_MOUNTS+=(/mnt/boot)
  else
    mkdir -p /mnt/boot/efi
    mount -- "$EFI_PART" /mnt/boot/efi
    VM_INSTALL_MOUNTS+=(/mnt/boot/efi)
  fi
  swapon -- "$SWAP_PART"
  VM_INSTALL_SWAP=$SWAP_PART
  pkgs=(base "$KERNEL" linux-firmware networkmanager sudo vim efibootmgr dosfstools)
  if [[ $BOOTLOADER == GRUB ]]; then pkgs+=(grub); else pkgs+=(limine); fi
  if [[ $FILESYSTEM == btrfs ]]; then pkgs+=(btrfs-progs); fi
  if [[ ${ENCRYPTION:-none} == luks2 ]]; then pkgs+=(cryptsetup mkinitcpio); fi
  if ((${#AUR_SEARCH_SELECTED[@]})); then pkgs+=(git base-devel); fi
  cpu=$(lscpu 2>/dev/null | awk -F: '/^Vendor ID:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}')
  case "$cpu" in GenuineIntel) microcode=intel-ucode ;; AuthenticAMD) microcode=amd-ucode ;; esac
  [[ -z $microcode ]] || pkgs+=("$microcode")
  mapfile -t system_pkgs < <(b17_official_packages)
  pkgs+=("${system_pkgs[@]}")
  mapfile -t desktop_pkgs < <(profile_packages | sed '/^$/d' | sort -u)
  if ((${#desktop_pkgs[@]})); then
    pkgs+=("${desktop_pkgs[@]}")
    b12_log INFO "Desktop ${DESKTOP} (${DESKTOP_INSTALL_TYPE}): ${desktop_pkgs[*]}"
  fi
  b12_log INFO "Selected official system packages: ${system_pkgs[*]}"
  ui_step 3 5 'Installing Arch Linux and selected packages'
  b12_log INFO "Installing base system packages and selected desktop"
  pacstrap -K /mnt "${pkgs[@]}"
  b12_log OK "Base packages installed"
  # Build AUR recipes without root privileges, then install the resulting artifacts.
  # AUR PKGBUILDs are untrusted code; the user must explicitly opt in.
  if ((${#AUR_SEARCH_SELECTED[@]})); then
    b12_log INFO "Building selected AUR packages: ${AUR_SEARCH_SELECTED[*]}"
    b18_aur_install || { b12_log ERROR 'AUR installation failed'; return 1; }
    b12_log OK 'AUR packages installed'
  fi
  genfstab -U /mnt > /mnt/etc/fstab
  grep -Eq '^[^#]+[[:space:]]+/[[:space:]]+(ext4|btrfs)[[:space:]]' /mnt/etc/fstab
  grep -Eq '^[^#]+[[:space:]]+/boot(/efi)?[[:space:]]+vfat[[:space:]]' /mnt/etc/fstab
  ui_step 4 5 'Configuring accounts, initramfs and bootloader'
  b12_log INFO "Configuring system, accounts and $BOOTLOADER"
  vm_install_write_config "$microcode"
  b12_log OK "System configuration and $BOOTLOADER completed"
  ui_step 5 5 'Verifying boot files and finishing'
  b12_log SUCCESS "Installation completed; reboot test required"
  b12_log_copy
  VM_INSTALL_FINISHED=1
  vm_install_cleanup
  VM_INSTALL_STARTED=0
  trap - ERR INT TERM EXIT
  printf '\nINSTALLATION COMPLETED. Remove the ISO, reboot, and verify login.\n'
  )
}

vm_install_menu() {
  local error
  ui_heading 'Bodarovoid — INSTALL ARCH (DESTRUCTIVE)'
  printf 'This ERASES EFI, root and swap. Selected: %s + %s + %s.\n\n' "${FILESYSTEM:-unset}" "${BOOTLOADER:-unset}" "${ENCRYPTION:-none}"
  if ! vm_install_check; then
    printf 'BLOCKED:\n'; for error in "${VM_INSTALL_ERRORS[@]}"; do printf ' - %s\n' "$error"; done
    ui_pause; return 0
  fi
  printf 'Disk: %s\nEFI (ERASE): %s\nRoot (ERASE): %s\nSwap (ERASE): %s\nHostname: %s\nUser: %s\n' "$DISK" "$EFI_PART" "$ROOT_PART" "$SWAP_PART" "$HOSTNAME" "$USERNAME"
  printf '\nThis is REAL installation, not a rehearsal.\n\n'
  profile_show
  b17_show
  local choice
  choice=$(ui_choose 'Continue to final destructive confirmation?' 'Proceed to final confirmation' 'Back') || return 0
  [[ $choice == 'Proceed to final confirmation' ]] || return 0
  vm_install_execute
  ui_pause
}

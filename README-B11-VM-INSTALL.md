# B11 — Real VirtualBox Installation (restricted first release)

**DANGER: B11 performs actual filesystem destruction.** All older B9/B10 screens remain read-only. B11 is explicitly selected from the main menu.

## Supported installation path

- Oracle VirtualBox guest booted in **UEFI** mode using the official Arch ISO
- VirtualBox **SATA** virtual hard disk (`VBOX HARDDISK`), disposable and backed up
- Existing GPT partition table with EFI System Partition, Linux filesystem root partition, and swap partition, all assigned in the Gum menu
- **EFI CREATE only** (an EFI partition with no existing filesystem signature); **ext4 root**, **GRUB UEFI**, **linux / linux-lts / linux-zen** kernel
- **Desktop: none** (bootable command-line Arch system); NetworkManager enabled
- Hostname, locale, keymap, timezone, user, and passwords configured interactively

**Not supported yet:** physical PCs, EFI reuse/dual boot, automatic partition creation, encryption, Btrfs, Limine, desktop installation, LVM/RAID, and multi-disk configurations. These remain planning features only. No tested rollback exists after formatting begins.

## Before use

1. Create a fresh VirtualBox VM and a **disposable** virtual disk. Disconnect any host disks, shared raw disks, and other storage you care about. Take a VM snapshot.
2. Enable **EFI** in VirtualBox VM settings. Boot the Arch ISO with internet access.
3. Install `gum` if necessary. Ensure `pacstrap`, `genfstab`, `arch-chroot`, `mkfs.fat`, `mkfs.ext4`, `mkswap`, `grub-install` (in target), and `efibootmgr` are available when required.
4. Use `cfdisk` manually to create a GPT disk with EFI type, Linux filesystem type and Linux swap type. The installer **does not partition disks**.
5. In Bodarovoid, assign the disk and its partitions, choose ext4 + GRUB, Desktop none, configure settings, and complete B9.2 through B10.9 safety rehearsals **in the same process** using EFI policy CREATE.
6. Select **REAL INSTALL — VirtualBox ext4 + GRUB (B11)**. Carefully review all paths. Enter the *new* destructive confirmation phrase only if you intend to erase those partitions.
7. After success, shut down, detach the ISO, and boot from the virtual disk. A successful reboot has **not been independently verified** by the author of this patch.

## Failure behavior

The installer stops on errors and attempts to deactivate only the swap it enabled and unmount only the mountpoints it created. It **does not undo formatting, package installation, firmware boot entries or configuration changes**. On failure, inspect the VM before retrying; do not assume a safe rollback. Avoid changing settings while a run is in progress.

## Tests

```bash
bash -n arch-install.sh lib/vm_install.sh
bash tests/test_b11_vm_install.sh
bash tests/test_b10_9_guards.sh
```

The tests are read-only, and do not establish that installation or reboot succeeds. Real end-to-end testing must occur on a throwaway VirtualBox disk.

# Bodarovoid B15 — Guided VirtualBox Installer (Development Preview)

This build reorganizes the working B14 installer into a guided menu. It does **not** authorize physical disk installation. The original advanced menus and B9/B10 guard procedures remain available.

## Safe test flow

1. Boot Arch ISO in a disposable VirtualBox UEFI VM. Install `gum` if needed.
2. Run `bash arch-install.sh` as root.
3. In the guided menu, select the intended disposable SATA virtual disk.
4. Prepare partitions: assign existing EFI/swap/root partitions, **or** explicitly choose destructive guided GPT creation. Guided creation erases the entire selected disk and requires an exact typed confirmation. It creates only partitions, not filesystems.
5. Configure system settings, choose desktop and Minimal/Full package preset, and review the complete target layout.
6. Complete the required B9/B10 approval and safety sequence. After disk or settings changes, redo the approvals. Some older safety checks may require additional prerequisites accessible from Advanced / legacy menu.
7. Run real installation only after its final check and exact destructive confirmation. It formats EFI, root, and swap and installs Arch Linux.
8. Shut down, detach ISO, boot installed virtual disk, and check login, mount points, swap, and display manager.

## Scope and limitations

- VirtualBox SATA `/dev/sdX` disks only; no real hardware, NVMe, USB or other hypervisors.
- UEFI, GPT, new EFI, ext4, GRUB and a separate swap partition only.
- No safe EFI reuse, dual boot, encryption, Btrfs or recovery automation.
- GNOME and Hyprland graphical boots still need dedicated tests.
- This is a guided front-end for the existing multi-stage approvals, **not** a one-click installer.
- B15 corrects the disk model read using sysfs, avoiding escaped-space `lsblk` output.
- B15 removes misleading read-only B13 preview warnings from the destructive GPT screen.

Do not use on disks containing data you need to keep.

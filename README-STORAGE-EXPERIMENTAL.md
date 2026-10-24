# Bodarovoid experimental storage paths

This build adds installation paths for ext4/Btrfs, GRUB/Limine, and optional LUKS2 **root** encryption. These are NOT production certified. Use only disposable VMware/VirtualBox UEFI disks. The existing VM disk safety restriction is retained.

- Btrfs uses @ and @home subvolumes with zstd compression.
- LUKS2 encrypts root, **not** the EFI system partition or the separate swap partition. Swap is unencrypted and may contain sensitive data. Do not describe this mode as full-disk encryption.
- The encrypted boot paths mount EFI at /boot so kernel/initramfs remain accessible. LUKS2 uses PBKDF2 for compatibility, with cryptsetup encrypt hook.
- Limine uses an EFI fallback path and a limine.conf Linux protocol entry. Exact EFI binary location/config syntax must be checked against the current Limine package before testing.
- AUR and storage combination tests have not been run. No successful boot is claimed for these new combinations.
- Legacy planning/preflight menus may still describe these paths as unsupported; the guided install uses its own execution checks.

## Test matrix (all disposable VMs)
1. ext4 + GRUB + no encryption (regression)
2. Btrfs + GRUB + no encryption
3. ext4 + Limine + no encryption
4. Btrfs + Limine + no encryption
5. ext4 + GRUB + LUKS2 root
6. Btrfs + GRUB + LUKS2 root
7. ext4 + Limine + LUKS2 root
8. Btrfs + Limine + LUKS2 root

For every case verify boot, / and /home mount options, /etc/fstab, kernel updates, and reboot. Avoid using the experimental modes on real hardware.

# Bodarovoid LUKS2 boot fix — experimental

This build corrects the mismatch between systemd mkinitcpio hooks and legacy BusyBox encrypt kernel arguments.

- `sd-encrypt` replaces `encrypt` in the systemd initramfs hook chain.
- Encrypted-root kernel arguments use `rd.luks.name=<LUKS UUID>=bodarovoid-root root=/dev/mapper/bodarovoid-root rw`.
- Btrfs additionally uses `rootflags=subvol=@`.
- GRUB_CMDLINE_LINUX is replaced, not appended; the generated grub.cfg is checked for unlock parameters.
- Limine uses the same encrypted-root kernel arguments.

**Testing:** Bash syntax and static transformations have been checked. None of the four LUKS2 boot combinations has been validated by a full VM installation. Use disposable VMware/VirtualBox disks only. The ESP and separate swap remain unencrypted. Do not use this on real hardware.

Recommended first test: ext4 + GRUB + LUKS2, no AUR. After install, verify the LUKS passphrase prompt and a successful boot. Then test Btrfs + GRUB + LUKS2, followed by Limine combinations.

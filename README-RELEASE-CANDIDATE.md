# Bodarovoid — installation release candidate (NOT production certified)

This is a hardening update to the supplied B18 project, **not a claim of 100% reliable installation**.

## Supported install path
- Fresh official Arch ISO, booted UEFI
- Verified VMware/VirtualBox virtual disk only; entire selected disk is erased
- GPT, fresh FAT32 EFI, ext4 root, dedicated swap, GRUB
- Optional KDE, GNOME, Hyprland, or no desktop
- Official package selection and live search
- Optional AUR builds (untrusted PKGBUILDs, explicit consent, unprivileged builder)

## Improvements
- Removed `makepkg --nodeps`: dependency checks are no longer bypassed.
- Added pre-write internet/HTTPS and official package checks.
- Updated wizard wording and obsolete pacman command guidance.
- Retained disk identity, VM-only guards and confirmations.

## Critical remaining limits
- **Not certified**: no end-to-end boot test was run in this environment.
- AUR dependencies (including AUR-to-AUR dependencies) are NOT automatically installed. Build fails rather than ignoring them.
- AUR PKGBUILDs are executable third-party code; non-root does not make them safe.
- Physical disks, EFI reuse, dual boot, Btrfs, encryption and BIOS boot are unsupported.
- Package names, available desktop components and VM firmware may vary over time.
- Some configuration failures after formatting can leave a nonbootable target.
- No GUI-based full hardware integration tests have been performed.

## Test safely
1. Download a current ISO from https://archlinux.org/download/.
2. Create a disposable VMware/VirtualBox UEFI VM with one empty virtual disk.
3. Boot ISO, verify networking and run `pacman -S --needed gum fzf curl jq git unzip`.
4. Transfer/extract this folder, then `bash arch-install.sh`.
5. First test no desktop and no AUR, then KDE/GNOME, then AUR on separate VM snapshots.
6. Do not distribute as a stable installer until installation and reboot regression tests pass.

Never run on real disks. The installer intentionally blocks unsupported physical hardware.

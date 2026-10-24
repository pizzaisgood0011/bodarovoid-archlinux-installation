# B14 — Desktop installation (experimental, VirtualBox only)

This release extends the previously boot-tested B11 installer with KDE Plasma, GNOME and Hyprland packages. It has NOT yet passed a desktop first-boot test.

## Workflow

1. Use a **new disposable VM disk** and boot the Arch ISO in UEFI mode. Do not run on a physical machine.
2. Configure the disk and partitions, then choose a desktop under System Configuration.
3. Use **Desktop Packages (B14)** to select Minimal or Full and toggle optional packages. Required packages are locked. Minimal installs only required packages plus explicitly selected extras; Full installs recommended and full extras.
4. Review the B11 summary and package list; redo all B9/B10 approvals after changing system settings.
5. Execute B11 only after reviewing the destructive confirmation.
6. KDE Plasma uses SDDM; GNOME uses GDM; Hyprland boots to TTY and users start `Hyprland` manually.

## Important limitations

- B11/B14 still formats the target EFI, root and swap partitions. No reuse of existing EFI, dual boot, Btrfs, LUKS or physical hardware support.
- Hyprland on VirtualBox may fail due to virtual GPU/Wayland compositor limitations. This is not proof of hardware compatibility.
- Optional package descriptions are short hints, not full pacman metadata. Pacman resolves transitive dependencies.
- The UI remains staged; automatic GPT creation and B11 installation are separate.
- Do not put passwords in logs. `passwd` is interactive and is not logged by the stage logger.

## Test

`bash tests/test_b14_profiles.sh` (read-only)

Desktop first-boot testing is still required before a stable release.

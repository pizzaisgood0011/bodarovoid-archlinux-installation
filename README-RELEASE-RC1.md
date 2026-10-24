# Bodarovoid RC1 — Fast Arch Installer

**Scope:** rapid, guided Arch Linux installation with Gum. No Plymouth, desktop theming, or graphical encryption prompt is installed. Users customize their own systems after installation.

## Supported and tested in VMware

Eight combinations were reported booting successfully by the project tester: ext4/Btrfs × GRUB/Limine × unencrypted/LUKS2 root. This is user-reported VM testing, not automated certification. VirtualBox has not been independently confirmed in this release. Physical-disk installation remains intentionally blocked by existing safeguards.

## RC1 improvements

- Clearer wizard heading, review warning and 5-stage progress labels.
- Preflight checks HTTPS connectivity, target mounts, and an already-open encrypted-root mapper.
- Preserves disk identity checks, approvals, typed destructive confirmation, and existing bootloader configuration.
- Includes a static regression test for Bash syntax, LUKS2 boot parameters, and key safety guard references.

## Security boundaries

- LUKS2 encrypts **root only**. EFI and separate swap are unencrypted. Sensitive data can reach swap; this is **not full-disk encryption**.
- AUR PKGBUILDs are untrusted executable scripts. The existing AUR opt-in is retained. Prefer official packages for trusted installations.
- The installer runs with root privileges and can permanently destroy selected partition data.
- No Plymouth or other LUKS graphical UI is included.

## Run

On a disposable UEFI VMware test guest booted from the Arch ISO, install `gum` and dependencies required by the existing project, then run `bash arch-install.sh`. Follow the wizard and mandatory approvals. Do not run against disks with valuable data.

## Validate without writing disks

`bash tests/test_release_static.sh`

## Release blockers / next validation

- Repeat clean-VM installation and reboot for all eight combinations **on this RC1 build**.
- Test interruption at each installation stage, missing internet, invalid inputs, and failure cleanup.
- Confirm VirtualBox support independently.
- Audit partition layout, bootloader paths, hardware detection and drivers on real hardware **before** enabling physical disks.
- Design a separate opt-in encrypted swap strategy before claiming complete encryption.

Do not market this release as production-ready for real machines. It is a VM-focused release candidate.

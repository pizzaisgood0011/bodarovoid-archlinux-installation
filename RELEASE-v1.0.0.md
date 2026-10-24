# Bodarovoid v1.0.0 — VM Edition

This is the first named v1.0.0 distribution of the Bodarovoid fast guided Arch Linux installer, packaged from RC1 without changing its installation engine.

## Scope

**VM-focused release. Not verified or supported for physical-disk installation.** Existing physical-disk guards remain enabled. The project tester previously reported successful boots for all eight ext4/Btrfs × GRUB/Limine × unencrypted/LUKS2 combinations on VMware, but the RC1 changes have not been confirmed through a full retest. This archive has not been certified as a general-purpose production installer.

## Included

- Gum-guided Arch installation and review/confirmation flow
- ext4 and Btrfs roots
- GRUB and Limine bootloaders
- Optional LUKS2 root encryption (not full-disk encryption)
- Existing desktop profiles and package selections
- RC1 preflight, progress and static regression checks

## Not included

- Plymouth or graphical unlock themes
- Encryption of EFI or separate swap
- Verified support for physical hardware

## Recommended release gates

1. Retest all eight combinations using this exact archive on disposable UEFI VM disks.
2. Test cancellation, wrong disk, network loss, interrupted install, and cleanup.
3. Document and resolve all blocking issues before announcing stable general-purpose support.

## Test locally

Run `bash tests/test_release_static.sh` from the project directory. This is a static check, not a boot test.

# Bodarovoid physical hardware release candidate

**EXPERIMENTAL — NOT A VERIFIED STABLE HARDWARE RELEASE.**

This is the v1.0.0 VM-tested installer adapted for SATA/NVMe physical disks.
Physical installation has **not** been tested on real hardware. The installer is
**whole-disk destructive**: it creates a fresh GPT and formats EFI, swap and root.
Do not use on a computer containing important data or on a dual-boot drive.

## Requirements

- Arch Linux ISO booted in UEFI mode, root shell, network access, gum installed.
- Dedicated spare internal SATA or NVMe drive with **no valuable data**.
- Backups verified and all other storage drives physically disconnected if possible.
- Installer is NOT for in-place installation, preserving existing partitions,
  dual boot, or reusing an existing Windows EFI partition.
- USB/removable target disks, mounted disks, active swap and disk-mapper holders are blocked.

## Enable real-disk installation

Run from the live Arch ISO terminal:

```bash
export BODAROVOID_PHYSICAL_INSTALL=I_UNDERSTAND_THIS_ERASES_A_REAL_DISK
./arch-install.sh
```

The opt-in is required on real machines. It does NOT replace the existing
explicit typed confirmations or identity rechecks before writes.

**Warning:** The physical target may still be misidentified by the operator.
Read the disk model, size and path, and disconnect other drives. A mistaken
selection can permanently destroy personal data. The EFI and swap partitions
are unencrypted even when LUKS2 root encryption is enabled.

## Testing status

- 8/8 filesystem/bootloader/encryption combinations were reported passing in
  VMware on v1.0.0 VM Edition.
- This physical RC has passed only static checks, NOT an actual installation.
- Test first on a disposable spare drive; report disk model, bootloader,
  filesystem, encryption mode, boot result, and any errors.

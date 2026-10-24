# Bodarovoid v1.0.0 — Hardware-capable installer

This build enables installation to physical SATA/NVMe disks **only after explicit opt-in**. It is not hardware-validated, and it can permanently destroy data on the selected disk. Previous reports of 8/8 successful boot combinations apply to VMware, not physical machines.

## Requirements
- Arch Linux live ISO booted in UEFI mode
- A dedicated empty target disk, preferably with other disks disconnected
- Reliable internet and sufficient power
- Root shell, `gum` installed (`pacman -Sy --needed gum` on live ISO)
- Verified external backups and verified target disk identity

## Start

```bash
cd bodarovoid-archlinux
chmod +x arch-install.sh
export BODAROVOID_PHYSICAL_INSTALL=I_UNDERSTAND_THIS_ERASES_A_REAL_DISK
./arch-install.sh
```

## Before approving any destructive action

```bash
lsblk -e7 -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,FSTYPE,MOUNTPOINTS
```

Compare the **device path, model, serial, and capacity** to your intended target. On systems with multiple SSDs, `/dev/nvme0n1` and `/dev/nvme1n1` can change across boots. Do not assume disk numbers identify Windows or Linux. Prefer physically disconnecting drives that must be preserved. Do not select a disk with mounted partitions, active swap, or device-mapper holders. Do not use this installer to preserve existing partitions: guided GPT creation erases the whole selected disk, and installation formats EFI, swap and root.

## Supported installer selections
- ext4 or Btrfs
- GRUB or Limine (UEFI)
- No encryption or LUKS2 root encryption
- Desktop profiles in the installer

## Known limitations
- **No physical-hardware installation or reboot has been validated.** Treat as a hardware release candidate, not a certified stable physical release.
- EFI and separate swap remain unencrypted with LUKS2 root encryption.
- Current encryption setup uses PBKDF2, not Argon2id. Changing it needs a separate compatibility test cycle.
- Installation is destructive and does not preserve a Windows partition or existing shared EFI partition.
- Failure/interruption recovery is not guaranteed; reformatting may be required.
- No Plymouth or graphical unlock theme.
- No assurance of support for every Wi-Fi, GPU, firmware or storage controller.

Do a first physical test on a spare drive with no valuable data. Verify the complete install and reboot before calling this hardware-stable.

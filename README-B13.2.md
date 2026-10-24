# B13.2 — Experimental VirtualBox GPT creation

This build adds an explicitly destructive, VirtualBox-only partition-table creation step. It does NOT install Arch or format partitions by itself. It has passed Bash syntax and inherited non-destructive tests, but its real partition-write path has NOT been exercised in a disposable VM by the developer. Do not treat it as production ready.

## Supported
- UEFI VirtualBox guest, SATA VBOX HARDDISK /dev/sdX, root privileges.
- 1 GiB EFI, 4 or 8 GiB swap, remaining root ext4 (filesystem created later by B11).
- Whole-disk GPT replacement. Existing data and partitions on the selected disk are destroyed.

## Procedure
1. Take a VirtualBox snapshot. Select target under Disk & Partitions.
2. Open Guided GPT Creation (B13.2 — ERASES DISK), preview and select 4/8 GiB swap.
3. Review the selected device; enter the exact WIPE /dev/sdX GPT phrase only for a disposable target.
4. Check lsblk -o NAME,SIZE,TYPE,PARTTYPE,FSTYPE,MOUNTPOINTS.
5. Complete all required B9/B10 approvals afresh; B11 remains the filesystem formatter/installer.

Swap-none remains preview-only because B11 requires a swap partition.
Do not run this on real hardware, production VMs, or disks with data you need.

# Bodarovoid B10.3 — Read-only mounting and cleanup plan

B10.3 extends B10.2 with a read-only plan for ext4 and Btrfs root mounts, EFI mounting, swap activation and rollback ordering. No commands are executed. Btrfs subvolume layout (`@`, `@home`) is **proposed**, not implemented or boot-tested. The EFI path `/boot/efi` is provisional; bootloader integration must validate it for GRUB and Limine separately.

Run `bash tests/test_b10_3_mount.sh` and existing B10 tests, then test Gum. Complete B10.1 authorization rehearsal first. B10.3 does not authorize disk writes, mounting, or swap activation.

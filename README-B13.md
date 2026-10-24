# B13 Guided Disk Layout — Read-only Preview

This stage adds a guided layout estimator for a selected disk. It reads device size and existing partition metadata; it does not create, delete, format, mount, or otherwise modify disks.

From the main menu select **Disk & Partitions**, choose a disk, then **Guided Disk Layout (B13 Preview)**. Choose swap size and inspect the proposed EFI/swap/ext4-root layout. The preview does not change B11's existing manually prepared partition workflow.

Tests:

```bash
bash -n arch-install.sh lib/*.sh
bash tests/test_b13_layout.sh
bash tests/test_b12_profiles.sh
bash tests/test_b11_vm_install.sh
bash tests/test_b11_2_hardening.sh
```

## Limitations

- The layout uses an estimated 8 MiB alignment reserve, not a final sector-accurate partition table.
- It does not yet support dual boot, EFI reuse, encryption, Btrfs, or destructive automatic partitioning.
- Existing B11 real installation requires a separate swap partition even if B13 previews no swap.
- A preview is not authorization to erase a disk.

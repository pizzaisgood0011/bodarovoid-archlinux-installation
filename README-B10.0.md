# B10.0 — Read-only engine foundation

B10.0 adds a read-only installation plan for ext4/Btrfs and GRUB/Limine (four design combinations). It does NOT implement or authorize installation, filesystem formatting, Btrfs subvolume creation, or bootloader setup.

## Test

```bash
bash -n arch-install.sh
bash tests/test_b10_0_engine.sh
bash tests/test_b9_7_pipeline.sh
bash tests/test_b9_6_lock_hardening.sh
bash arch-install.sh
```

In Gum, choose disk and partitions, configure settings, approve B9.2, pass B9.4, lock B9.5, then open **Installation Engine Foundation (B10.0)** and choose EFI creation or reuse as appropriate. For a fresh unformatted VM ESP choose creation. This only displays a plan.

Safety: No disk writes. The plan intentionally rejects unknown filesystem/bootloader selections and stale safety gates. The four configurations are design targets, not tested bootable installations. The B9.8/B9.9 legacy preview paths still support only ext4/GRUB; B10.0 uses independent read-only validation instead of falsely claiming those previews cover Btrfs/Limine.

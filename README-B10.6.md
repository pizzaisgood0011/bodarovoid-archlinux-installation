# Bodarovoid B10.6 — UEFI Bootloader Integration Plan

Read-only planning for GRUB and Limine with ext4 or Btrfs. No bootloader commands execute. EFI reuse is preserve-only. Actual Limine package layout, kernel/initramfs paths, UEFI NVRAM behavior, and Btrfs subvolume boot behavior must be verified in a future executable release.

## Tests

```bash
bash -n arch-install.sh
bash tests/test_b10_6_bootloader.sh
bash tests/test_b10_5_config.sh
bash tests/test_b10_4_base.sh
bash tests/test_b10_3_mount.sh
bash tests/test_b10_2_format.sh
bash tests/test_b10_1_authorization.sh
bash tests/test_b10_0_engine.sh
```

## Gum test

Select disk and partitions, approve B9.2, pass B9.4, lock B9.5, complete B10.1 rehearsal with the same EFI policy, then choose **Bootloader Integration Plan (B10.6)**. Check the selected kernel, filesystem and bootloader in the output. This stage does not install or modify anything.

# B9.8 — Filesystem Preparation Preview

B9.8 is **read-only**. It generates a proposed ext4/GRUB command sequence after verifying the B9.7 settings, preflight, and identity-lock gates. No commands are executed. Do not copy/paste the displayed formatting commands.

Current preview deliberately blocks Btrfs, Limine, and missing swap partitions. EFI formatting is shown for review only; future real implementation must handle existing EFI partitions and dual-boot without erasing them by default. This is NOT a production-safe install executor.

## Tests

```bash
bash -n arch-install.sh
bash tests/test_b9_8_preparation.sh
bash tests/test_b9_7_pipeline.sh
bash tests/test_b9_6_lock_hardening.sh
bash arch-install.sh
```

Inside Gum, complete B9.2 approval, B9.4 preflight, B9.5 lock, then select **Filesystem Preparation Preview (B9.8)**. No formatting or mounting is performed.

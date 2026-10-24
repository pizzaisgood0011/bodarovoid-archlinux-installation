# B9.9.1 — EFI creation vs reuse (read only)

The new menu distinguishes **create new EFI filesystem** (only when no filesystem signature is detected) from **reuse existing vfat EFI**. Both require the EFI System Partition GUID and the prior B9.8 gates, including B9.5 identity lock. Neither option performs disk writes or grants authorization. A blank signature does **not** establish that a partition has no valuable data. Existing B9.9 stays preserve-only. B9.8 now omits its obsolete EFI formatting command preview.

Run `bash tests/test_b9_9_1_efi_policy.sh`, `bash tests/test_b9_9_safety.sh`, `bash tests/test_b9_8_preparation.sh`, `bash tests/test_b9_7_pipeline.sh`, `bash tests/test_b9_6_lock_hardening.sh`, then `bash arch-install.sh` in the Arch ISO. Follow disk/settings/B9.2/B9.4/B9.5 first, then B9.9.1. On a fresh, unformatted EFI partition, choose **Create new EFI**. No commands are executed.

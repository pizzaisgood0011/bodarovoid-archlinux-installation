# B9.9 — Partition Safety Policy (READ ONLY)

This milestone **never executes** formatting, mounting, swap activation, pacstrap, or bootloader commands.

- EFI must be an existing vfat filesystem and is **preserved**. B9.8 displayed an illustrative `mkfs.fat` command; B9.9 explicitly rejects EFI reformatting.
- Root and swap are marked **ERASE** in the policy, but no action is taken.
- B9.7/B9.8 prerequisite gates, unique partition roles and the EFI filesystem type are checked.
- `REVIEW ONLY` acknowledges a preview, **not authorization** for installation.
- Unsupported configurations remain blocked.

Run `bash tests/test_b9_9_safety.sh`, `bash tests/test_b9_8_preparation.sh`, `bash tests/test_b9_7_pipeline.sh`, `bash tests/test_b9_6_lock_hardening.sh`, then `bash arch-install.sh` in Arch ISO.

**Before any real installation in B10:** require explicit EFI reuse/creation policies, backup guidance, independent disk and partition verification, fresh final confirmation, mountpoint and swap rechecks, failure recovery, and bootloader coexistence handling. A preview is not sufficient authorization.

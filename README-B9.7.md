# B9.7 — Read-only installation pipeline simulation

This package is the complete project with B9.7 integrated. The uploaded `arch-install.sh` did not yet source or display B9.4/B9.5, so this version integrates their existing modules as well.

## Test

```bash
cd ~/bodarovoid-archlinux
bash -n arch-install.sh lib/pipeline_b97.sh
bash tests/test_b9_7_pipeline.sh
bash arch-install.sh
```

In Gum, select disk and partitions, approve settings (B9.2), verify B9.4, lock B9.5, then run `Installation Pipeline Simulation (B9.7)`.

The simulation validates the approvals and prints a high-level hypothetical pipeline. It does **not** run formatting, mounting, pacstrap, chroot, or bootloader commands. It does **not** prove that real installation will work. B9.7 never grants permission for disk changes.

**Important:** This project still includes legacy B2/B3 destructive menus inherited from the original archive. Do not use them during B9.7 testing. Only use the read-only B9 menus.

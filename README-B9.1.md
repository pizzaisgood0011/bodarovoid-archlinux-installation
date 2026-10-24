# Luciole B9.1 — System configuration engine (experimental)

This patch adds `lib/system_executor.sh` and a read-only test. It does **not** modify your existing files or connect an install button. No disk formatting, partitioning, mounting or GRUB actions are included.

## Install
Copy `lib/system_executor.sh` and `tests/test_b9_1_system_executor.sh` into the corresponding paths in your repository.

Run on Arch ISO:

```bash
bash -n lib/system_executor.sh
bash tests/test_b9_1_system_executor.sh
```

## Preview only (safe)

From a shell with `lib/system.sh` sourced and the user-selected variables populated:

```bash
source lib/system_executor.sh
system_exec_preview /mnt
```

## Applying (NOT part of B9.1 testing)

`system_exec_apply /mnt APPLY-SYSTEM-CONFIG` is an experimental one-shot function for a freshly pacstrapped, mounted Arch root. It writes configuration and prompts for passwords. It must NOT be used on an existing configured system. It does not set up GRUB or fstab. The function does not yet have a complete transaction/rollback mechanism; if interrupted, manual recovery may be required.

**Do not call the apply function during this patch's test.** Next phase will integrate a guarded Gum confirmation workflow and comprehensive target-disk identity validation.

# Bodarovoid B11.2 — VirtualBox installer hardening

This is an experimental destructive installer, **not a production release**.

Changes:
- Rejects missing partitions, duplicate role partitions, and partitions not directly belonging to the selected disk.
- Runs the destructive sequence in a dedicated subshell, with error/exit cleanup confined to that subshell.
- Keeps the final exact-disk confirmation and B10.9 revalidation.
- Keeps ext4 + GRUB + fresh EFI + pre-existing GPT partition scope; no EFI reuse, Btrfs, Limine, or desktop execution.

Test (read-only):

```bash
bash -n arch-install.sh lib/vm_install.sh
bash tests/test_b11_vm_install.sh
bash tests/test_b11_2_hardening.sh
bash tests/test_b10_9_guards.sh
bash tests/test_b10_8_readiness.sh
lsblk -o NAME,SIZE,MODEL,TYPE,FSTYPE,MOUNTPOINTS
cat /proc/swaps
```

No real VirtualBox install or reboot has been tested in the build environment. A passing test does not certify safe execution. Before any destructive test, use a snapshot and verify the target disk and all selected partitions independently. Never enter the final ERASE confirmation until willing to permanently lose all data on those partitions.

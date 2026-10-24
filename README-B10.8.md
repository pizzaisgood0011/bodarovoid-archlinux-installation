# B10.8 — Controlled Execution Readiness (read-only)

Adds a Gum menu for a **non-authorizing** readiness rehearsal. Requires existing B10.7 and B10.1 gates, validates disk identity and read-only state, scans disk descendants for mounts and active swap, and requires `CHECK <selected-disk> ONLY`.

**No formatting, mounting, pacstrap, account configuration or bootloader installation is enabled.** A passing check is not proof of safe erasure. It does not fully inspect holders, mdraid/LVM, multipath, encrypted mappings, open file descriptors, or check-to-use races. Future write support requires an independent safety architecture and destructive-operation tests on disposable devices.

Test on Arch ISO:
```bash
bash -n arch-install.sh
bash tests/test_b10_8_readiness.sh
bash tests/test_b10_7_audit.sh
bash arch-install.sh
```

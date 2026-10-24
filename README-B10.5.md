# Bodarovoid B10.5 — Read-only system configuration plan

This stage adds `lib/config_b105.sh` and a Gum menu entry. It validates previously approved B10.4 prerequisites and system settings, then prints a configuration plan. No disk writes, chroot commands, account creation, password changes, or service changes occur.

## Test

```bash
bash -n arch-install.sh
bash tests/test_b10_5_config.sh
bash tests/test_b10_4_base.sh
bash tests/test_b10_3_mount.sh
bash tests/test_b10_2_format.sh
bash tests/test_b10_1_authorization.sh
bash tests/test_b10_0_engine.sh
bash arch-install.sh
```

In Gum select disk and partitions, configure system, approve B9.2, pass B9.4, lock B9.5, rehearse B10.1, then open `System Configuration Plan (B10.5)` and choose the same EFI policy. Expected ending: `B10.5 PLAN COMPLETE — no files written, no accounts created, no passwords changed. Real installation DISABLED.`

**Limits:** Locale and keymap availability are checked against the live environment. The plan is not an executor. Password handling, sudoers editing, rollback, service enablement, and target-side validation are not implemented. Bootloader installation remains unimplemented.

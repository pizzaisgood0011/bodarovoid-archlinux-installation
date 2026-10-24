# B9.6 — Target Lock Hardening (read-only)

Based on the B9.5 module. Fixes NUL-byte warnings by streaming identity directly into sha256sum, checks errors before recording approval, and tests invalidation with two different valid-shaped mock disk identities and partition identifiers. Does not modify disks.

## Apply

Back up `lib/preflight_b95.sh` in the existing repository first. Extract this ZIP into the repository root, preserving its `lib/` and `tests/` paths, then run:

```bash
bash -n lib/preflight_b95.sh
bash tests/test_b9_6_lock_hardening.sh
bash tests/test_b9_5_target_lock.sh
```

Restart the installer and lock the intended test target again. Do not run legacy B2/B3/B4 destructive actions. This patch does not prove physical disk safety or enable installation.

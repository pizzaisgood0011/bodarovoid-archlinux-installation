# B10.9 — Independent Pre-Write Guards (READ ONLY)

B10.9 adds an additional independent rehearsal after B10.8. It requires a successful B10.8 confirmation in the **same installer process**, verifies its fingerprint and settings snapshot, inspects `/proc/self/mountinfo` using block-device major:minor IDs, inspects `/sys/dev/block/*/holders` for stacked-device dependencies, and rechecks swap inspection. It fails closed if inspection is unavailable. A separate `GUARD <selected disk> ONLY` phrase rehearses confirmation; it never authorizes disk writes.

**Limitations:** mount namespaces, open file descriptors, inaccessible dependency graphs, hotplug and check-to-use races remain unresolved. Real installation stays disabled. No filesystems are formatted or mounted.

Test: `bash tests/test_b10_9_guards.sh` then `bash arch-install.sh`. Run B10.8 confirmation first without exiting Gum, then B10.9. The earlier B10.8 confirmation is intentionally not persisted across restarts.

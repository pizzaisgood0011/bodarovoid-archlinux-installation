# B10.1 — Authorization Rehearsal (READ ONLY)

This stage deliberately grants **no real authorization**. It validates the existing B10.0 plan and B9.5 disk lock, asks for an exact disk-specific phrase, and checks that the disk identity and settings have not changed. A session-only rehearsal state is invalidated by changed disk fingerprints, partitions, filesystem, bootloader, EFI mode, or approved settings.

**No formatting, mounting, pacstrap, or bootloader commands are run.** This is not a secure authorization mechanism for real writes; it is a rehearsal to test invariants before implementing an executor. A future write-enabled version needs device identity revalidation at each destructive boundary, protection from race conditions, mount/swap checks, EFI reuse validation, failure cleanup, and explicit separate authorization.

Run `bash tests/test_b10_1_authorization.sh` and existing regression tests, then test via Gum.

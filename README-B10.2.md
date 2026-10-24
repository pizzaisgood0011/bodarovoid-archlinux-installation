# B10.2 — Formatting engine design (read-only)

This version deliberately does **not** enable real formatting. It adds a gated,
read-only command preview for ext4 and Btrfs, with EFI create/reuse behavior.
The Gum entry is `Formatting Engine Design (B10.2)`.

## Tests

```bash
bash -n arch-install.sh
bash tests/test_b10_2_format.sh
bash tests/test_b10_1_authorization.sh
bash tests/test_b10_0_engine.sh
```

## Gum workflow

Select disk and partitions, configure settings, approve B9.2, pass B9.4,
lock B9.5, rehearse the selected EFI mode in B10.1, then open B10.2
and choose the **same** EFI mode. A new installer session resets approvals.

## Safety

Every operation is prefixed `[NOT EXECUTED]`. No shell code executes these
commands. Formatting, mounting, and installation remain disabled.
The earlier B2/B3/B4 legacy modules are not a supported execution path.

Before real formatting is developed, implement and test a separate write
executor with verified device identity and lineage, live-media exclusion,
mounted/active-swap protection, TOCTOU-resistant checks, per-operation
explicit authorization, and safe interruption behavior. Avoid assuming an
empty filesystem signature means a partition contains no valuable data.

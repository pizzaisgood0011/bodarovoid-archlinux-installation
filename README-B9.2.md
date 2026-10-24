# B9.2 — Gum System Settings Review

This is a non-destructive preview. It does not configure a target, format disks, install packages, or enable a full installation workflow.

## Apply

From your repository root, copy `lib/config_review.sh`, `tests/test_b9_2_review.sh`, and `apply-b9.2.sh` to their corresponding locations. Run:

```bash
bash apply-b9.2.sh
bash tests/test_b9_2_review.sh
bash arch-install.sh
```

Choose **System Configuration**, set your values, then choose **Review System Settings (B9.2)**. Type `APPROVE SETTINGS` to approve the preview. The approval lasts only while the installer process is running; entering the review again resets it. Approval does not trigger installation.

The patch script creates a timestamped backup of `arch-install.sh` and refuses unknown menu layouts. It needs Python 3 for the one-time integration.

Note: the review validates input shape and checks locale availability; it is not a substitute for full target preflight, disk validation, or installation testing.

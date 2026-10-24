# B9.3 — Approved Settings Handoff (READ ONLY)

Adds a main-menu preview that accepts only system settings explicitly approved in B9.2.
Changes to kernel, filesystem, bootloader, CPU, GPU, desktop, hostname, username,
timezone, keymap, or locale invalidate the approved snapshot. Return to B9.2 to reapprove.

Apply: extract the ZIP into your repo root, then run `bash apply-b9.3.sh`.
Test: `bash tests/test_b9_3_workflow.sh` and `bash arch-install.sh`.

This patch does not call disk/format/mount/pacstrap/chroot commands, install a bootloader,
or create users. It does not integrate the installation engine yet.

The tests assume the live ISO has the standard Etc/UTC timezone and en_US.UTF-8
locale definitions. Existing B2/B3 experimental menus remain unchanged and may
be destructive; do not run them while testing B9.3.

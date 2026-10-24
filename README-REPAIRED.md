# Bodarovoid B9.3.2 — Integrated repository repair

This archive was rebuilt from the uploaded project, not an older baseline.

## Fixed
- B9.2 review and B9.3 handoff are sourced by `arch-install.sh` and appear in the main menu.
- B9.3 captures the approved settings snapshot and rejects later changes.
- B9.1 experimental system application now requires an additional environment opt-in and is **not** wired into the menu.
- Existing disk, formatting, mounting and package-selection modules were retained unchanged.

## Run
```bash
cd ~/bodarovoid-archlinux
bash tests/test_b9_integration.sh
bash arch-install.sh
```
Choose **System Configuration**, **Review System Settings (B9.2)**, then **Approved Settings Handoff (B9.3)**.

## Important safety limits
The main menu still includes **experimental VirtualBox formatting/mounting** actions from earlier stages. Do not use those on real hardware. Several legacy B4 scripts are hardcoded to old `/dev/sdb` VM identities; **do not execute them on the new VM**. The automated end-to-end installer is not implemented; `lib/install.sh` is empty. No production-ready installer is claimed.

Do not run old `apply-b9.2.sh` or `apply-b9.3.sh` on this integrated archive.

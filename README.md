# Luciole v0.8 Stage B1 — Formatting approval rehearsal

Built from v0.8 Stage A. **No filesystem formatting, mounting, or installation is enabled.** `cfdisk` can still write partition tables when the user explicitly chooses Write.

## Changes
- `lib/format_review.sh` (new): a two-step approval rehearsal with exact disk path entry and `ERASE` confirmation, preflight checks, disk/partition snapshots, and last-second revalidation.
- `lib/preflight.sh`: remove contradictory unformatted-EFI warning when the explicit `new-fat32` policy is valid; report it as information instead.
- `lib/dryrun.sh`: show provisional `/mnt/boot` EFI mount location rather than `TBD`; final bootloader integration is still pending.
- `arch-install.sh`: add **Formatting Approval Rehearsal** menu.

## Testing
Run `find . -type f -name '*.sh' -exec bash -n {} +` then `bash arch-install.sh` in the Arch live ISO.

Test: incomplete assignments block; active swap/mounted partitions block; wrong EFI type blocks; cancelling confirmation returns safely; incorrect disk path blocks; incorrect `ERASE` blocks; valid rehearsal shows `REHEARSAL PASSED` and `EXECUTION DISABLED`; previous menus still work.

**Security limitations:** this is a rehearsal, not a secure formatting executor. Snapshots do not cover every possible active consumer, races, stale kernel partition state, or metadata signature. Do not interpret rehearsal success as authorization for real formatting. Real execution requires additional fail-closed device checks, independent execution tests, and explicit opt-in.

## v0.8 Stage B2 — VirtualBox-only formatting (experimental)

This build adds `lib/format_executor.sh`. Its destructive menu is **locked by default**.
It is only for disposable VirtualBox guests, and only for GPT disks no larger than 16 GiB.
The installer does not partition disks, mount filesystems, run pacstrap, or install a bootloader.
Existing FAT EFI is preserved. Root and selected swap are always overwritten if executed.

Run normally to test the locked menu:

```bash
bash arch-install.sh
```

After snapshotting your disposable VM, and **only if you intend to erase its selected partitions**, launch explicitly:

```bash
LUCIOLE_ENABLE_VM_FORMAT=1 bash arch-install.sh
```

Use the `VirtualBox Formatting (B2)` menu. It requires a full plan review, exact disk path,
and `FORMAT-VM` confirmation. It checks the selected disk, partitions, active users, and
captured identity before each command. Execution logs are under `/run/luciole/`.
**A failure may leave a partially formatted disk.** Never run this against host or personal disks.

First run the non-destructive approval rejection cases. After a deliberately destructive
VM test, verify `lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS` and `blkid`.

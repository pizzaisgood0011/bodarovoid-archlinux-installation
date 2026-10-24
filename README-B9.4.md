# B9.4 — Read-only execution preflight

Built for the B9.3.2 repaired project. This is an additive patch.

1. Back up your repository.
2. Extract this ZIP into the repository root, preserving paths.
3. Run `bash apply-b9.4.sh`.
4. Run `bash tests/test_b9_4_preflight.sh`.
5. Run `bash arch-install.sh` and choose `Installation Execution Preflight (B9.4)`.

Expected: without a disk selection and approval, the gate reports BLOCKED. With settings approved and disk/partitions selected, it inspects devices read-only. It **never** authorizes installation. Do not run the legacy B2/B3/B4 destructive menus on a new VM; their guards may be VM-specific.

B9.4 does not yet fully verify ESP GPT type, all possible storage topologies, filesystem integrity, bootloader support, mirrors or package downloadability. It must not be treated as permission to install.

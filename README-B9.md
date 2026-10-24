# Luciole B9.0 — User-owned system identity (safe patch)

This patch updates the existing `lib/system.sh` from `luciole-v0.8-stage-a.zip`.
It removes the hardcoded hostname, timezone, locale, and keymap defaults. Username was already blank.
The Gum System Configuration menu continues to collect each choice.

## Apply in your repository (on the development machine)

1. Back up your current `lib/system.sh`.
2. Extract this ZIP into your repository root, replacing `lib/system.sh`.
3. Run `bash tests/test_b9_settings.sh`.
4. Launch your existing `arch-install.sh` and set hostname, username, timezone, keymap, and locale in System Configuration.

## Safety

This patch does not format, mount, install, chroot, write system configuration, or modify the installed VM.
It is only the first B9 integration step. The existing v0.8 entry point is preview-only.
Do NOT interpret this patch as a complete unattended installer.

Next: implement a reviewed installation manifest, password prompts, and guarded chroot configuration modules.

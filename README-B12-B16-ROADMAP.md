# Bodarovoid B12 development snapshot

This build preserves the **proven B11 VirtualBox-only, no-desktop real installation**.

## Implemented
- B12 structured, readable stage log for B11 installations, saved under `/root/bodarovoid-logs` in the live ISO and copied to `/var/log/bodarovoid/install.log` on successful installation.
- B14 **read-only preview** of Minimal/Full profiles for KDE Plasma, GNOME and Hyprland, with optional extras selection and a package-plan preview.
- B11 destructive path remains **base system only**. Selecting a desktop blocks B11, by design.

## Not yet implemented
- B12 full per-command detailed logs and polished wizard.
- B13 automatic partitioning.
- B14 desktop package installation and desktop configuration; profile choices do not install anything.
- B15 physical hardware support, GPU/driver integration, dual boot, recovery.
- B16 release-quality integration, automated VM matrix and full documentation.

## Test safely
```
bash -n arch-install.sh lib/*.sh
bash tests/test_b11_vm_install.sh
bash tests/test_b11_2_hardening.sh
bash tests/test_b12_profiles.sh
```

The new UI item is `Desktop Package Profiles (Preview)`.
Do not authorize a destructive installation just to test profiles or logging.

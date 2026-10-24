# Desktop essentials update

GNOME Minimal and Full now install `gnome-console` as a locked required package, plus `gnome-keyring`, `gvfs`, and `xdg-desktop-portal-gnome`.

KDE Plasma already installs `konsole` and `dolphin` as required packages.

Hyprland now installs both `kitty` and `foot` as required packages, so a second terminal is available if Kitty has problems in VMware. The default Hyprland keybinding may still target Kitty; `foot` is an alternative, not an automatic fallback.

These packages are part of the desktop's required package list for both Minimal and Full profiles and are included in the installation package aggregation.

**Testing:** Shell syntax checks passed; no new full install/reboot was performed. Treat this as a test build, not a certified stable release.

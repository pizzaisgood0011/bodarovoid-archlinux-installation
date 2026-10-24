# Bodarovoid B17 — Package Explorer Preview

New guided step **5. Customize system packages / online search** works with any desktop, including No desktop.

- Recommended system packages are preselected and removable; optional system packages are selectable.
- Official package searches use the Arch ISO's synchronized pacman repository indexes (`pacman -Ssq`). Update with `pacman -Sy` only when appropriate, before searching. Official additions are included in the real `pacstrap` package array.
- AUR searches use the AUR RPC v5 HTTPS API (`curl` + `jq`); selected AUR package names are **only saved** to `/var/lib/bodarovoid-aur-requests.txt` in the installed system. AUR PKGBUILDs are untrusted community recipes; review and build them as an unprivileged user after reboot. The installer intentionally does NOT build AUR packages automatically.
- Changing package choices clears B10.9 guard state. Repeat safety approvals before installing.
- This is an experimental preview. It has passed Bash syntax checks only, not a VM installation test. Physical disks remain blocked.

## Known limitations

- Gum search is query-then-filter, **not per-keystroke live network suggestions**.
- Official search relies on locally synchronized pacman repo indexes; AUR lookup is online.
- Selected official package names are not independently revalidated against a fresh repository index at install time; pacstrap will fail if unavailable.
- Existing B16 disk restrictions, destructive warnings, and system configuration workflow remain in place.

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/desktop_profiles.sh
for DESKTOP in 'KDE Plasma' GNOME Hyprland; do
  for DESKTOP_INSTALL_TYPE in Minimal Full; do
    DESKTOP_EXTRA_SELECTED=()
    profile_validate
    profile_packages | grep -q .
  done
  DESKTOP_INSTALL_TYPE=Minimal
  DESKTOP_EXTRA_SELECTED=(firefox)
  profile_validate
  profile_packages | grep -Fxq firefox
  DESKTOP_EXTRA_SELECTED=('not-a-real-package')
  if profile_validate; then echo 'Invalid optional package accepted' >&2; exit 1; fi
done
DESKTOP=none
DESKTOP_EXTRA_SELECTED=()
[[ -z $(profile_packages) ]]
echo 'PASS: B14 profile selection and validation (no disk writes)'

#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source lib/desktop_profiles.sh
source lib/install_log.sh
for DESKTOP in 'KDE Plasma' GNOME Hyprland; do
  DESKTOP_INSTALL_TYPE=Minimal
  profile_packages | grep -q .
  DESKTOP_INSTALL_TYPE=Full
  profile_packages | grep -q .
done
DESKTOP=none
[[ -z $(profile_packages) ]]
BODAROVOID_LOG_DIR=$(mktemp -d)
trap 'rm -rf -- "$BODAROVOID_LOG_DIR"' EXIT
b12_log_init
b12_log OK 'Test stage complete' >/dev/null
grep -q 'Test stage complete' "$BODAROVOID_LOG_FILE"
echo 'PASS: B12 logs and B14 preview profiles (NO DISK WRITES)'

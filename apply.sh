#!/usr/bin/env bash
set -Eeuo pipefail
repo="$(pwd)"
[[ -f "$repo/lib/mount_executor.sh" && -f "$repo/lib/format_executor.sh" ]] || { echo 'Run from the repository root.' >&2; exit 1; }
python - "$repo/lib/mount_executor.sh" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='''  [[ ${DISK:-} == /dev/sdc &&
     ${EFI_PART:-} == /dev/sdc1 &&
     ${ROOT_PART:-} == /dev/sdc3 &&
     ${SWAP_PART:-} == /dev/sdc2 ]] ||
    { mount_exec_fail 'Only the approved /dev/sdc VM partition layout is allowed.'; return 1; }'''
new='''  case "${DISK:-}:${EFI_PART:-}:${ROOT_PART:-}:${SWAP_PART:-}" in
    /dev/sdc:/dev/sdc1:/dev/sdc3:/dev/sdc2|/dev/sdb:/dev/sdb1:/dev/sdb3:/dev/sdb2) ;;
    *) mount_exec_fail 'Only approved /dev/sdb or /dev/sdc VM partition layouts are allowed.'; return 1 ;;
  esac'''
assert s.count(old)==1, 'Expected layout guard not found exactly once'
s=s.replace(old,new,1)
old='''  [[ -z $(swapon --noheadings --raw --output NAME 2>/dev/null) ]] ||
    { mount_exec_fail 'Swap is already active.'; return 1; }'''
new='''  local active_swaps
  active_swaps=$(swapon --show=NAME --noheadings --raw) ||
    { mount_exec_fail 'Cannot inspect active swap.'; return 1; }
  [[ -z $active_swaps ]] ||
    { mount_exec_fail 'Swap is already active.'; return 1; }'''
assert s.count(old)==1, 'Expected swap check not found exactly once'
s=s.replace(old,new,1)
old="  if ! gum confirm 'Mount /dev/sdc3, /dev/sdc1 and activate /dev/sdc2 swap?'; then"
new='  if ! gum confirm "Mount $ROOT_PART at /mnt, $EFI_PART at /mnt/boot, and activate $SWAP_PART swap?"; then'
assert s.count(old)==1, 'Expected confirmation not found exactly once'
s=s.replace(old,new,1)
p.write_text(s)
PY
bash -n "$repo/lib/mount_executor.sh"
echo 'Mount patch applied. No mounts or formatting performed.'

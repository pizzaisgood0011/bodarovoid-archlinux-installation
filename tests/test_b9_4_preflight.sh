#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/system.sh
source lib/config_review.sh
source lib/workflow_b9_3.sh
source lib/preflight_b94.sh
DISK=''; EFI_PART=''; ROOT_PART=''; SWAP_PART=''
b94_run
((${#B94_ERRORS[@]} > 0))
printf '%s\n' "${B94_ERRORS[@]}" | grep -q 'approval'
printf '%s\n' "${B94_ERRORS[@]}" | grep -q 'disk'
! grep -Eq '(^|[[:space:]])(mkfs|wipefs|parted|sgdisk|pacstrap|mount)[[:space:]]' lib/preflight_b94.sh
printf 'B9.4 read-only blocked-state tests passed.\n'

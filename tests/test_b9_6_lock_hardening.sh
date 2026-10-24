#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/preflight_b95.sh
# Test stream hashing with embedded NUL bytes without accessing block devices.
b95_identity() { printf 'disk\0%s\0part\0%s\0' "$FAKE_DISK" "$FAKE_PART"; }
b94_run() { B94_ERRORS=(); }
b93_is_approved() { return 0; }
b93_snapshot() { printf 'approved-settings'; }
FAKE_DISK=/dev/mockA FAKE_PART=uuidA
expected=$(printf 'disk\0/dev/mockA\0part\0uuidA\0' | sha256sum)
[[ $(b95_fingerprint) == "${expected%% *}" ]]
B95_APPROVED_FINGERPRINT=$(b95_fingerprint)
B95_APPROVED_SETTINGS=$(b93_snapshot)
b95_is_approved
FAKE_DISK=/dev/mockB
! b95_is_approved
FAKE_DISK=/dev/mockA FAKE_PART=uuidB
! b95_is_approved
FAKE_PART=uuidA
b95_is_approved
b95_identity() { return 1; }
! b95_fingerprint
! b95_is_approved
printf 'B9.6 NUL-safe fingerprint and lock invalidation tests passed.\n'

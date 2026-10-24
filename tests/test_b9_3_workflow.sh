#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/system.sh
source lib/config_review.sh
source lib/workflow_b9_3.sh
# Isolate approval handoff from the host OS locale database.
config_review_validate() { system_valid_hostname "$HOSTNAME" && system_valid_username "$USERNAME"; }
HOSTNAME='arch-box'; USERNAME='alice'; TIMEZONE='Etc/UTC'; KEYMAP='us'; LOCALE='en_US.UTF-8'; DESKTOP='none'
if b93_preview >/dev/null 2>&1; then echo 'Unapproved preview accepted' >&2; exit 1; fi
CONFIG_REVIEW_APPROVED=1
b93_capture_approval
b93_is_approved
b93_preview >/dev/null
[[ $B93_PLAN_READY == 1 ]]
HOSTNAME='changed'
if b93_is_approved >/dev/null 2>&1; then echo 'Changed settings accepted' >&2; exit 1; fi
if b93_preview >/dev/null 2>&1; then echo 'Changed settings preview accepted' >&2; exit 1; fi
[[ $B93_PLAN_READY == 0 ]]
HOSTNAME='arch-box'
CONFIG_REVIEW_APPROVED=0
if b93_is_approved >/dev/null 2>&1; then echo 'Revoked approval accepted' >&2; exit 1; fi
printf 'B9.3 non-destructive handoff tests passed.\n'

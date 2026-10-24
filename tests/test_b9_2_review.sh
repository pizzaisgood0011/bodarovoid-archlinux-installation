#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/system.sh
source lib/config_review.sh
[[ $CONFIG_REVIEW_APPROVED == 0 ]]
HOSTNAME='arch-box'; USERNAME='alice'; TIMEZONE='Etc/UTC'; KEYMAP='us'; LOCALE='en_US.UTF-8'
system_valid_hostname "$HOSTNAME"
system_valid_username "$USERNAME"
config_review_reset
[[ $CONFIG_REVIEW_APPROVED == 0 ]]
HOSTNAME='-bad'
if config_review_validate >/dev/null 2>&1; then echo 'Invalid hostname accepted' >&2; exit 1; fi
HOSTNAME='arch-box'; USERNAME='root'
if config_review_validate >/dev/null 2>&1; then echo 'Root username accepted' >&2; exit 1; fi
printf 'B9.2 non-destructive review tests passed.\n'

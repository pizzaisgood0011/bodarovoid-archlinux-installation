#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/system.sh
source lib/system_executor.sh
HOSTNAME='arch-test'
USERNAME='tester'
TIMEZONE='UTC'
KEYMAP='us'
LOCALE='en_US.UTF-8'
system_exec_validate
system_exec_preview > /dev/null
HOSTNAME='-invalid'
if system_exec_validate >/dev/null 2>&1; then echo 'Invalid hostname accepted' >&2; exit 1; fi
HOSTNAME='arch-test'
if system_exec_apply /mnt NOT-CONFIRMED >/dev/null 2>&1; then echo 'Missing confirmation accepted' >&2; exit 1; fi
printf 'B9.1 validation and non-destructive tests passed.\n'

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/system.sh
[[ -z $HOSTNAME && -z $USERNAME && -z $TIMEZONE && -z $KEYMAP && -z $LOCALE ]]
system_valid_hostname arch-workstation
! system_valid_hostname '-bad'
system_valid_username alice
! system_valid_username root
! system_valid_username 'Bad User'
printf 'B9 settings tests passed (no system changes).\n'

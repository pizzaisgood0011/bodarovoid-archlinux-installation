#!/usr/bin/env bash
# Simple stage log; never log passwords or secret inputs.
BODAROVOID_LOG_DIR=${BODAROVOID_LOG_DIR:-/root/bodarovoid-logs}
BODAROVOID_LOG_FILE=''
b12_log_init() {
  mkdir -p -m 0700 -- "$BODAROVOID_LOG_DIR" || return 1
  BODAROVOID_LOG_FILE="$BODAROVOID_LOG_DIR/install-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
  ( umask 077; : > "$BODAROVOID_LOG_FILE" )
  b12_log INFO 'Installation started'
}
b12_log() {
  local level=$1 message=$2
  [[ -n ${BODAROVOID_LOG_FILE:-} ]] || return 0
  printf '[%s] [%-7s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$level" "$message" | tee -a -- "$BODAROVOID_LOG_FILE"
}
b12_log_copy() {
  [[ -n ${BODAROVOID_LOG_FILE:-} && -f $BODAROVOID_LOG_FILE && -d /mnt/var/log ]] || return 1
  install -d -m 0700 /mnt/var/log/bodarovoid
  install -m 0600 -- "$BODAROVOID_LOG_FILE" /mnt/var/log/bodarovoid/install.log
}

#!/usr/bin/env bash
# Called by fzf on query changes. Query is a positional argument, never evaluated.
set -u
source_type=${1:-}
query=${2:-}
[[ ${#query} -ge 2 ]] || exit 0
case "$source_type" in
  Official) pacman -Ssq -- "$query" 2>/dev/null | head -60 || true ;;
  AUR)
    command -v curl >/dev/null && command -v jq >/dev/null || exit 0
    curl -fsSG --connect-timeout 2 --max-time 5 \
      --data-urlencode 'by=name-desc' --data-urlencode "arg=$query" \
      'https://aur.archlinux.org/rpc/v5/search' 2>/dev/null | \
      jq -r '.results[:60][]? | .Name' 2>/dev/null || true ;;
esac

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ -f arch-install.sh && -f lib/system.sh && -f lib/ui.sh ]] || { echo 'Run from repository root after copying patch files.' >&2; exit 1; }
if grep -Fq 'source "$BASE_DIR/lib/config_review.sh"' arch-install.sh; then echo 'B9.2 already connected.'; exit 0; fi
cp -p arch-install.sh "arch-install.sh.before-b9.2.$(date +%Y%m%d%H%M%S)"
python3 - <<'PY'
from pathlib import Path
p=Path('arch-install.sh'); s=p.read_text()
a='source "$BASE_DIR/lib/system.sh"'
assert s.count(a)==1, 'Cannot locate system module import'
s=s.replace(a,a+'\nsource "$BASE_DIR/lib/config_review.sh"')
a="'System Configuration' 'Review Selections'"
assert s.count(a)==1, 'Unexpected main menu structure'
s=s.replace(a,"'System Configuration' 'Review System Settings (B9.2)' 'Review Selections'")
a="'System Configuration') system_menu ;;"
assert s.count(a)==1, 'Unexpected menu case structure'
s=s.replace(a,a+"\n      'Review System Settings (B9.2)') config_review_menu ;;")
p.write_text(s)
PY
bash -n arch-install.sh lib/config_review.sh tests/test_b9_2_review.sh
printf 'B9.2 connected. No installation actions enabled.\n'

#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python3 - <<'PY2'
from pathlib import Path
import shutil
p=Path('arch-install.sh')
s=p.read_text()
anchor='source "$BASE_DIR/lib/preflight_b94.sh"'
menu="'Installation Execution Preflight (B9.4)'"
case="'Installation Execution Preflight (B9.4)') b94_menu ;;"
if not (Path('lib/preflight_b95.sh').exists() and anchor in s and menu in s and case in s):
    raise SystemExit('B9.4 integration not found; no files changed. Apply B9.4 first.')
if 'lib/preflight_b95.sh' in s:
    print('B9.5 already integrated')
else:
    shutil.copy2(p,'arch-install.sh.b95-backup')
    s=s.replace(anchor,anchor+'\nsource "$BASE_DIR/lib/preflight_b95.sh"',1)
    s=s.replace(menu,menu+" 'Target Identity Lock (B9.5)'",1)
    s=s.replace(case,case+"\n      'Target Identity Lock (B9.5)') b95_menu ;;",1)
    p.write_text(s)
    print('B9.5 integrated; backup created.')
PY2
bash -n arch-install.sh lib/preflight_b95.sh

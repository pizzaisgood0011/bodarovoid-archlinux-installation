#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
file=arch-install.sh
[[ -f $file && -f lib/workflow_b9_3.sh && -f lib/preflight_b94.sh ]] || { echo 'Missing B9.3.2 source or B9.4 module'; exit 1; }
python3 - <<'PY'
from pathlib import Path
p=Path('arch-install.sh'); s=p.read_text()
anchor='source "$BASE_DIR/lib/workflow_b9_3.sh"'
menu="'Approved Settings Handoff (B9.3)'"
case="'Approved Settings Handoff (B9.3)') b93_menu ;;"
assert anchor in s and menu in s and case in s, 'Unexpected installer layout: no changes made'
if 'lib/preflight_b94.sh' in s:
    print('B9.4 already integrated')
else:
    import shutil
    shutil.copy2(p, p.with_suffix('.sh.b94-backup'))
    s=s.replace(anchor,anchor+'\nsource "$BASE_DIR/lib/preflight_b94.sh"',1)
    s=s.replace(menu,menu+" 'Installation Execution Preflight (B9.4)'",1)
    s=s.replace(case,case+"\n      'Installation Execution Preflight (B9.4)') b94_menu ;;",1)
    p.write_text(s)
    print('B9.4 integrated; backup: arch-install.sh.b94-backup')
PY
bash -n arch-install.sh lib/preflight_b94.sh

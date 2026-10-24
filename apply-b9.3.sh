#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
[[ -f arch-install.sh && -f lib/config_review.sh && -f lib/workflow_b9_3.sh ]] || { echo 'Missing B9.2 or B9.3 files' >&2; exit 1; }
python3 - <<'PY'
from pathlib import Path
p=Path('arch-install.sh')
s=p.read_text()
if 'source "$BASE_DIR/lib/workflow_b9_3.sh"' in s:
    print('B9.3 already applied')
    raise SystemExit(0)
anchors = [
    ('source "$BASE_DIR/lib/config_review.sh"', 'source "$BASE_DIR/lib/config_review.sh"\nsource "$BASE_DIR/lib/workflow_b9_3.sh"'),
    ("'Review System Settings (B9.2)' 'Review Selections'", "'Review System Settings (B9.2)' 'Approved Settings Handoff (B9.3)' 'Review Selections'"),
    ("'Review System Settings (B9.2)') config_review_menu ;;", "'Review System Settings (B9.2)') config_review_menu; if [[ ${CONFIG_REVIEW_APPROVED:-0} == 1 ]]; then b93_capture_approval || true; fi ;;\n      'Approved Settings Handoff (B9.3)') b93_menu ;;")
]
for a,b in anchors:
    if s.count(a)!=1: raise SystemExit('Unexpected installer structure; no files changed: '+a)
    s=s.replace(a,b)
import subprocess, tempfile
with tempfile.NamedTemporaryFile(mode='w', suffix='.sh') as tmp:
    tmp.write(s); tmp.flush()
    subprocess.run(['bash','-n',tmp.name],check=True)
backup=p.with_name('arch-install.sh.before-b9.3')
if backup.exists(): raise SystemExit('Backup already exists; no files changed')
backup.write_text(p.read_text())
p.write_text(s)
print('B9.3 connected. Original backed up to arch-install.sh.before-b9.3')
PY

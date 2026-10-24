#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
bash -n arch-install.sh lib/config_review.sh lib/workflow_b9_3.sh lib/system_executor.sh
grep -Fq 'source "$BASE_DIR/lib/config_review.sh"' arch-install.sh
grep -Fq 'source "$BASE_DIR/lib/workflow_b9_3.sh"' arch-install.sh
grep -Fq "'Review System Settings (B9.2)') config_review_menu" arch-install.sh
grep -Fq "'Approved Settings Handoff (B9.3)') b93_menu" arch-install.sh
bash tests/test_b9_settings.sh
if [[ -r /etc/locale.gen && -d /usr/share/kbd/keymaps ]]; then
  bash tests/test_b9_1_system_executor.sh
else
  printf 'SKIP B9.1 live-environment test: Arch locale/keymap files unavailable. Run on Arch ISO.\n'
fi
bash tests/test_b9_2_review.sh
bash tests/test_b9_3_workflow.sh
printf 'B9 integrated menu checks passed (no disk writes).\n'

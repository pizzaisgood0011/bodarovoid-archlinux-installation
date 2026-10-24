#!/usr/bin/env bash
# B9.7: read-only pipeline rehearsal. Never executes installation commands.
B97_STEPS=(
  'Verify approved system settings'
  'Verify installation preflight'
  'Verify locked disk and partition identities'
  'SIMULATE: prepare EFI, root and optional swap filesystems'
  'SIMULATE: mount root and EFI under installation target'
  'SIMULATE: install base packages with pacstrap'
  'SIMULATE: generate fstab and configure system'
  'SIMULATE: configure GRUB bootloader'
  'SIMULATE: finish installation and report'
)
B97_ERRORS=()
B97_READY=0

b97_validate() {
  B97_ERRORS=()
  B97_READY=0
  if ! declare -F b93_is_approved >/dev/null || ! b93_is_approved; then
    B97_ERRORS+=('B9.2/B9.3 settings approval is missing or stale.')
  fi
  if ! declare -F b94_run >/dev/null; then
    B97_ERRORS+=('B9.4 preflight module is unavailable.')
  else
    b94_run
    if ((${#B94_ERRORS[@]})); then
      B97_ERRORS+=("B9.4 preflight blocked: ${#B94_ERRORS[@]} error(s).")
      local err
      for err in "${B94_ERRORS[@]}"; do B97_ERRORS+=("B9.4: $err"); done
    fi
  fi
  if ! declare -F b95_is_approved >/dev/null || ! b95_is_approved; then
    B97_ERRORS+=('B9.5 target lock is missing, stale, or changed.')
  fi
  if ((${#B97_ERRORS[@]} == 0)); then B97_READY=1; return 0; fi
  return 1
}

b97_report() {
  local step
  printf 'B9.7 — INSTALLATION PIPELINE SIMULATION (READ ONLY)\n\n'
  if ! b97_validate; then
    printf 'BLOCKED — simulation cannot proceed:\n'
    for step in "${B97_ERRORS[@]}"; do printf '  - %s\n' "$step"; done
    printf '\nNo disk changes or installation commands were performed.\n'
    return 1
  fi
  printf 'Target: %s\nEFI: %s\nRoot: %s\nSwap: %s\n\n' \
    "$DISK" "$EFI_PART" "$ROOT_PART" "${SWAP_PART:-none}"
  for step in "${B97_STEPS[@]}"; do printf '[SIMULATED] %s\n' "$step"; done
  printf '\nSIMULATION COMPLETE — no changes made. Real installation remains DISABLED.\n'
}

b97_menu() {
  ui_heading 'B9.7 — Installation Pipeline Simulation (READ ONLY)'
  printf 'This screen only prints a simulated plan. No installation commands run.\n\n'
  local action
  action=$(ui_choose 'Choose an action' 'Run read-only simulation' 'Back') || return 0
  [[ $action == 'Run read-only simulation' ]] || return 0
  ui_heading 'B9.7 — Simulation Results'
  b97_report || true
  ui_pause
}

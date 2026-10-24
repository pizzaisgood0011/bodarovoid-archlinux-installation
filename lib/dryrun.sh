#!/usr/bin/env bash
# Structured display-only operations. Never execute these descriptions as commands.
DRYRUN_OPERATIONS=()

dryrun_build() {
  DRYRUN_OPERATIONS=()
  [[ -n ${DISK:-} ]] && DRYRUN_OPERATIONS+=("CHECK  Disk identity: $DISK")
  DRYRUN_OPERATIONS+=("${FORMAT_OPERATIONS[@]}")
  [[ -n ${ROOT_PART:-} ]] && DRYRUN_OPERATIONS+=("PLAN   Mount root at /mnt")
  [[ -n ${EFI_PART:-} ]] && DRYRUN_OPERATIONS+=("PLAN   Mount selected EFI at /mnt/boot (provisional; bootloader setup not implemented)")
  DRYRUN_OPERATIONS+=("PLAN   Install ${#PACKAGE_PLAN[@]} selected packages")
  DRYRUN_OPERATIONS+=("PLAN   Configure locale, users, network and initramfs")
  DRYRUN_OPERATIONS+=("PLAN   Configure $BOOTLOADER bootloader")
  DRYRUN_OPERATIONS+=("STOP   Installation engine disabled: no operations executed")
}

dryrun_menu() {
  packages_build_plan
  preflight_run
  dryrun_build
  ui_heading 'Installation Dry Run (READ ONLY)'
  printf 'Target disk: %s\n\n' "${DISK:-Not selected}"
  printf '%s\n' "${DRYRUN_OPERATIONS[@]}"
  printf '\nPreflight: %d error(s), %d warning(s)\n' "${#PREFLIGHT_ERRORS[@]}" "${#PREFLIGHT_WARNINGS[@]}"
  local item
  for item in "${PREFLIGHT_ERRORS[@]}"; do printf 'ERROR: %s\n' "$item"; done
  for item in "${PREFLIGHT_WARNINGS[@]}"; do printf 'WARN: %s\n' "$item"; done
  printf '\n'
  ui_error 'SIMULATION ONLY. NO DISK OPERATIONS EXECUTED.'
  ui_pause
}

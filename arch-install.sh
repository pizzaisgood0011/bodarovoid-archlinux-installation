#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/disks.sh"
source "$BASE_DIR/lib/partitions.sh"
source "$BASE_DIR/lib/hardware.sh"
source "$BASE_DIR/lib/system.sh"
source "$BASE_DIR/lib/config_review.sh"
source "$BASE_DIR/lib/workflow_b9_3.sh"
source "$BASE_DIR/lib/system_executor.sh"
source "$BASE_DIR/lib/validation.sh"
source "$BASE_DIR/config/packages.sh"
source "$BASE_DIR/lib/packages.sh"
source "$BASE_DIR/lib/encryption.sh"
source "$BASE_DIR/lib/preflight.sh"
source "$BASE_DIR/lib/preflight_b94.sh"
source "$BASE_DIR/lib/preflight_b95.sh"
source "$BASE_DIR/lib/pipeline_b97.sh"
source "$BASE_DIR/lib/preparation_b98.sh"
source "$BASE_DIR/lib/safety_b99.sh"
source "$BASE_DIR/lib/safety_b991.sh"
source "$BASE_DIR/lib/engine_b100.sh"
source "$BASE_DIR/lib/authorization_b101.sh"
source "$BASE_DIR/lib/format_b102.sh"
source "$BASE_DIR/lib/mount_b103.sh"
source "$BASE_DIR/lib/base_b104.sh"
source "$BASE_DIR/lib/config_b105.sh"
source "$BASE_DIR/lib/bootloader_b106.sh"
source "$BASE_DIR/lib/pipeline_audit_b107.sh"
source "$BASE_DIR/lib/readiness_b108.sh"
source "$BASE_DIR/lib/prewrite_b109.sh"
source "$BASE_DIR/lib/install_log.sh"
source "$BASE_DIR/lib/desktop_profiles.sh"
source "$BASE_DIR/lib/system_packages_b17.sh"
source "$BASE_DIR/lib/guided_disk_b13.sh"
source "$BASE_DIR/lib/virtual_target.sh"
source "$BASE_DIR/lib/vm_install.sh"
source "$BASE_DIR/lib/guided_apply_b132.sh"
source "$BASE_DIR/lib/wizard_b15.sh"
source "$BASE_DIR/lib/plan.sh"
source "$BASE_DIR/lib/safety.sh"
source "$BASE_DIR/lib/dryrun.sh"
source "$BASE_DIR/lib/format_policy.sh"
source "$BASE_DIR/lib/format_review.sh"
source "$BASE_DIR/lib/format_executor.sh"
source "$BASE_DIR/lib/mount_executor.sh"
source "$BASE_DIR/lib/mount_cleanup.sh"

DISK=''
EFI_PART=''
ROOT_PART=''
SWAP_PART=''

review_menu() {
  ui_heading 'Review Selections'
  ui_status
  system_status
  printf '\n'
  ui_note 'Physical installation requires explicit opt-in; target disk will be erased.'
  if [[ -z $DISK || -z $EFI_PART || -z $ROOT_PART || -z $USERNAME ]]; then
    ui_note 'Incomplete: select disk, EFI, root, and username before installation is added.'
  fi
  ui_pause
}

main() {
  if ! command -v gum >/dev/null 2>&1; then
    echo 'gum is required. On the Arch ISO: pacman -S --needed gum'
    exit 1
  fi
  if [[ $EUID -ne 0 ]]; then
    echo 'Run this installer as root on the Arch live ISO.'
    exit 1
  fi
  b15_wizard
  while true; do
    ui_heading 'Advanced / Legacy Menu'
    ui_status
    local action
    action=$(ui_choose 'Choose an action' 'Disk & Partitions' 'Guided Disk Layout (B13 Preview)' 'Guided GPT Creation — ERASES DISK' 'System Configuration' 'Review System Settings (B9.2)' 'Approved Settings Handoff (B9.3)' 'Installation Execution Preflight (B9.4)' 'Target Identity Lock (B9.5)' 'Installation Pipeline Simulation (B9.7)' 'Filesystem Preparation Preview (B9.8)' 'Partition Safety Policy (B9.9)' 'EFI Creation vs Reuse Policy (B9.9.1)' 'Installation Engine Foundation (B10.0)' 'Authorization Rehearsal (B10.1)' 'Formatting Engine Design (B10.2)' 'Mounting & Cleanup Plan (B10.3)' 'Base System Installation Plan (B10.4)' 'System Configuration Plan (B10.5)' 'Bootloader Integration Plan (B10.6)' 'Full Pipeline Safety Audit (B10.7)' 'Controlled Execution Readiness (B10.8)' 'Independent Pre-Write Guards (B10.9)' 'INSTALL ARCH — VM or Physical Disk' 'Review Selections' 'Safety & Validation' 'Package Selection' 'Desktop Packages (B14)'  'Encryption (Preview)' 'Installation Plan & Preflight' 'Installation Dry Run' 'Formatting Policy (Preview)' 'Formatting Approval Rehearsal' 'Exit') || break
    case "$action" in
      'Disk & Partitions') disk_menu ;;
      'Guided Disk Layout (B13 Preview)') b13_menu ;;
      'Guided GPT Creation — ERASES DISK') b132_menu ;;
      'System Configuration') system_menu ;;
      'Review System Settings (B9.2)') config_review_menu ;;
      'Approved Settings Handoff (B9.3)') b93_menu ;;
      'Installation Execution Preflight (B9.4)') b94_menu ;;
      'Target Identity Lock (B9.5)') b95_menu ;;
      'Installation Pipeline Simulation (B9.7)') b97_menu ;;
      'Filesystem Preparation Preview (B9.8)') b98_menu ;;
      'Partition Safety Policy (B9.9)') b99_menu ;;
      'EFI Creation vs Reuse Policy (B9.9.1)') b991_menu ;;
      'Installation Engine Foundation (B10.0)') b100_menu ;;
      'Authorization Rehearsal (B10.1)') b101_menu ;;
      'Formatting Engine Design (B10.2)') b102_menu ;;
      'Mounting & Cleanup Plan (B10.3)') b103_menu ;;
      'Base System Installation Plan (B10.4)') b104_menu ;;
      'System Configuration Plan (B10.5)') b105_menu ;;
      'Bootloader Integration Plan (B10.6)') b106_menu ;;
      'Full Pipeline Safety Audit (B10.7)') b107_menu ;;
      'Controlled Execution Readiness (B10.8)') b108_menu ;;
      'Independent Pre-Write Guards (B10.9)') b109_menu ;;
      'INSTALL ARCH — VM or Physical Disk') vm_install_menu ;; 
      'Review Selections') review_menu ;;
      'Safety & Validation') validation_menu ;;
      'Package Selection') packages_menu ;;
      'Desktop Packages (B14)' ) profile_menu ;;
      'Encryption (Preview)') encryption_menu ;;
      'Installation Plan & Preflight') plan_menu ;;
      'Installation Dry Run') dryrun_menu ;;
      'Formatting Policy (Preview)') format_policy_menu ;;
      'Formatting Approval Rehearsal') format_review_menu ;;
      'Exit') break ;;
    esac
  done
  printf 'Installer closed.\n'
}

main "$@"

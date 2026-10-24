Luciole B4.2: targeted recovery for the interrupted /dev/sdb VirtualBox pacstrap attempt.
Run from repository root, after updating the ISO keyring and populating the target keyring:
  bash -n luciole-b4.2-recovery-patch/b4_recover.sh
  LUCIOLE_ENABLE_VM_RECOVERY=1 bash luciole-b4.2-recovery-patch/b4_recover.sh
Requires B4.0 preflight, gum, and mounted /dev/sdb partitions.
No formatting, package cache removal, or signature bypass. Do not reboot before B5.

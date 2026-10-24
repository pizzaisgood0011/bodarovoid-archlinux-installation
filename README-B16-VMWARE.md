# Bodarovoid B16 VMware + VirtualBox preview

This patch expands **virtual-machine-only** installation from VirtualBox to VMware Workstation. **Physical disk installation is intentionally blocked** until independent safety and boot testing. This is not a general-purpose real-hardware release.

Supported: UEFI boot, GPT, new EFI + swap + ext4 root, GRUB, verified VirtualBox/VMware guest and corresponding virtual disk model. Existing installer approvals still apply. NVMe partition suffixes are handled in the guided GPT creator. Other layouts, EFI reuse and BIOS are not supported by the real installer.

Before attempting destructive testing: create a disposable VM with only one empty virtual disk, snapshot it, boot the Arch ISO in UEFI mode, and inspect `lsblk -o NAME,TYPE,SIZE,MODEL,TRAN,MOUNTPOINTS`. VMware disk model strings vary; if the guard blocks yours, capture `/sys/class/block/sda/device/model` and do not bypass the guard. **This patch has only static Bash syntax checks, not live VM installation testing.**

A successful installation is not proof that Hyprland will start: graphical acceleration depends on VMware's virtual GPU and guest Mesa/Wayland support.

# Limine automatic bootloader fix — experimental

Fixed installer failure caused by checking `/boot/EFI` before creating it. The installer now creates `/boot/EFI/BOOT`, copies the x86-64 UEFI Limine binary, generates `/boot/limine.conf` with the filesystem UUID obtained from `blkid`, includes available CPU microcode, and verifies kernel/initramfs files are on the mounted EFI System Partition. The configuration-stage log correctly names the selected bootloader.

This build passed Bash syntax checks, **not** an end-to-end boot test. Use only a disposable VMware/VirtualBox disk. Test ext4 + Limine + no encryption first. LUKS2 and Btrfs + Limine combinations remain experimental.

Note: This does not repair a VM that was already partially installed; it fixes the next clean installation run. Never re-run the destructive installer against a disk containing data you wish to preserve.

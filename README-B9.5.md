# B9.5 — Read-only target identity lock

Copy this patch over the existing project with B9.4 installed, then run:

```bash
bash apply-b9.5.sh
bash tests/test_b9_5_target_lock.sh
bash arch-install.sh
```

Choose partitions and approve settings (B9.2), run B9.4, then open **Target Identity Lock (B9.5)**. Review disk identity and type `LOCK TARGET`. This locks the current disk/partition identity and settings for the current session only. It never writes to a disk or starts installation.

**Important:** The lock is only a preparation-stage check. It is not wired into any destructive B2/B3/B4 code and must not be treated as authorization to run those scripts. Existing legacy formatting menus remain dangerous. Do not use them on real disks. B9.5 does not detect all hazards (e.g., installation media on selected disk, device replacement after lock); future execution must independently revalidate and obtain destructive consent.

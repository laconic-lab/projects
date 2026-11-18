# 03 — Backup and recovery plan

## Targeted preservation
The backup script captures, when present:
- `/var/lib/nvidia/` — runfile installer database
- `/usr/src/nvidia-470.256.02/` — 470 DKMS source/configuration
- `/etc/modprobe.d/`
- `/etc/X11/xorg.conf`
- `/etc/default/grub`
- Kernel, DKMS, package, hold and active-driver state
- Optional `secureupdate` script when its exact path is passed as an argument

Archives are written under this project's `backups/` directory.

## Run
```bash
bash scripts/nvidia-diagnostic.sh
bash scripts/nvidia-backup.sh
```
Optional:
```bash
bash scripts/nvidia-backup.sh /exact/path/to/secureupdate
```

## Limitations
This is not a full system image and does not back up the entire OS or package payloads. It is not an automated restore package. The installer database contains historical mixed-version records; preserve it as evidence, but do not blindly restore it or run its uninstaller.

Verify an archive:
```bash
tar -tzf backups/nvidia-recovery-*.tar.gz | less
```
Keep a copy on external storage before package changes.

## Recovery principle
Do not run `nvidia-uninstall`, remove DKMS registrations, purge packages, or recreate links from memory. Inspect the backup and current system first, then create a specific recovery plan.

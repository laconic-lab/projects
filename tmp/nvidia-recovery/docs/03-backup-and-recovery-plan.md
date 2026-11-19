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

Archives are written under this project's `backups/` directory. The script verifies tar/gzip integrity and now checks that every selected protected system path (and optional SecureUpdate copy, if supplied) is present in the archive before publishing it. The archive is created with private permissions (`0600`).

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

Verify an archive manually:
```bash
tar -tzf /exact/path/to/nvidia-recovery-YYYYMMDD-HHMMSS.tar.gz | less
```

The script's built-in verification checks archive readability and the presence of each protected path selected during that run. It does not compare every archived file's contents against the live filesystem, prove that a future restore will boot, or include kernel package payloads.
Keep a copy on external storage before package changes.

## Recovery principle
Do not run `nvidia-uninstall`, remove DKMS registrations, purge packages, or recreate links from memory. Inspect the backup and current system first, then create a specific recovery plan.

# NVIDIA Recovery — Linux Mint

Project for preserving and diagnosing the NVIDIA configuration on a Dell Precision M4800 / Quadro K2100M.

## Known snapshot (2026-11-01)
- Linux Mint 22.1 Wilma / Ubuntu 24.04 Noble
- GPU: NVIDIA Quadro K2100M (Kepler)
- Running kernel: `6.8.0-147-generic`
- Active driver: `470.256.02`, installed via NVIDIA's official runfile with DKMS integration
- APT 535/580 packages remain installed
- DKMS: 470 installed for 6.8.0-147; 580 installed for 6.8.0-139 and built for 6.8.0-147; VirtualBox 7.0.16 installed for 6.8.0-147

## First use
Extract this project to `/home/laco/Documents/NVIDIA-Recovery/`, then run:

```bash
bash scripts/nvidia-diagnostic.sh
bash scripts/nvidia-backup.sh
```

Optional exact path to include the update script in the backup:
```bash
bash scripts/nvidia-backup.sh /exact/path/to/secureupdate
```

## Safety
- Diagnostic script is read-only with respect to system configuration and packages; it writes a report under `reports/`.
- Backup script reads selected protected files using sudo and writes an archive under `backups/`.
- No automated correction/purge script is included.
- Do not run `nvidia-uninstall`, purge packages, remove DKMS registrations, or alter library links without a separately reviewed and explicitly approved plan.
- A DKMS `built` entry does not mean that branch is loaded.
- S3 resume troubleshooting is separate from the package cleanup.

See `docs/` for the investigation, diagrams, backup plan and correction policy.

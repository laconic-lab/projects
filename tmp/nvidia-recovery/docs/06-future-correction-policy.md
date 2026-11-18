# 06 — Future correction policy

## Current decision
No automated correction script is included.

## Why
This system combines a working runfile-managed 470 installation, APT 535/580 packages, transitional dependencies, shared DKMS identity, generic symlinks owned by APT 580 but resolving to 470 libraries, and mixed historical installer records.

Blind purge, autoremove, runfile uninstaller or DKMS removal could break the working driver.

## Requirements before a correction script is considered
1. Perform a manual correction under explicit approval.
2. Verify 470 remains loaded and the external display works.
3. Verify DKMS and library links.
4. Reboot successfully.
5. Save before/after reports and exact transaction record.
6. Document rollback and failure handling.

Any future correction script must verify OS/GPU/kernel/driver, abort on unexpected package state, back up first, show the exact APT simulation, require interactive confirmation, avoid `-y` on destructive transactions, never blindly call `nvidia-uninstall`, and verify after execution.

## S3 resume
S3 resume black-screen remains a separate investigation. Do not attribute it to 580 without evidence. Investigate suspend/resume services, kernel logs, module parameters, firmware and display-manager behaviour after the package state is stable.

# Linux Mint — Privacy and Background Component Change Log

## System
- **OS:** Linux Mint 22 Cinnamon
- **Hardware:** Dell Precision M4800
- **Date:** 2026-11-19

## 2026-11-19 — Initial privacy-related changes

### kerneloops
- **Decision:** Disable the kernel-oops collection/reporting daemon.
- **Action:** Set `allow-submit = no` and `allow-pass-on = no` in `/etc/kerneloops.conf`; disabled and stopped `kerneloops.service`.
- **Observation:** Verification reported service `disabled` and `inactive`; both configuration values were `no`.
- **Backup:** `/var/backups/mint-privacy-20261119_043528/kerneloops.conf`

### GeoClue
- **Decision:** Disable the system location service.
- **Action:** Masked and stopped `geoclue.service`.
- **Observation:** Verification reported service `masked` and `inactive`.
- **Configuration:** `/etc/geoclue/geoclue.conf` was not modified.
- **Backup:** `/var/backups/mint-privacy-20261119_043528/geoclue.conf`

### GeoClue demo agent
- **Decision:** Disable the demo location agent autostart.
- **Action:** Created user override `~/.config/autostart/geoclue-demo-agent.desktop` with `Hidden=true`.
- **Observation:** Override file exists. Session-start behaviour has not yet been independently verified.
- **Backup:** `/var/backups/mint-privacy-20261119_043528/geoclue-demo-agent.desktop`

### motd-news
- **Decision:** Stop scheduled MOTD news activity.
- **Action:** Disabled and stopped `motd-news.timer`.
- **Observation:** Verification reported timer `disabled` and `inactive`. The installed `/etc/update-motd.d/50-motd-news` script contained only `#!/bin/sh`.
- **Package note:** The script is owned by `base-files`; `base-files` was retained. The timer was disabled rather than removing the package.

### mintchat
- **Decision:** Remove the application.
- **Action:** Ran `sudo apt-get remove mintchat`.
- **Observation:** APT removed `mintchat` version `1.8`. No other package was removed. Verification showed package state `rc`, meaning the package was removed while residual configuration files remained.
- **Removal scope:** No purge or autoremove was performed.

### GNOME Online Accounts
- **Decision:** Remove optional online-account desktop integration.
- **Action:** Ran `sudo apt-get remove gnome-online-accounts`.
- **Observation:** APT removed `gnome-online-accounts` version `3.50.4-0ubuntu2` and `gnome-online-accounts-gtk` version `3.50.7+zara`. The prior removal simulation proposed only these two packages.
- **Dependency check:** Installed reverse dependencies identified only `gnome-online-accounts-gtk`. No MintUpdate, APT, login, or essential system service dependency was identified.
- **Related component:** `gvfs-goa-volume-monitor.service` was running before removal. Its post-removal state remains to be verified.

## Retained components

| Component | Decision / status |
|---|---|
| mintreport | Retain. Startup entry was already disabled by the user. Inspected upload actions require explicit user interaction. |
| MintUpdate and package update timers | Retain. Required for normal update functionality. |
| Apport support libraries (`python3-apport`, `python3-problem-report`) | Retain and monitor. Main `apport` package and `apport.service` were absent during inventory. |
| kerneloops package | Still installed; its service is disabled and stopped. |
| GeoClue package | Still installed; its service is masked and stopped. |
| base-files | Retain. |

## Backup
Configuration and original autostart files were copied to:

`/var/backups/mint-privacy-20261119_043528`

## Pending verification
- Verify that GOA D-Bus activation files and processes are absent after package removal.
- Check the post-removal state of `gvfs-goa-volume-monitor.service`.
- Verify GeoClue remains masked and the demo-agent autostart override is effective after a new login.
- Continue auditing other installed background components for external communication capability.

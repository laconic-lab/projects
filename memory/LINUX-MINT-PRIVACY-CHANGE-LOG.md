# Linux Mint — Privacy and Background Component Change Log

## System
- **OS:** Linux Mint 22 Cinnamon
- **Hardware:** Dell Precision M4800
- **Audit date:** 2026-11-19
- **Audit scope:** Identify unsolicited data collection or external transmission without explicit user choice. Ordinary background services, local network discovery, printing, updates, and hardware support are not classified as telemetry without evidence.

## 2026-11-19 — Privacy-related changes

### kerneloops
- **Decision:** Retain the package but disable its daemon; retain permission-based submission policy and prevent third-party forwarding.
- **Action:** Set `allow-submit = ask` and `allow-pass-on = no` in `/etc/kerneloops.conf`; disabled and stopped `kerneloops.service`.
- **Verified state:** Service `disabled` and `inactive`. Configuration values were reported as `ask` and `no`.
- **Evidence boundary:** The presence and behaviour of a working permission prompt have not been verified. No successful report submission was established.
- **Backup:** `/var/backups/mint-privacy-20261119_043528/kerneloops.conf`

### GeoClue
- **Decision:** Disable the system location service and demo-agent autostart.
- **Action:** Masked and stopped `geoclue.service`; created `~/.config/autostart/geoclue-demo-agent.desktop` with `Hidden=true`.
- **Verified state:** Service `masked` and `inactive`; user override file exists.
- **Not yet verified:** Behaviour after a fresh login.
- **Configuration:** `/etc/geoclue/geoclue.conf` was not modified.
- **Backup:** `/var/backups/mint-privacy-20261119_043528/geoclue.conf` and `/var/backups/mint-privacy-20261119_043528/geoclue-demo-agent.desktop`

### motd-news
- **Decision:** Stop scheduled MOTD news activity.
- **Action:** Disabled and stopped `motd-news.timer`.
- **Verified state:** Timer `disabled` and `inactive`. The installed `/etc/update-motd.d/50-motd-news` script contained only `#!/bin/sh`.
- **Package note:** The script is owned by `base-files`; `base-files` was retained.

### mintchat
- **Decision:** Remove the application.
- **Action:** Ran `sudo apt-get remove mintchat`.
- **Result:** APT removed `mintchat` version `1.8`. No other package was removed. Package state `rc` indicated residual configuration files.
- **Removal scope:** No purge or autoremove was performed.

### GNOME Online Accounts
- **Decision:** Remove optional online-account desktop integration.
- **Action:** Ran `sudo apt-get remove gnome-online-accounts`.
- **Result:** APT removed `gnome-online-accounts` version `3.50.4-0ubuntu2` and `gnome-online-accounts-gtk` version `3.50.7+zara`. The prior removal simulation proposed only these two packages.
- **Dependency check:** Installed reverse dependencies identified only `gnome-online-accounts-gtk`. No MintUpdate, APT, login, or essential system-service dependency was identified.
- **Session processes:** Existing `goa-daemon` and `goa-identity-service` processes continued running from deleted executables after package removal. They are expected to exit after logout/login; this remains to be verified.
- **GVFS integration:** Masked and stopped the user-level `gvfs-goa-volume-monitor.service`; verified `masked` and `inactive`. The package-owned D-Bus activation file was left unchanged, and other GVFS components were retained.

## Retained components and audit conclusions

| Component | Decision / evidence |
|---|---|
| mintreport | Retain. Startup entry was already disabled by the user. Inspected upload actions require explicit user interaction. |
| MintUpdate and package update timers | Retain for normal update functionality. |
| Apport support libraries (`python3-apport`, `python3-problem-report`) | Retain. Main `apport` package and `apport.service` were absent during inventory; no active reporting was established. |
| kerneloops | Package retained; daemon disabled/stopped; submission policy `ask`, third-party forwarding `no`. |
| GeoClue | Package retained; service masked/stopped. |
| GVFS | Retain; only the GOA volume-monitor user service is masked. |
| base-files | Retain. |
| Avahi, CUPS, cups-browsed | Retain. Observed activity was local mDNS/DNS-SD discovery and local printing. CUPS listens only on loopback. No unsolicited telemetry transmission evidence was found. |

## Backups

Configuration and original autostart files were copied to:

`/var/backups/mint-privacy-20261119_043528`

## Pending audit and verification

- Verify that the two existing GOA session processes have exited after logout/login.
- Verify GeoClue remains masked and the demo-agent autostart override is effective after a new login.
- Complete the fwupd inspection. The previous diagnostic report is incomplete: it stopped at a permission error reading `/etc/fwupd/fwupd.conf`; configured remotes and fwupd settings were not inspected.

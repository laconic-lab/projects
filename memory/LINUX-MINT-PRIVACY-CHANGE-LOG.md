# Linux Mint — Privacy Change Log

## System and audit scope

- **OS:** Linux Mint 22 Cinnamon
- **Hardware:** Dell Precision M4800
- **Audit date:** 2026-11-19
- **Purpose:** Identify unsolicited data collection or external transmission without explicit user choice. Ordinary background services, local network discovery, printing, updates, and hardware support are not considered telemetry without supporting evidence.

## Changes made

### kerneloops
- Retained the package; disabled and stopped `kerneloops.service`.
- Configured `allow-submit = ask` and `allow-pass-on = no` in `/etc/kerneloops.conf`.
- Verified the service is disabled and inactive. The configuration values were reported as `ask` and `no`.
- **Evidence limitation:** A working permission prompt has not been verified. No successful report submission was established.

### GeoClue
- Retained the package; masked and stopped `geoclue.service`.
- Added a user autostart override at `~/.config/autostart/geoclue-demo-agent.desktop` with `Hidden=true`.
- Verified the service is masked and inactive and the override exists.
- **Pending:** Verify behaviour after a fresh login. `/etc/geoclue/geoclue.conf` was not changed.

### motd-news
- Disabled and stopped `motd-news.timer`.
- Verified the timer is disabled and inactive. The installed `/etc/update-motd.d/50-motd-news` contained only its shebang.
- Retained `base-files`, which owns that script.

### mintchat
- Removed `mintchat` version `1.8` with `apt-get remove`.
- No other package was removed. No purge or autoremove was performed; package state `rc` indicated residual configuration files.

### GNOME Online Accounts
- Removed `gnome-online-accounts` version `3.50.4-0ubuntu2` and `gnome-online-accounts-gtk` version `3.50.7+zara`.
- The removal simulation proposed only those two packages. No dependency on MintUpdate, APT, login, or essential system services was identified.
- Existing `goa-daemon` and `goa-identity-service` processes remained in the session from deleted executables after removal.
- Masked and stopped the user-level `gvfs-goa-volume-monitor.service`; verified it is masked and inactive. The package-owned D-Bus activation file and other GVFS components were left unchanged.
- **Pending:** Verify the old GOA processes have exited after logout/login.

## Retained components and findings

| Component | Finding / decision |
|---|---|
| mintreport | Retained. Startup entry was already disabled by the user; inspected upload actions require explicit user interaction. |
| MintUpdate and package update timers | Retained for normal update functionality. |
| `python3-apport`, `python3-problem-report` | Retained. Main `apport` package and `apport.service` were absent; no active reporting was established. |
| GVFS | Retained; only the GOA volume-monitor user service was masked. |
| Avahi | Retained. Observed mDNS activity was local-network discovery; no unsolicited telemetry transmission evidence was found. |
| CUPS and cups-browsed | Retained. CUPS listened only on loopback; observed browsing was local printer discovery. No unsolicited telemetry transmission evidence was found. |

## Backups

Original configuration and autostart files were copied to:

`/var/backups/mint-privacy-20261119_043528`

## Pending audit and verification

- Verify GOA session processes have exited after logout/login.
- Verify GeoClue remains masked and the demo-agent override is effective after a new login.
- Complete fwupd inspection. The previous report stopped at a permission error reading `/etc/fwupd/fwupd.conf`; configured remotes and fwupd settings were not inspected.

# Linux Mint — Privacy Change Log

## System and audit scope

- **OS:** Linux Mint 22 Cinnamon
- **Hardware:** Dell Precision M4800
- **Audit date:** 2026-11-19
- **Purpose:** Identify services and applications that collect user/device/usage information and transmit it externally without explicit user consent.
- **Boundary:** Ordinary background activity, local-network discovery, printing, software/firmware updates, and hardware support are not classified as telemetry without supporting evidence.
- **Status:** Audit and system changes are paused at the user's request. No further changes are authorized.

## Audit findings

The audit reviewed the following components. “No evidence found” means the checks performed did not establish unsolicited telemetry; it is not a claim that a component is incapable of network communication.

| Component | Evidence and assessment | Decision |
|---|---|---|
| `kerneloops` | The service was active/enabled before the change. Its configuration supported report submission and forwarding, but no successful external submission was established. A functioning consent prompt was not verified. | Service disabled; package retained. See changes below. |
| GeoClue | Provides location information to local applications. No evidence was established that the service itself sends unsolicited telemetry to an external vendor. | Package retained; service and demo-agent autostart disabled. This was a privacy precaution, not a confirmed telemetry mitigation. |
| `motd-news` | The timer was enabled, but the installed `50-motd-news` script contained only its shebang. No actual news retrieval or telemetry transmission was established. | Timer disabled. This may have been unnecessary given the inert script. |
| mintchat | Package was installed. The audit did not establish that it transmitted telemetry without consent. | Package removed as a privacy preference, not as a proven telemetry finding. |
| GNOME Online Accounts (GOA) | Optional online-account integration. No unsolicited telemetry transmission was established. Removing it also removes cloud-account integration functionality. | Packages removed as a privacy preference, not as a proven telemetry finding. |
| GVFS GOA volume monitor | A user-session integration component associated with GOA, not evidence of telemetry by itself. | User service masked after GOA removal; other GVFS components retained. |
| mintreport | Startup/upload behaviour was reviewed. The upload actions inspected required explicit user interaction; no automatic reporting was established. | Retained. |
| Apport | Main `apport` package and `apport.service` were absent. Python support packages were installed, but no active automatic reporter was established. The Python packages are retained. | Retained. |
| MintUpdate and APT timers | Update functionality and scheduled package maintenance were observed. No evidence established that these were unsolicited telemetry. | Retained. |
| Avahi | Observed mDNS traffic was local-network discovery/advertising, not external telemetry. | Retained. |
| CUPS and cups-browsed | CUPS listened on loopback; observed browsing was local printer discovery. No unsolicited external reporting was established. | Retained. |
| fwupd / LVFS | LVFS metadata refresh is firmware-update functionality. The enabled LVFS remote had automatic reports and automatic security reports disabled; the testing remote was disabled and automatic reports were disabled. The vendor-directory remote was local. No automatic telemetry/reporting was established. | Retained. No fwupd changes made. |
| Brave network connections | External connections were observed, but their purpose was not attributed to telemetry. | No change; insufficient evidence. |

## Changes made

### kerneloops

- Retained the package; disabled and stopped `kerneloops.service`.
- Set `allow-submit = ask` and `allow-pass-on = no` in `/etc/kerneloops.conf`.
- Verified the service was disabled and inactive and that the configuration values were reported as `ask` and `no`.
- **Limitation:** A working permission prompt was not verified. No successful report submission was established. The service change was precautionary rather than a response to proven transmission.

### GeoClue

- Retained the package; masked and stopped `geoclue.service`.
- Added `~/.config/autostart/geoclue-demo-agent.desktop` with `Hidden=true`.
- Verified the service was masked and inactive and the override existed.
- `/etc/geoclue/geoclue.conf` was not changed.
- **Limitation:** No unsolicited external telemetry by GeoClue was established. A fresh-login behaviour check was not completed.

### motd-news

- Disabled and stopped `motd-news.timer`.
- Verified the timer was disabled and inactive.
- The installed `/etc/update-motd.d/50-motd-news` contained only its shebang; `base-files` was retained.
- **Limitation:** No actual transmission was established; disabling the timer may not have been necessary.

### mintchat

- Removed `mintchat` version `1.8` using `apt-get remove`.
- No other package was removed. No purge or autoremove was performed; package state `rc` indicated residual configuration files.
- **Limitation:** Removal was a preference decision; unsolicited telemetry was not established.

### GNOME Online Accounts

- Removed `gnome-online-accounts` version `3.50.4-0ubuntu2` and `gnome-online-accounts-gtk` version `3.50.7+zara`.
- The removal simulation proposed only those two packages. No dependency on MintUpdate, APT, login, or essential system services was identified.
- Existing `goa-daemon` and `goa-identity-service` processes remained in the session from deleted executables immediately after removal.
- Masked and stopped the user-level `gvfs-goa-volume-monitor.service`; verified it was masked and inactive. The package-owned D-Bus activation file and other GVFS components were left unchanged.
- **Limitation:** Removal was a privacy preference, not a response to proven unsolicited telemetry. The old session processes were expected to end at logout/login, but that follow-up check was not completed.

## Backups

Original configuration and autostart files were copied to:

`/var/backups/mint-privacy-20261119_043528`

## Pause state and outstanding verification

The user chose to pause the privacy audit and all further system changes. No additional services or packages are to be disabled or removed unless separately approved.

If the audit is resumed, the only outstanding checks from changes already made are:

- Verify whether the old GOA session processes have exited after a fresh login.
- Verify GeoClue service/autostart behaviour after a fresh login.

No further fwupd inspection is outstanding: the available remote configuration and `fwupdmgr get-remotes` output were sufficient for the preliminary finding above. No fwupd setting was changed.

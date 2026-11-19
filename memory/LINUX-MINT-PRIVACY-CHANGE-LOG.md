# Linux Mint — Privacy and Background Component Change Log

## System
- **OS:** Linux Mint 22 Cinnamon
- **Hardware:** Dell Precision M4800
- **Date:** 2026-11-19

## 2026-11-19 — Initial privacy-related changes

### kerneloops
- **Decision:** Keep the permission-based submission policy while preventing third-party forwarding; disable the daemon itself.
- **Action:** Set `allow-submit = ask` and `allow-pass-on = no` in `/etc/kerneloops.conf`; disabled and stopped `kerneloops.service`.
- **Observation:** Service verified `disabled` and `inactive`. Configuration values are `ask` and `no`, respectively. The presence of a working permission prompt has not been verified.
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
- **Session processes:** The existing `goa-daemon` and `goa-identity-service` processes continued running from deleted executables after package removal. They are expected to disappear after logout/login.
- **GVFS integration:** `gvfs-goa-volume-monitor.service` is provided by the retained `gvfs-backends` package. The service was masked at user level and stopped; verification returned `masked` and `inactive`. The package-owned D-Bus activation file was left unchanged. Other GVFS components were retained.

## Retained components

| Component | Decision / status |
|---|---|
| mintreport | Retain. Startup entry was already disabled by the user. Inspected upload actions require explicit user interaction. |
| MintUpdate and package update timers | Retain. Required for normal update functionality. |
| Apport support libraries (`python3-apport`, `python3-problem-report`) | Retain and monitor. Main `apport` package and `apport.service` were absent during inventory. |
| kerneloops package | Still installed; service disabled and stopped; submission policy set to `ask`, third-party forwarding set to `no`. |
| GeoClue package | Still installed; its service is masked and stopped. |
| GVFS packages | Retain; only the GOA volume-monitor user service is masked. |
| base-files | Retain. |
| Avahi, CUPS, cups-browsed | Retain. Observed traffic is local mDNS/DNS-SD discovery and local printing; no telemetry transmission evidence was found. CUPS listens only on loopback. |

## Assistant error register — lessons to apply to every remaining audit

This register records mistakes and unsafe assumptions made during this audit. It is intended as a practical pre-flight checklist, not as evidence that every listed mistake caused a system failure.

| Error / incident | What was wrong or incomplete | Rule to prevent recurrence |
|---|---|---|
| fwupd inspection script stopped at `/etc/fwupd/fwupd.conf` | The script checked whether the file existed, but not whether it was readable. `sed` returned “Permission denied”; with `set -e` and `pipefail`, the grouped pipeline stopped there. Remote files, `fwupdmgr get-remotes`, and `get-settings` were never inspected. | Preflight every protected path for existence, type, and readability. Treat permission-denied as an explicit result and choose an approved read-only privilege path; do not let one expected access restriction silently terminate the whole audit. Mark incomplete sections clearly. |
| fwupd script used `tee` unnecessarily | A foreground `tee` pipeline was used for a finite diagnostic even though it added little value. This was not the asynchronous `exec > >(tee ...)` anti-pattern, and the available evidence does **not** establish that `tee` caused the terminal crash. | Do not add `tee` by habit. Choose the simplest safe output method. If a report is needed, capture output inside a separate script process or a scoped subshell, then display it after completion. Never redirect the interactive shell persistently. |
| `set -Eeuo pipefail` in a pasted interactive block | Shell options can affect the user's interactive shell after the block, and `errexit`/pipeline failure behaviour made a recoverable read-permission issue abort the report. | Put strict shell options inside a standalone script or an explicitly scoped subshell. Design expected non-zero results deliberately; do not use strict mode as a substitute for error handling. |
| Repeated `|| true` in the fwupd script | This suppressed failures without distinguishing an optional/missing item from a real diagnostic error. | Handle each expected condition explicitly. Preserve and report unexpected exit statuses; never hide errors merely to keep a script moving. |
| No completion marker or completeness summary in the fwupd report | The partial report ended at a permission error without a clear “incomplete” marker or a summary of skipped checks. | Every multi-section audit must report completed, skipped, and failed sections, and end with an explicit completion status. Never interpret a partial report as a completed audit. |
| Earlier kerneloops explanation overstated what configuration proved | A forwarding setting showed capability/policy, not proof that a report had actually been transmitted. This was later corrected; no successful submission evidence was established. | Distinguish configured capability, enabled policy, observed process/network activity, and confirmed successful transmission. Never claim an upload occurred without direct evidence. |
| Audit scope initially risked treating background/network activity as telemetry | Local mDNS/DNS-SD discovery and printing activity are functional LAN services, not evidence of unsolicited telemetry. | Investigate only evidence of unsolicited data collection or external transmission without explicit user choice. Do not classify a daemon as telemetry merely because it runs in the background or uses a network socket. |
| User-level GVFS GOA mask was briefly removed by an `unmask` command, then reapplied | The mask was temporarily undone before being restored and verified. This was a command-sequence mistake, not evidence of a package or D-Bus file change. | Before state-changing service commands, restate the exact intended operation and target. Afterward verify both `is-enabled` and `is-active`; do not chain opposite operations or assume the resulting state. |

### Mandatory pre-flight checklist for future diagnostic scripts
1. Confirm the exact audit question and keep the scope limited to unsolicited telemetry.
2. Identify execution context, privilege requirements, expected duration, output volume, and a safe stop method.
3. Check every file's existence, type, and read permissions before trying to read it.
4. Keep interactive commands and privilege prompts attached directly to the terminal; do not put them in pipelines, command substitutions, or timeout wrappers.
5. Avoid `tee` unless it materially helps. Never use persistent/asynchronous redirection on the interactive shell.
6. Scope strict shell options to a script process or subshell; preserve real exit statuses.
7. Handle optional/missing files and expected non-zero results explicitly; do not blanket-suppress errors.
8. Bound command output and runtime. Avoid unbounded journal, process, or network streams.
9. Print a completion summary listing successful, skipped, failed, and unrun checks.
10. Make no configuration or package changes during an inventory unless separately approved; preserve backups and verify every approved change.

## Backup
Configuration and original autostart files were copied to:

`/var/backups/mint-privacy-20261119_043528`

## Pending verification
- Verify that the two deleted GOA session processes have exited after logout/login.
- Verify GeoClue remains masked and the demo-agent autostart override is effective after a new login.
- Continue auditing other installed background components for external communication capability.
- Complete the fwupd inspection; the previous report is incomplete and did not inspect configured remotes or fwupd settings.

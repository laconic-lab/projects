# Windows Activation / Software Protection Platform (SPP) Investigation — Dell Precision M4800

**Status:** Open — diagnosis in progress; no successful reactivation  
**Last updated:** 2026-11-13  
**System:** Dell Precision M4800, Windows 11 Pro 25H2, build 26200.9974  
**Repository location:** `tmp/WINDOWS-ACTIVATION-SPP-INVESTIGATION.md`

> This is the canonical handoff and investigation log for the Windows activation incident. It is deliberately separate from the KB5132061 servicing audit. Update this document after each completed test, preserving the distinction between observed evidence, interpretation, and hypotheses.

## 1. Purpose and incident summary

Windows 11 Pro was activated before the November 2026 servicing incident. Following installation of cumulative update KB5132061 and reboot to build **26200.9974**, Windows entered Notification mode and reported that it was not activated.

The user reports that the original Windows 10 product key was legitimately used to activate Windows 10 in March 2025, followed by an upgrade to Windows 11. The user retried that original key through Settings → Activation → Change product key; the same `0x80070005` error occurred. Do not ask the user to repeat that operation.

The working hypothesis is that the underlying digital entitlement may still be valid, while the activation operation is failing due to an authorization, licensing-state, or related system issue. This is plausible but **not proven**. There is no evidence that the purchased entitlement has been revoked or lost.

### Current state

- Windows 11 Pro 25H2, build `26200.9974`.
- Windows is in **Notification** licensing state.
- `slmgr /xpr`: Notification mode.
- `SoftwareLicensingProduct`: Windows Professional, partial key `3V66T`, LicenseStatus `5`.
- `slmgr /dlv`: Retail channel; Notification Reason `0xC004F034`; SPP service version `10.0.26100.9974`.
- `3V66T` is the ending of the generic Windows Pro setup key. This does not prove that the user's purchased entitlement is absent. Retail channel / ProductKeyType Retail do not prove that the original purchased key is currently installed.
- TEST-35R added an explicit Network Service ACE to one ProfileList key (details below).
- TEST-36 performed one user-approved `/ato` attempt; it failed with `0x80070005`.
- TEST-38R found no Defender block attributable to activation.
- TEST-39 captured full Defender 5007 and SPP 8198 event details. It did not identify a Defender block of SPP.
- **Do not run another activation attempt until separately authorized.**

## 2. Hardware, operating system, and incident timeline

| Item | Verified information |
|---|---|
| Hardware | Dell Precision M4800 |
| Operating system | Windows 11 Pro 25H2 |
| Pre-update build | 26200.9818 |
| Post-KB5132061 build | 26200.9974 |
| Update | KB5132061, November 2026 security update |
| First documented activation failure | 2026-11-12 20:31:08 |
| Current licensing state | Notification |
| Prior activation | User confirms Windows 11 was legitimately activated before this incident |

The KB5132061 installation and servicing investigation is tracked separately in [the M4800 KB5132061 audit](https://github.com/laconic-lab/projects/blob/main/tmp/KB5132061_for_M4800.md). Do not conflate the servicing issue with the activation issue: no causal link has been established.

## 3. Safety rules and authorization boundary

These rules apply to all future work on the physical M4800:

1. **Diagnosis first.** Prefer read-only inspection before any system change.
2. Explain the purpose, risk, exact scope, and rollback before proposing a change.
3. Use exact PowerShell command blocks and log results to the shared drive `R:\`.
4. New result files must use `Set-Content -Encoding UTF8`; appends must use `Add-Content -Encoding UTF8`.
5. Use sequential filenames such as `R:\results.activation-spp-040.txt`.
6. Do not expose or request product keys, Installation IDs, Activation IDs, passwords, or other secrets.
7. Do not run `slmgr /upk`, additional `/ipk` operations, product-key retries, licensing-store resets, rearm, or reinstall operations.
8. Do not stop or disable Defender, Windows Firewall, or Security Center services speculatively.
9. Do not change service security descriptors, DCOM permissions, registry ACLs, or licensing files without evidence and explicit user approval.
10. No VM snapshots, backups, or disk-copy suggestions: this is the physical M4800.
11. The user approved the specific TEST-35R ProfileList ACL correction and one TEST-36 `/ato` attempt. Those approvals do not authorize unrelated changes or another activation attempt.
12. The user said to proceed beyond read-only if needed. This is permission to propose justified targeted actions, not blanket approval to weaken security or make arbitrary changes.

### Known approved change

TEST-35R added an explicit, non-inheriting Full Control ACE for `NT AUTHORITY\NETWORK SERVICE` to:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-20`

The user explicitly approved this one change. It remains in place pending diagnosis. Do not automatically roll it back.

## 4. Key evidence and error codes

### Activation and licensing evidence

- Security-SPP Event 8198 at 2026-11-12 20:31:08: `0x80070005`, trigger TimerEvent.
- Further Event 8198 records on 2026-11-13:
  - NetworkAvailable triggers sometimes report `0x8007139F`.
  - UserLogon and NetworkAvailable triggers also report `0x80070005`.
- Event 1003 at 2026-11-13 05:32:23 recorded licensing errors including `0xC004E003`, `0xC004F034`, and `0xC004F009`.
- Event 8230 showed LastConsumptionReason `0xC004F034`, LastNotificationId `ReActivateRequired`, LicenseState Notification, and partial key `3V66T`.
- TEST-36 manual `/ato` output: `Error: 0x80070005 Access denied: the requested action requires elevated privileges`.
- TEST-36 process exit code: `-2147024891` (0x80070005).
- After TEST-36, Windows remained LicenseStatus 5 / Notification.

These errors establish activation failure, not the identity of the denied resource or proof of entitlement loss.

### SPP service

- `sppsvc` is configured Automatic and runs as `NT AUTHORITY\NetworkService`.
- It was observed stopped in one inventory, with ExitCode 0. This may be normal trigger/on-demand behavior; it is not by itself evidence of service failure.
- `sc.exe sdshow sppsvc` was collected; no service descriptor modification was made.
- Host service and executable must be treated separately: a stopped service at an observation instant does not prove a broken service.

### KMS / volume activation

KMS is largely ruled out by the evidence collected:

- Retail channel reported.
- No KMS host or DNS suffix override found.
- No `_vlmcs._tcp` SRV record found.
- No KMS registry override found.

Do not repeat this branch without new evidence.

## 5. Test register

The detailed raw command outputs are retained in the individual result files on `R:\` and, where published, in the repository. The entries below summarize the verified findings available in this handoff. Earlier tests 01–27 are intentionally summarized at the branch level because their complete individual transcripts are not all present in the current handoff context; do not invent missing test details.

### Tests 01–27 — initial activation, licensing, update, and security triage

The initial investigation established the post-update Windows activation failure, Notification state, Retail channel, partial generic setup key ending `3V66T`, and recurring SPP errors. It also examined the licensing state and activation history, system servicing context, and possible KMS configuration. The following conclusions are retained:

- Windows was activated before the KB5132061 reboot, according to the user.
- The original Windows 10 key retry through Settings failed with `0x80070005`; do not repeat.
- No evidence demonstrates that the user's digital entitlement was revoked.
- KMS is unsupported by the collected configuration evidence.
- SPP errors include `0x80070005`, `0x8007139F`, `0xC004E003`, `0xC004F034`, and `0xC004F009`.
- No SPP service, licensing-store, product-key, or DCOM repair was performed during this initial branch.

### TEST-28 — ProfileList Network Service ACL

Inspected:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-20`

Observed that the key did not contain an explicit `NETWORK SERVICE` (`S-1-5-20`) ACE. Existing ACEs included Users Read, Administrators Full Control, SYSTEM Full Control, Creator Owner inherit-only Full Control, and application-package read permissions.

This was a genuine ACL discrepancy worth investigating, but it did not prove causation.

### TEST-29 — Network Service user hive and PnP service

- Initial PowerShell `Get-Acl` attempt against `HKU\S-1-5-20` produced blank/inconclusive output.
- Plug-and-Play (`plugplay`) service configuration was collected.
- `plugplay` was Demand Start, LocalSystem, hosted by `svchost.exe -k DcomLaunch -p`.
- No PnP service changes were made.

### TEST-30 — direct registry hive query and policy inventory

- Direct `reg.exe query HKU\S-1-5-20 /s` succeeded: the hive exists and is populated.
- `gpresult /scope computer /v` showed a standalone workstation with no applied GPOs; System Services, Registry, and File System policy areas were N/A.
- No policy changes were made.

### TEST-31 / TEST-32 — PowerShell registry provider discrepancy

- PowerShell `Get-Acl` failed to resolve registry paths, including the HKU path.
- TEST-32 established that PowerShell's registry drives included HKCU and HKLM, but no HKU drive.
- Direct `reg.exe` queries succeeded; HKLM ProfileList key existed.
- This was a PowerShell provider/path access limitation, not evidence that the registry keys were missing.

### TEST-33 — direct .NET registry ACL reads

Direct .NET RegistryKey APIs successfully read both ACLs.

**HKLM ProfileList child key:** no Network Service ACE.

**HKU Network Service hive** (`HKEY_USERS\S-1-5-20`):

- Owner Administrators; group SYSTEM.
- Protected DACL.
- Network Service has Full Control (`KA`) with object/container inheritance.
- SYSTEM and Administrators also have Full Control.

Conclusion: the loaded Network Service user hive already had Full Control. The missing ACE was confined to the ProfileList branch.

### TEST-34 — ProfileList parent and Network Service profile directory

- The ProfileList parent ACL was inspected. It had no Network Service ACE.
- The child key inherited the parent ACEs; this was not merely a child-only inheritance break.
- `C:\Windows\ServiceProfiles\NetworkService` exists.
- Network Service has Full Control on that profile directory; SYSTEM and Administrators also have Full Control.
- No changes were made.

Conclusion: the discrepancy was specifically the absence of a Network Service ACE on the ProfileList parent/child path, not on the user hive or profile directory.

### TEST-35 — initial approved ACL correction attempt (not applied)

- Registry export succeeded to `R:\backup.activation-spp-035-profilelist.reg`.
- Initial script stopped before writing due to an incorrect PowerShell enum type name.
- Correct enum identified as `[System.Security.AccessControl.RegistryRights]`.
- No ACL change occurred during the initial failed attempt.

### TEST-35R — approved ProfileList ACL correction (applied and verified)

Backups:

- `R:\backup.activation-spp-035-profilelist.reg`
- `R:\backup.activation-spp-035-profilelist-sddl.txt`

Before modifying, the corrected script verified the existing SDDL matched TEST-33.

Added ACE:

`(A;;KA;;;NS)`

Resulting SDDL:

`O:SYG:SYD:AI(A;;KA;;;NS)(A;CIID;KR;;;BU)(A;CIID;KA;;;BA)(A;CIID;KA;;;SY)(A;CIIOID;KA;;;CO)(A;CIID;KR;;;AC)(A;CIID;KR;;;S-1-15-3-1024-1065365936-1281604716-3511738428-1654721687-432734479-3232135806-4053264122-3456934681)`

Verification established:

- New ACE is explicit and non-inheriting.
- All six original ACEs remained present and unchanged.
- Owner remains SYSTEM.
- Parent ACL unchanged.
- HKU hive and Network Service profile directory unchanged.

The user approved this targeted change. Keep it in place pending diagnosis; no rollback has been requested.

### TEST-36 — one approved manual activation attempt

User approved one `/ato` attempt after TEST-35R.

Command:

```powershell
cscript.exe //nologo "$env:windir\system32\slmgr.vbs" /ato
```

Before attempt: Windows Pro, Retail channel, LicenseStatus 5, partial key `3V66T`, Notification.

Start time: 2026-11-13 14:29:49.8046644 +01:00.

Output:

`Error: 0x80070005 Access denied: the requested action requires elevated privileges`

Process exit code: `-2147024891` (`0x80070005`).

After attempt: still LicenseStatus 5 / Notification.

No service restart, reboot, key change, licensing-store reset, or other system change occurred.

Interpretation: the ProfileList ACE correction did **not** resolve the failure on this attempt. It remains unknown whether TEST-36 was executed in the same elevated PowerShell window later examined by TEST-37.

### TEST-37 — current token elevation

Output included:

- Identity: `UNKNOWN\Laco`
- Administrator role: True
- Integrity SID extraction field: blank (script limitation)
- `whoami /groups` showed High Mandatory Level, SID `S-1-16-12288`.

Conclusion: the TEST-37 shell was high integrity/elevated. This does not establish that TEST-36 used the same shell. **This is still an unanswered question.**

### TEST-38 — Defender diagnostic script error (not a valid test)

The first TEST-38 script contained a PowerShell parser error: an empty pipeline element after a closing brace. The helper function was never defined; later calls failed. Only a heading and completion marker were written to `R:\results.activation-spp-038.txt`.

No Defender setting, service, activation state, or permission was changed. Do not treat TEST-38 as evidence.

### TEST-38R — Defender / activation interference inspection

The corrected read-only diagnostic completed. It examined Defender service state, protection status, detections, Defender Operational events, SPP events, and activation executable signatures.

**Defender services:** `WinDefend`, `WdNisSvc`, `SecurityHealthService`, and `mpssvc` were all Running.

**Protection status:** antivirus, real-time protection, behavior monitoring, IOAV protection, and NIS enabled; `AMRunningMode = Normal`. No recent threat detections returned.

**Defender events:** 1123/1127 events identified `takeown.exe`, DISM/DismHost, and Microsoft PC Manager. None identified `sppsvc.exe`, `slui.exe`, or `cscript.exe`. These events do not establish an activation block.

**SPP events:** repeated Event 1003 records around TEST-36; no corresponding Defender block identified.

**Executable checks:** `sppsvc.exe`, `slui.exe`, and `cscript.exe` existed and had valid Microsoft signatures. Reported file version was `10.0.26100.8457`; earlier SPP service version was `10.0.26100.9974`. This difference alone does not prove corruption.

**Decision:** do not pause or disable Defender. No evidence justified weakening protection.

### TEST-39 — full Defender Event 5007 and SPP Event 8198 details

Raw output is committed separately:

[TEST-39 full event output](https://github.com/laconic-lab/projects/blob/main/tmp/results.activation-spp-039.txt)

The query covered 2026-11-13 05:00 through approximately 14:37 local time.

Key observations from the full event messages:

- Several 5007 events at 05:05–05:10 reflect Defender service initialization/start-state transitions, diagnostic initialization progress, configuration hash changes, and feature-control values. These do not identify SPP binaries or licensing objects.
- The 5007 event at 13:13:01 added an AllowedApplications entry for Microsoft PC Manager's `MSPCManagerCore.exe` under Controlled Folder Access. It does not concern SPP.
- A 5007 event at 13:54:50 changed the Defender CoreService configuration hash. A hash change alone does not reveal which effective protection setting changed.
- The full SPP Event 8198 records confirm:
  - 05:05:36–05:05:39: `0x8007139F`, NetworkAvailable.
  - 05:07:33 and 05:07:40: `0x8007139F`, NetworkAvailable.
  - 05:07:56: `0x80070005`, UserLogon.
  - 13:13:27, 13:13:30, 13:13:31: `0x80070005`, NetworkAvailable.
  - 13:44:32 and 13:44:39: `0x8007139F`, NetworkAvailable.
  - 13:50:50: `0x80070005`, UserLogon.
- The 13:44 SPP failures do not coincide with a logged Defender event identifying an SPP component as blocked.
- The Event 5007 messages are configuration-change notifications, not proof of malicious activity or activation interference.

**TEST-39 conclusion:** no Defender-to-SPP blocking relationship has been demonstrated. Do not disable Defender or change its configuration based on these events.

## 6. Separate investigation threads — avoid false causal links

### Controlled Folder Access and UUP/DISM activity

Previously observed CFA events:

- 1127: ADK DISM on D:
- 1127: UUP DismHost on D:
- 1127: another DismHost on D:
- 1123: `takeown.exe` blocked from modifying Documents
- 1127: Windows DISM on C:
- 1127: Microsoft PC Manager

The earliest of these was 2026-11-11 23:34, before the first documented activation failure on 2026-11-12 20:31. The events identify unrelated processes and do not establish an SPP cause.

### UUP ACL changes

The user ran `takeown.exe /F "D:\W10UIuup" /R /D Y`, recursively changing ownership to the user. Subsequent `icacls` operations affected that UUP working tree, with 871 failures reported in the recursive grant/reset operations. One protected manifest required a targeted grant before deletion.

These actions were on `D:\W10UIuup`, not the ProfileList key or SPP objects. No causal link to activation has been demonstrated.

### TEMP/TMP and RAM disk

- Windows TEMP/TMP paths were temporarily restored to defaults during servicing troubleshooting; `R:\Temp` was later re-enabled.
- `R:` is a 4 GB NTFS RAM disk.
- No evidence currently links TEMP/TMP or the RAM disk to the activation failure.

### DISM mount points

`DISM /Cleanup-Mountpoints` completed successfully and cleaned stale mount points. `D:\MountUUP` was later absent and the WIMMount Mounted Images registry key was empty. Do not repeat cleanup or edit WIMMount registry state without new evidence.

## 7. Hypotheses and current assessment

| Hypothesis | Assessment | Reason |
|---|---|---|
| Purchased digital entitlement was lost/revoked | Unproven; do not assume | Windows was activated before incident; current errors do not establish entitlement revocation |
| Network Service lacked ProfileList access | Genuine ACL discrepancy; correction applied; not sufficient | TEST-35R applied ACE; TEST-36 still failed |
| Defender blocked SPP | Not supported by current evidence | TEST-38R/39 found no SPP process or object in Defender blocks |
| UAC / non-elevated command | Still unresolved for TEST-36 | TEST-37 shell was high integrity, but same-shell relationship unknown |
| SPP service or its security descriptor | Not yet established | Service was observed stopped once; no descriptor change; more targeted inspection needed |
| DCOM SELF permission issue | Less supported | Workstation is not domain joined; no Event 8229 found in prior 7-day query |
| KMS configuration | Largely ruled out | Retail channel and no KMS host/record/override found |
| UUP/DISM/CFA incident caused activation failure | No demonstrated link | Different paths/processes; chronology alone is insufficient |
| Corrupt or mismatched activation executables | Not established | Files exist and signatures are valid; version difference alone is insufficient |

## 8. Next actions and decision gates

### Immediate question still pending

Confirm whether TEST-36 `/ato` and TEST-37 token-elevation check were run in the **same PowerShell window**.

- If yes: the `/ato` elevation error occurred in a high-integrity shell. Investigate the authorization path of SPP and the activation caller rather than repeating basic UAC checks.
- If no: TEST-37 proves only that the later shell was elevated; TEST-36's token state remains unknown.

### Recommended next diagnostic branch

Proceed with read-only inspection of the SPP service security descriptor, service configuration, relevant executable and licensing-object ACLs, and the exact process/service identities involved. Do not change any descriptor or permission during inventory.

Use evidence to decide whether a narrowly scoped change is justified. Do not jump to DCOM or Defender changes without an event or access-denied trace pointing there.

### Activation retry gate

No further `/ato` attempt is authorized by the earlier one-time approval. A new attempt requires:
1. A reasoned diagnostic basis.
2. A statement of what the test will and will not change.
3. Explicit user approval.

## 9. Evidence and artifact index

| Artifact | Purpose |
|---|---|
| [TEST-39 raw event output](https://github.com/laconic-lab/projects/blob/main/tmp/results.activation-spp-039.txt) | Full Defender 5007 and SPP 8198 messages and XML |
| `R:\results.activation-spp-038.txt` | Failed TEST-38 script output; not valid evidence |
| `R:\results.activation-spp-038R.txt` | Corrected Defender diagnostic output |
| `R:\backup.activation-spp-035-profilelist.reg` | Registry export before approved ACL correction |
| `R:\backup.activation-spp-035-profilelist-sddl.txt` | Original ProfileList key SDDL |
| [KB5132061 M4800 audit](https://github.com/laconic-lab/projects/blob/main/tmp/KB5132061_for_M4800.md) | Separate Windows update/servicing investigation |

Raw result files are evidence. This document is the interpretation and handoff. When a new test is completed, add its exact command, timestamp, output artifact, result, interpretation, and any change/rollback details here before moving to another test.

## 10. Handoff instructions for a new chat

Start by reading this document in full. Treat it as the canonical state of the activation investigation as of 2026-11-13.

Do not restart completed branches, repeat the original key retry, repeat TEST-35R, repeat the one approved TEST-36 activation attempt, or disable Defender speculatively.

First obtain the pending answer about whether TEST-36 and TEST-37 used the same PowerShell window. Then continue with targeted read-only SPP authorization diagnostics.

Preserve the user's central concern: Windows was legitimately activated before the update, and the evidence so far does not prove that the digital entitlement has disappeared.

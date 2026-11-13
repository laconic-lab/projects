# Windows Activation / Software Protection Platform (SPP) Investigation — Dell Precision M4800

**Status:** Open — diagnosis in progress; no successful reactivation  
**Last updated:** 2026-11-13 (TEST-41 added; diagnostic sequence authorization clarified)  
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
12. The user has now explicitly approved continuing the planned diagnostic test sequence without asking for separate approval before each test. Proceed with justified, bounded diagnostic tests and update this document after every completed test. This standing approval covers diagnostics; it does **not** authorize speculative or unrelated system changes, security weakening, licensing-store modification, or another activation attempt. Any proposed state-changing operation must still be evidence-based, narrowly scoped, explained with rollback, and separately approved.

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

Continue the diagnostic sequence without requesting one-test-at-a-time approval. The same-window question remains useful but is not a blocker; treat TEST-36 token elevation as unconfirmed unless the user later clarifies. Continue with targeted read-only SPP authorization diagnostics. Update this canonical document after every completed test.

Preserve the user's central concern: Windows was legitimately activated before the update, and the evidence so far does not prove that the digital entitlement has disappeared.


### TEST-40 — SPP service identity, configuration, descriptor, and executable ACL

**Timestamp:** 2026-11-13 14:43:45 +01:00  
**Raw log:** `R:\results.activation-spp-040.txt`  
**Scope:** Read-only inventory. No service, registry, ACL, executable, licensing, or activation changes were made.

**Current shell token**
- `whoami /all` showed the user in the local Administrators group and High Mandatory Level SID `S-1-16-12288`.
- This establishes that the TEST-40 shell was high-integrity/elevated. It does not establish whether TEST-36 used the same PowerShell window.

**SPP service configuration**
- `sppsvc`: `WIN32_OWN_PROCESS`, Automatic (Delayed Start), normal error control.
- Binary: `C:\Windows\System32\sppsvc.exe`.
- Dependency: `RpcSs`.
- Service account: `NT AUTHORITY\NetworkService`.
- Service was STOPPED at the time of inspection; Win32 exit code 0, service exit code 0, PID 0. This single observation does not establish a fault; SPP may be trigger/on-demand activated.

**Service security and identity**
- `sc.exe sdshow sppsvc` returned:
  `D:(A;;CCDCLCSWRPWPDTLOCRRC;;;SY)(A;;CCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPLOCRRC;;;IU)(A;;LCRPLO;;;AC)(A;;CCLCSWRPLOCRRC;;;SU)(A;;LCRP;;;AU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)`
- `sc.exe qsidtype sppsvc`: SERVICE_SID_TYPE UNRESTRICTED.
- `sc.exe showsid sppsvc`: service SID active, `S-1-5-80-123231216-2592883651-3715271367-3753151631-4175906628`.
- Required privileges: `SeAuditPrivilege`, `SeChangeNotifyPrivilege`, `SeCreateGlobalPrivilege`, `SeImpersonatePrivilege`.
- No service descriptor or privilege changes were made.

**Executable**
- `C:\Windows\System32\sppsvc.exe` exists.
- ACL:
  - `NT SERVICE\TrustedInstaller:(F)`
  - `BUILTIN\Administrateurs:(RX)`
  - `AUTORITE NT\Système:(RX)`
  - `BUILTIN\Utilisateurs:(RX)`
  - All Application Packages and All Restricted Application Packages: `(RX)`
- `icacls` reported one file successfully processed and zero failures.
- The signature and CIM formatting sections were piped through `Format-List` inside a captured script block; the output was emitted as PowerShell formatting records, so their detailed property values did not survive in the saved/pasted report. Do not infer signature status or CIM details from this output. Correct the capture method in a later focused test if needed.

**Service registry configuration**
- `HKLM\SYSTEM\CurrentControlSet\Services\sppsvc` query succeeded.
- `ObjectName=NT AUTHORITY\NetworkService`, `Start=2`, `DelayedAutoStart=1`, `ServiceSidType=1`, `LaunchProtected=1`.
- `RequiredPrivileges` matches the four privileges reported by `sc.exe qprivs`.
- `FailureActions` and two TriggerInfo entries are present.
- The service Security binary value was read but not decoded or modified.

**Interpretation**
- TEST-40 confirms SPP is configured to run as Network Service, with an active unrestricted service SID and the listed required privileges.
- The service descriptor was readable and no obvious missing Network Service service-control ACE was identified from this inspection. The descriptor alone does not establish whether the service can access every licensing object it needs.
- The executable ACL grants read/execute to Administrators, SYSTEM, Users, and application package groups; no obvious executable ACL denial is demonstrated.
- The stopped service state at one instant is not evidence of failure on its own.
- `LaunchProtected=1` is recorded as an important configuration value; preserve it. Do not attempt to disable service protection or alter service configuration.
- No evidence from TEST-40 justifies changing the service descriptor, service account, startup type, registry ACLs, executable ACLs, or Defender.

**Next diagnostic direction**
- Continue read-only inspection of the specific licensing/Software Protection registry and file objects referenced by SPP, and correct the TEST-40 formatting capture in a narrowly scoped follow-up if those details are needed.
- Keep the unresolved question: were TEST-36 and TEST-37 run in the same PowerShell window?
- No further `/ato` attempt is authorized.


### TEST-41 — SPP licensing store and registry ACL inventory

**Timestamp:** 2026-11-13 14:44:54 +01:00  
**Raw log:** `R:\results.activation-spp-041.txt`  
**Scope:** Read-only ACL inventory. No file contents or licensing values were read; no changes were made.

**Filesystem ACL findings**
- `C:\Windows\System32\spp`: Network Service has explicit Full Control with container/object inheritance.
- `C:\Windows\System32\spp\store`: Network Service has explicit Full Control and an inherited Full Control ACE.
- `C:\Windows\System32\spp\store\2.0`: Network Service has explicit Full Control; SYSTEM and Administrators also have Full Control. The active `NT SERVICE\sppsvc` service SID has explicit Full Control with inheritance to children.
- `tokens.dat` (15,874,066 bytes): inherited Full Control for Network Service, SYSTEM, Administrators, and the sppsvc service SID; BUILTIN Users have Read/Synchronize.
- `data.dat` (29,920 bytes): owner is Network Service; inherited Full Control for Network Service, SYSTEM, Administrators, and sppsvc; BUILTIN Users have Read/Synchronize.
- Network Service profile root and its `AppData\Roaming\Microsoft` ancestors each grant Network Service explicit Full Control.
- `C:\Windows\ServiceProfiles\NetworkService\AppData\Roaming\Microsoft\SoftwareProtectionPlatform` was not present. This alone is not evidence of a fault; the primary SPP store was found under System32.

**Registry ACL findings**
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform` was opened for read-permissions and its security descriptor was retrieved.
- Owner is TrustedInstaller. Descriptor includes SYSTEM and Administrators Full Control, BUILTIN Users read access, and an ACE for the active sppsvc service SID with mask `DC`. Do not infer broader rights from the abbreviated mask; no changes were made.
- The attempted `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL` read returned `KEY NOT PRESENT OR NOT OPENABLE`. The script deliberately collapsed null-open and inaccessible conditions, so it does not establish that the key is absent. A later test would need to distinguish those outcomes using a separate read-only existence/open diagnostic.

**Interpretation**
- The primary SPP filesystem store and both inspected licensing data files grant Network Service Full Control. The sppsvc service SID is also explicitly granted Full Control on the 2.0 directory and the two data files.
- TEST-41 therefore does not support a simple missing-Network-Service-ACL explanation for the activation failure.
- No ACL repairs, ownership changes, registry edits, or licensing-store resets are justified by these results.
- The missing per-profile SoftwareProtectionPlatform directory is not treated as an error without evidence that this build/configuration requires it.
- The SL key result remains inconclusive because the test did not distinguish absence from access failure.

**Next diagnostic direction**
- Move away from speculative ACL repair. If continuing the authorization investigation, identify the exact SPP activation caller and correlate its security context with the recorded 8198 failures; use read-only event/process/service evidence.
- The TEST-40 CIM/signature formatting capture issue remains a data-quality limitation, not evidence of a failure.
- Keep unresolved whether TEST-36 and TEST-37 were run in the same PowerShell window.
- No further `/ato` attempt is authorized.


### Investigation workflow clarification — 2026-11-13

The user explicitly requested that the investigation proceed without asking for separate approval before each diagnostic test. This standing authorization applies to the planned, justified diagnostic sequence, including read-only tests. It does not grant blanket permission for system changes. Any permission, service, registry, Defender, licensing-store, or activation-state modification remains subject to a specific evidence-based proposal and separate approval. The canonical document must be updated and verified after every completed test.


### TEST-42 — SPP registry subtree ACL inventory

**Timestamp:** 2026-11-13 14:47:20 +01:00  
**Raw log:** `R:\results.activation-spp-042.txt`  
**Scope:** Read-only recursive registry ACL inventory in Registry64 and Registry32. No registry values were modified.

**Findings**
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform` opened successfully in both registry views.
- The root key owner is TrustedInstaller. Its ACL includes SYSTEM and Administrators Full Control, BUILTIN Users read access, and service-specific ACEs.
- Registry64 recursive inventory processed 45 keys; Registry32 processed 5 keys.
- The `Activation`, `GenuineApps`, `Plugins`, `ReferralData`, `Setup`, and related subkeys show consistent ACL patterns. Several are owned by SYSTEM; others by TrustedInstaller.
- The active sppsvc service SID observed in TEST-40 is present in the SPP root and in relevant subkey ACLs. The root ACE uses mask `DC`; do not interpret this abbreviated mask as Full Control.
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL` returned “KEY NOT FOUND OR NOT OPENABLE” in both views. As with TEST-41, the test does not distinguish a missing key from an open/access failure.

**Interpretation**
- TEST-42 does not reveal an obvious blanket SPP registry ACL failure. The service-specific SID is represented in the tree, and the inspected child ACLs are broadly consistent.
- This is not proof that every operation has the required access: the exact activation operation, access mask, and caller identity have not yet been correlated with an access denial.
- The differing subkey counts between Registry64 and Registry32 are not by themselves evidence of damage.
- No registry ACL repair or other change is justified by this inventory.

**Next diagnostic direction**
- Correlate SPP service identity, service SID configuration, and actual service/runtime behavior. Do not infer that an ACE is defective solely because its abbreviated rights mask looks narrower than Full Control.
- Continue to distinguish absent registry keys from keys that exist but cannot be opened.
- No further `/ato` attempt is authorized.

### TEST-43 — SPP service identity and executable security

**Timestamp:** 2026-11-13 14:48:41 +01:00  
**Raw log:** `R:\results.activation-spp-043.txt`  
**Scope:** Read-only service configuration, descriptor/SID queries, process state, executable metadata, ACL, and signature. No service, registry, ACL, executable, or activation changes were made.

**Findings**
- CIM reports service `sppsvc` (Software Protection) as:
  - State: STOPPED
  - StartMode: Auto
  - StartName: `NT AUTHORITY\NetworkService`
  - Path: `C:\WINDOWS\system32\sppsvc.exe`
  - Service type: Own Process
  - PID: 0
  - Status: OK
- `sc.exe qc` output in the captured transcript was incomplete: only DisplayName, Dependencies, and ServiceStartName appeared. The output does not preserve the full start-type/binary details.
- `sc.exe qsidtype`, `sc.exe showsid`, and `sc.exe sdshow` produced no visible output in this transcript. Therefore TEST-43 did **not** establish the service SID type, service SID value, or service security descriptor. Their blank output must not be interpreted as absent configuration.
- No SPP service process was running at the instant of inspection, so no live process token or runtime identity could be collected.
- `C:\Windows\System32\sppsvc.exe` exists; size 4,871,608 bytes; creation and last-write times 2026-11-11 05:06:56–05:06:57 UTC.
- File version: `10.0.26100.8457`; description: Microsoft Software Protection Platform Service.
- File owner: TrustedInstaller.
- File ACL SDDL:
  `O:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464G:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464D:P(A;;0x1200a9;;;SY)(A;;0x1200a9;;;BA)(A;;0x1200a9;;;BU)(A;;FA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;0x1200a9;;;AC)(A;;0x1200a9;;;S-1-15-2-2)`
- The file grants Full Access to its own service SID; SYSTEM, Administrators, Users, and the listed application package groups have the displayed `0x1200a9` access mask.
- Authenticode signature: Valid; signer CN=Microsoft Windows, O=Microsoft Corporation, L=Redmond, S=Washington, C=US.

**Interpretation**
- TEST-43 confirms SPP is configured to run as Network Service, matching the identity involved in the earlier ProfileList investigation.
- The STOPPED state with Automatic start is noteworthy but not conclusive. A stopped service at one observation time does not prove failure; service triggers and idle behavior must be considered.
- The executable is Microsoft-signed and its ACL explicitly grants Full Access to the SPP service SID. This does not support a simple executable ACL denial.
- The file version `10.0.26100.8457` differs from the previously reported SPP service version `10.0.26100.9974`. Record this as a version discrepancy for targeted component/version provenance checking, not as proof of corruption. TEST-38R also reported this executable version.
- The service descriptor and SID-type queries are missing from the captured evidence. TEST-40 had previously captured these successfully; its findings remain the stronger evidence for service SID configuration and descriptor.
- No evidence justifies changing the service startup type, service account, service descriptor, executable ACL, or file.

**Next diagnostic direction**
- Re-run only the failed descriptor/SID capture using explicit output capture and exit-code reporting, rather than repeating the whole inventory.
- Investigate why the SPP service is stopped and whether a controlled service start produces relevant events or access failures. A start-only experiment may change service runtime state and should be logged with before/after state and event correlation; it must not be combined with an activation retry.
- Investigate the executable version/build provenance against the installed component servicing state before considering file repair.
- No further `/ato` attempt is authorized.


### TEST-44 — Controlled SPP service start

**Timestamp:** 2026-11-13 14:50:00 +01:00  
**Raw log:** `R:\results.activation-spp-044.txt`  
**Scope:** Attempted to start `sppsvc`, observe its state and collect event records. No activation attempt, service configuration change, permission change, registry edit, or licensing-store modification was performed.

**Findings**
- Before test: `sppsvc` was STOPPED; StartMode Auto; account `NT AUTHORITY\NetworkService`; PID 0; exit codes 0.
- `Start-Service -Name sppsvc` returned SUCCESS.
- After test: service was RUNNING; StartMode remained Auto; account remained Network Service; PID 9368; exit codes 0.
- CIM process query returned PID 9368 and parent PID 1076, but did not return an executable path or command line. The service process was nevertheless associated with the running service PID.
- The Security-SPP event query failed with `Get-WinEvent : The parameter is incorrect` (EventLogException). The transcript then stopped in the finally block; the subsequent Service Control Manager event query was not executed. Therefore TEST-44 contains no valid event-correlation result.

**Interpretation**
- The service can be started successfully through the Service Control Manager and reaches RUNNING state under its configured Network Service account. This argues against a simple inability to launch the service or a general service-control denial.
- It does not establish that the service can complete activation, access every licensing object, or successfully process an activation request.
- The earlier STOPPED observation was not, by itself, evidence of a persistent service failure.
- No further service changes are justified by this test. Leave the service in its observed running state unless Windows stops it naturally; do not change its startup type or account.
- The event-query error is a test instrumentation failure, not evidence of an SPP failure.

**Next diagnostic direction**
- First capture the current service state and recent SPP/System events using a corrected event query. Avoid repeating the service start because it has already succeeded.
- Since the service is now running, use the active service process/PID to inspect its process identity and relevant runtime state. If pursuing access-denied attribution, collect targeted audit/ETW evidence rather than broad ACL inventories.
- Do not combine event collection with an activation retry. No further `/ato` attempt is authorized.


### TEST-45 — SPP runtime state and event correlation

**Timestamp:** 2026-11-13 14:51:56 +01:00  
**Raw log:** `R:\results.activation-spp-045.txt`  
**Scope:** Read-only inspection of current service state, live process details, and recent Application/System events. No service, registry, ACL, licensing, or activation changes were made.

**Findings**
- At 14:51:56, approximately 117 seconds after TEST-44's successful start, `sppsvc` was STOPPED again.
- Configuration remained Auto and `NT AUTHORITY\NetworkService`; PID 0 and both reported exit codes were 0.
- No live SPP process was available for process-owner or token inspection.
- Security-SPP events since the TEST-44 start:
  - 14:50:00, Event 900, Information: “The Software Protection service is starting. Parameters:<explicit>”.
  - 14:50:00, Event 16394, Information: “Offline downlevel migration succeeded.”
  - 14:50:47, Event 16384, Information: “Successfully scheduled Software Protection service for re-start at 2026-11-14T12:50:47Z. Reason: RulesEngine.”
- The System log query returned no matching Service Control Manager events in the selected window.
- The TEST-45 Application query worked using `Get-WinEvent -LogName Application -MaxEvents 1500` followed by filtering. This avoids the parameter error encountered in TEST-44's FilterHashtable query.

**Interpretation**
- TEST-44's start was real and successful, but the service did not remain running. It had stopped again by TEST-45.
- This is consistent with an on-demand/triggered service completing its startup work and returning to a stopped state; it is not, by itself, proof of a crash or service failure. Both service exit codes were zero, and no SCM failure event was found in the queried window.
- Event 16394 reports successful offline downlevel migration. This is an informational SPP event; its presence alone does not establish that current Windows activation is successful or that the licensing store is repaired.
- Event 16384 records a RulesEngine-scheduled restart. The message's scheduled timestamp is preserved verbatim; do not infer a local-time conversion or causation from it.
- Because the process had already stopped, TEST-45 could not inspect its runtime token. The exact access-denied caller and target object remain unidentified.
- No evidence justifies changing the service startup type, service account, service descriptor, or service permissions.

**Next diagnostic direction**
- The service's start-and-stop behavior is not currently the leading explanation for `0x80070005`. Avoid repeatedly starting it.
- Correlate the original Security-SPP 8198 activation failures with the exact Windows activation client/caller and any corresponding diagnostic or access-denied events. The next test should focus on the activation failure's event XML and process/service context, without issuing another activation request.
- Preserve the distinction between the service's successful informational startup/migration events and the separate failed activation events.
- No further `/ato` attempt is authorized.


### TEST-46 — Security-SPP Event 8198 XML extraction

**Timestamp:** 2026-11-13 14:53:18 +01:00  
**Raw log:** `R:\results.activation-spp-046.txt`  
**Scope:** Read-only retrieval of Security-SPP Application events from 2026-11-12 20:00 onward, including complete XML for Event 8198 and selected related events.

**Execution / transcript note**
- The event collection and XML output completed through the printed `===== END TEST-46 =====` marker.
- The closing `finally { Stop-Transcript }` block was pasted/executed separately after the preceding `try { ... }` block had already closed. PowerShell therefore treated `finally` as an unknown command and reported `CommandNotFoundException`.
- This is a console-pasting / block-structure issue, not an error in the event query. The main output was captured. The transcript was not cleanly closed by the script; if the same console transcript remains active, close it with a standalone `Stop-Transcript` command.
- The query returned 13 Event 8198 records.

**Event 8198 XML findings**

| Local time (+01:00) | Record ID | HRESULT | Trigger | Event XML ProcessID |
|---|---:|---|---|---:|
| 2026-11-12 20:31:08.742 | 108821 | `0x80070005` | TimerEvent | 12200 |
| 2026-11-13 05:05:36.940 | 108948 | `0x8007139F` | NetworkAvailable | 5976 |
| 2026-11-13 05:05:38.328 | 108950 | `0x8007139F` | NetworkAvailable | 5128 |
| 2026-11-13 05:05:39.478 | 108952 | `0x8007139F` | NetworkAvailable | 1764 |
| 2026-11-13 05:07:33.755 | 108979 | `0x8007139F` | NetworkAvailable | 4324 |
| 2026-11-13 05:07:40.623 | 108981 | `0x8007139F` | NetworkAvailable | 4344 |
| 2026-11-13 05:07:56.920 | 108989 | `0x80070005` | UserLogon; SessionId=1 | 7664 |
| 2026-11-13 13:13:27.954 | 109186 | `0x80070005` | NetworkAvailable | 14012 |
| 2026-11-13 13:13:30.054 | 109189 | `0x80070005` | NetworkAvailable | 13488 |
| 2026-11-13 13:13:31.067 | 109192 | `0x80070005` | NetworkAvailable | 13696 |
| 2026-11-13 13:44:32.147 | 111458 | `0x8007139F` | NetworkAvailable | 7116 |
| 2026-11-13 13:44:39.374 | 111460 | `0x8007139F` | NetworkAvailable | 7592 |
| 2026-11-13 13:50:50.316 | 111479 | `0x80070005` | UserLogon; SessionId=1 | 7140 |

**Common XML fields**
- Provider: `Microsoft-Windows-Security-SPP`.
- Event ID: 8198, Error.
- RuleId: `3482d82e-ca2c-4e1f-8864-da0267b484b2`.
- Action: `AutoActivate`.
- AppId: `55c92734-d682-4d71-983e-d6ec3f16059f`.
- SkuId: `4de7cb65-cdf1-4de9-8ae8-e3cce27b9f2c`.
- NotificationInterval: 1440.
- Event XML has an empty Correlation element and ThreadID 0 for these records.
- The ProcessID is the event's recorded execution context. By itself it does not identify the initiating interactive user process or the protected object that denied access; historical PID-to-process mapping is not available from this event alone.

**Interpretation**
- The first recorded failure is explicitly an automated `AutoActivate` operation triggered by `TimerEvent`, returning `0x80070005`.
- Subsequent failures use the same RuleId, Action, AppId and SkuId. Both `0x80070005` and `0x8007139F` occur, with NetworkAvailable and UserLogon triggers.
- This confirms that the failures are generated by the SPP automatic activation rule, rather than proving a manual activation-client failure. It does not identify the denied resource, ACL, RPC call, or caller responsible.
- The Event 8198 XML contains no useful ActivityID or caller identity. The changing ProcessID values cannot safely be attributed to a specific executable without contemporaneous process telemetry.
- The log's event inventory and selected event XML were collected successfully despite the transcript-finally syntax issue. The output is large because the script also emitted many related Event 1003 records and two-minute neighboring SPP event XML; those records do not add a caller identity to Event 8198.
- No state changes or activation attempts occurred.

**Next diagnostic direction**
- Do not repeat the broad XML dump. The useful next evidence is historical process creation / process lifetime telemetry for the Event 8198 ProcessIDs, especially around the first 20:31:08 failure and later 13:13 / 13:50 failures.
- First inspect whether Security process-creation auditing (Event 4688) or Sysmon process-creation logging was enabled and retained for those timestamps. This is read-only. If no such telemetry exists, the old PIDs cannot be reliably reconstructed after the fact; use a narrowly scoped, forward-looking diagnostic capture only if justified.
- No `/ato` retry is authorized.



### TEST-47 — Historical process telemetry check (partially invalid; script defects)

**Timestamp:** 2026-11-13 14:56:00–14:57:21 +01:00  
**Raw log:** `R:\results.activation-spp-047.txt`  
**Scope:** Read-only inspection of process-creation auditing, Security Event 4688, and Sysmon process-creation records around the 13 Event 8198 timestamps/PIDs from TEST-46.

**Execution findings**
- The Security log is enabled, contains 21,034 records, has a 20 MiB maximum size, and uses Circular logging.
- The `auditpol /get /subcategory:"Process Creation"` invocation failed with `0x00000057` (“The parameter is incorrect”). Therefore this test did **not** establish whether Process Creation auditing was enabled. The command syntax/localized subcategory handling needs correction; do not interpret this as auditing being disabled.
- The first 4688 query window (2026-11-12 20:30–20:32) returned no 4688 events.
- The matching loops used `$pid` as a loop variable. PowerShell variable names are case-insensitive, and `$PID` is a built-in read-only automatic variable. Every attempted assignment therefore raised `SessionStateUnauthorizedAccessException` / “Cannot overwrite variable PID because it is read-only or constant.”
- This variable collision generated the very large volume of repeated errors in the transcript and prevented reliable PID matching in the remaining windows. It is a defect in the diagnostic script, not a Windows activation or Security-log error.
- Because the matching loops failed, TEST-47 cannot provide a valid conclusion about matching Event 4688 records in the remaining windows or Sysmon Event 1 records. Any Sysmon section affected by the same `$pid` variable collision is invalid.
- The transcript did close normally with `Stop-Transcript`; no system settings or audit policy were changed.

**Interpretation**
- TEST-47 is **partially invalid**, not a negative finding about process telemetry.
- The Security log's enabled/circular state is established, but its 20 MiB capacity and 21,034 records do not tell us whether the relevant older process-creation events were retained.
- No historical PID-to-process mapping has yet been recovered. The one valid observation—no 4688 events returned in the first two-minute window—must not be generalized to the other windows or treated as proof that process auditing was disabled.
- No activation attempt, service change, audit-policy change, or permission change occurred.

**Corrective approach**
- Do not rerun the broad, error-producing script. A corrected, narrowly scoped follow-up should:
  1. Query Process Creation auditing using a verified subcategory identifier/name and capture the command's exit code.
  2. Query the relevant Security 4688 records without assigning to `$PID`; use a differently named loop variable (for example, `$targetProcessId`) or parse event XML fields directly.
  3. Check whether the Sysmon Operational channel exists and is enabled before querying Event 1.
  4. Keep output compact: report event counts and only matching records, not every event XML in the time windows.
- If the relevant historical telemetry was not enabled or has rolled out of the circular log, those old PIDs cannot be reconstructed retroactively. A forward-looking trace may then be considered, but it should be tightly scoped and separately explained before enabling any audit setting.
- No `/ato` retry is authorized.



### TEST-48 — Corrected historical process correlation (Sysmon confirms automatic activation client)

**Timestamp:** 2026-11-13 15:00:05–15:00:24 +01:00  
**Raw log:** `R:\\results.activation-spp-048.txt`  
**Scope:** Read-only inspection of Process Creation audit policy, Security Event 4688, and Sysmon Event 1 in the five timestamp windows associated with the 13 Security-SPP Event 8198 records from TEST-46.

**Execution findings**
- Process Creation auditing queried successfully using subcategory GUID `{0CCE922B-69AE-11D9-BED3-505054503030}`; `auditpol.exe` exit code 0. The current setting is **No Auditing** (French display: “Création du processus — No Auditing”).
- Security log remains enabled, with 21,034 records, 20 MiB maximum size, Circular mode.
- Security Event 4688 queries:
  - 2026-11-12 20:30–20:32: no events.
  - 2026-11-13 05:04:30–05:09: 26 events queried; no target PID match was printed.
  - 2026-11-13 13:12:30–13:14: no events.
  - 2026-11-13 13:43:30–13:45:30: 13 events queried; no target PID match was printed.
  - 2026-11-13 13:49:50–13:52: no events.
- Sysmon Operational channel exists and is enabled, with 38,905 records, Circular mode.
- Sysmon Event 1 records correlate **all 13 Event 8198 ProcessIDs** with newly created `slui.exe` processes at or immediately before the corresponding activation error times. The matching activation-client processes show:
  - Image: `C:\\Windows\\System32\\slui.exe`.
  - Parent image: `C:\\Windows\\System32\\SppExtComObj.Exe`.
  - User: `NT AUTHORITY\\NETWORK SERVICE` (localized in the transcript as `AUTORITE NT\\SERVICE RÉSEAU`).
  - Command line: `SLUI.exe` with the same RuleId, `Action=AutoActivate`, AppId and SkuId recorded in TEST-46.
- Representative exact correlation:
  - First failure: Event 8198 at 2026-11-12 20:31:08.742, PID 12200; Sysmon Event 1 created `slui.exe` PID 12200 at 20:31:07, parent `SppExtComObj.Exe`, Network Service.
  - 2026-11-13 05:05–05:08: PIDs 5976, 5128, 1764, 4324, 4344 and 7664 map to `slui.exe` creations immediately preceding the corresponding Event 8198 records.
  - 2026-11-13 13:13: PIDs 14012, 13488 and 13696 map to `slui.exe` creations at 13:13:25–13:13:29.
  - 2026-11-13 13:44: PIDs 7116 and 7592 map to `slui.exe` creations at 13:44:31 and 13:44:38.
  - 2026-11-13 13:50: PID 7140 maps to `slui.exe` created at 13:50:48.
- Some PIDs also appear in unrelated Sysmon process-creation records at other times in the queried windows (for example, Google Updater, Broadcom Host Control, taskhostw, mscorsvw, and svchost). Process IDs are reusable; these unrelated entries are not the activation process for the corresponding Event 8198. The time-aligned `slui.exe` Event 1 records are the relevant matches.
- The script's final standalone `else` was pasted after its matching `if` block had already completed, producing a harmless “else is not recognized” error. Sysmon channel detection and all five Sysmon query windows had already completed. The transcript was closed normally with `Stop-Transcript`.

**Interpretation**
- This is the first reliable historical process-level attribution of the automatic activation failures. Security-SPP Event 8198's ProcessID is, in these cases, the PID of the `slui.exe` automatic activation client.
- The activation client is launched by `SppExtComObj.Exe` and runs as Network Service. This is consistent across the first failure and all later Event 8198 records correlated by Sysmon.
- The repeated `0x80070005` failures therefore occur during an automatic activation operation executed by `slui.exe` in the Network Service security context. This makes the effective Network Service / process execution path more relevant than the interactive administrator token tested in TEST-37.
- This does **not** identify the object, API, RPC endpoint, registry value, file, service operation, or network operation that returns Access Denied. It also does not prove that the ProfileList ACL discrepancy corrected in TEST-35R caused the failure; the later activation attempt still failed.
- The current Process Creation audit policy is No Auditing. The absence of 4688 records in three windows is consistent with that current policy, but does not establish what the policy was at earlier timestamps. The 4688 records in two windows were not matches for the target activation PIDs.
- Sysmon provided the necessary historical process creation evidence. Its Operational log is circular, so retention remains finite.
- No audit policy, Sysmon configuration, service, ACL, registry, licensing store, or activation state was changed. No activation attempt occurred.

**Next diagnostic direction**
- Do not enable broad Security process auditing merely to repeat what Sysmon has already established.
- Next inspect the existing Sysmon configuration and targeted Event 3 network-connection / Event 5 process-termination records for the exact activation `slui.exe` processes, using their Sysmon ProcessGuid rather than PID alone. This can establish whether the client made network connections and its lifetime, without changing configuration.
- If Event 3 was not enabled, report that limitation rather than enabling it speculatively. Network connection telemetry may clarify connectivity but will not, by itself, identify a file or registry access denial.
- The priority remains identifying the exact operation behind `0x80070005`; no ACL repair, Defender disablement, licensing-store reset, or service security change is justified by TEST-48.
- No `/ato` retry is authorized.


### TEST-49 — Sysmon process GUID, network-connection and termination correlation

**Timestamp:** 2026-11-13 15:02:25–15:02:47 +01:00  
**Raw log:** `R:\\results.activation-spp-049.txt`  
**Scope:** Read-only correlation of the 13 activation `slui.exe` processes identified in TEST-48, using Sysmon ProcessGuid to query Event 3 (network connections) and Event 5 (process termination).

**Process creation / identity**
- All 13 target PIDs from TEST-46/TEST-48 were matched to exact Sysmon Event 1 records for `C:\\Windows\\System32\\slui.exe`.
- Each record supplied a unique ProcessGuid. This avoids PID-reuse ambiguity when correlating subsequent events.
- All 13 ran as `NT AUTHORITY\\NETWORK SERVICE`, with parent image `C:\\Windows\\System32\\SppExtComObj.Exe`.
- Creation timestamps matched the corresponding activation attempts:
  - PID 12200: 2026-11-12 20:31:07.
  - PIDs 5976, 5128, 1764: 2026-11-13 05:05:36–05:05:38.
  - PIDs 4324, 4344, 7664: 2026-11-13 05:07:32–05:07:54.
  - PIDs 14012, 13488, 13696: 2026-11-13 13:13:25–13:13:29.
  - PIDs 7116, 7592: 2026-11-13 13:44:31–13:44:38.
  - PID 7140: 2026-11-13 13:50:48.

**Sysmon Event 3 — network connections**
- Queried all five corresponding time windows for Event 3 and matched records by the 13 unique ProcessGuids.
- No Event 3 records were returned in any of the five windows.
- This means no matching Sysmon network-connection telemetry is available in those windows. It does **not** prove that the processes made no network connections: Event 3 may not be configured to record them, or the events may not have been retained. The test did not inspect or change Sysmon configuration.

**Sysmon Event 5 — process termination**
- Matching Event 5 records were found for all 13 activation `slui.exe` ProcessGuids:
  - PID 12200 terminated at 20:31:08 on 2026-11-12.
  - PIDs 5976, 5128, 1764 terminated at 05:05:36–05:05:39 on 2026-11-13.
  - PIDs 4324, 4344, 7664 terminated at 05:07:33–05:07:56.
  - PIDs 14012, 13488, 13696 terminated at 13:13:27–13:13:31.
  - PIDs 7116, 7592 terminated at 13:44:32–13:44:39.
  - PID 7140 terminated at 13:50:50.
- These termination records align closely with the Security-SPP Event 8198 failure timestamps already extracted in TEST-46. For the first failure, the activation process was created at 20:31:07, Event 8198 was recorded at 20:31:08.742, and the process termination event was recorded at 20:31:08.
- The Event 5 records establish short process lifetimes and confirm that the correlated activation clients exited. They do not by themselves establish whether each process exited normally or identify the internal API/object that returned the error.

**Interpretation**
- TEST-49 completes the process-lifetime correlation for all 13 Event 8198 process IDs: each is a distinct, short-lived `slui.exe` automatic-activation client running as Network Service and launched by `SppExtComObj.Exe`.
- The first failure's creation, Security-SPP failure, and termination occur within approximately one second. The later attempts show the same short-lived pattern.
- No matching Event 3 network telemetry was found. Network connectivity or endpoint reachability therefore remains unproven; do not interpret the zero results as proof that no network activity occurred.
- Combined with TEST-36, the interactive elevated administrator's manual `/ato` attempt returned `0x80070005`; TEST-48/49 independently show that automatic activation attempts execute under Network Service. The next investigation should focus on the operation performed inside the Network Service activation path, not repeat administrator-token checks.
- No service, audit policy, Sysmon configuration, ACL, registry, Defender, licensing-store, or activation state was changed. No activation attempt occurred.

**Next diagnostic direction**
- Inspect the existing Sysmon configuration to determine whether Event 3 network-connection logging is enabled and whether exclusions apply to `slui.exe` or `SppExtComObj.Exe`. This is read-only; do not alter the Sysmon configuration merely to obtain network events.
- Then prioritize targeted evidence for the actual Access Denied operation in the SPP activation path (for example, existing relevant SPP/COM/RPC/operational diagnostics). Avoid broad tracing or enabling new audit categories until the likely resource or API is narrowed.
- Do not repeat `/ato`; no new activation attempt is authorized.


### TEST-50 — Sysmon configuration inspection (incomplete; executable-path indexing defect)

**Timestamp:** 2026-11-13 15:04:02 +01:00  
**Raw log:** R:\\results.activation-spp-050.txt  
**Scope:** Read-only inspection of the Sysmon service, executable, active configuration and recent Event 16 / Event 4 history.

**Successful findings**
- Sysmon service is present and Running:
  - Service name: Sysmon
  - StartMode: Automatic
  - Account: LocalSystem
  - PID: 4848
  - Image path: C:\\WINDOWS\\system32\\sysmon.exe
- The executable exists at that path, file/product version 10.0.26100.8457, Authenticode signature Valid, signer Microsoft Windows.

**Execution defect / incomplete sections**
- Executable discovery produced the path string, but subsequent indexing treated the scalar string as a character array: $candidates[0] yielded only C, not the full path.
- The attempted command therefore invoked C and failed with “The term 'C' is not recognized”.
- The outer catch ran, so the script stopped before querying Sysmon Event 16 and Event 4.
- The script's finally block was pasted separately after the try/catch block had already completed, producing “finally is not recognized”. Transcript closure was therefore not confirmed by this output.
- No Sysmon configuration dump was obtained. No Event 16 or Event 4 query was executed.

**Interpretation**
- Service identity, executable path, version and Microsoft signature are established.
- The active Sysmon configuration, including whether Event 3 NetworkConnect is enabled or filtered, remains unknown.
- TEST-50 is incomplete, not a negative finding about Sysmon network telemetry.
- No Sysmon configuration, service state, audit policy, ACL, registry, Defender, licensing store or activation state was changed. No activation attempt occurred.

**Corrective next step**
- Close any still-active transcript in the current PowerShell session with Stop-Transcript if PowerShell reports one is running.
- Re-run only the missing read-only configuration and event-history queries using the exact path already established: C:\\WINDOWS\\system32\\sysmon.exe. Do not use array indexing or executable discovery again.
- Execute the entire corrected script as one block so try/catch/finally remains structurally intact.
- No /ato retry is authorized.


### TEST-50R — Corrected Sysmon configuration command and event-history queries

**Timestamp:** 2026-11-13 15:05:19–15:05:20 +01:00  
**Raw log:** R:\\results.activation-spp-050R.txt  
**Scope:** Read-only invocation of Sysmon's configuration-display command and retrieval of recent Event 16 / Event 4 records.

**Results**
- Executed the exact verified binary: `C:\\WINDOWS\\system32\\sysmon.exe` with argument `-c`.
- Process exit code: 0. No configuration text was emitted into the PowerShell transcript despite `2>&1`; therefore the active configuration contents were not captured and must not be inferred from the exit code.
- Sysmon Event 16 (ServiceConfigurationChange): 0 records returned by the query (latest 30 requested).
- Sysmon Event 4 (service state): 5 records returned:
  - 2026-11-13 13:44:21 local — State Started; version 10.0.26100.8457; schema 4.91.
  - 2026-11-13 05:07:23 local — State Started; same version/schema.
  - 2026-11-13 05:05:30 local — State Started; same version/schema.
  - 2026-11-12 01:57:06 local — State Started; same version/schema.
  - 2026-11-11 17:56:24 local — State Started; same version/schema.
- Transcript closed normally.

**Interpretation**
- The Event 16 query found no retained configuration-change records in the requested latest-30 query. This does not establish that Sysmon's configuration never changed; older records may be outside retention, or no such event may have been logged.
- Event 4 records show Sysmon service start events at 05:05:30, 05:07:23 and 13:44:21, shortly before the corresponding activation-client bursts seen in TEST-48/49. These timestamps are temporal correlation only; they do not establish that Sysmon restarts caused activation failures or altered its event filters.
- TEST-49's lack of Event 3 matches remains unexplained because the active configuration contents were not captured. A zero exit code with no emitted configuration text is not sufficient to conclude whether Event 3 NetworkConnect is enabled.
- No service, configuration, audit policy, ACL, registry, Defender, licensing store or activation state was changed. No activation attempt occurred.

**Next diagnostic direction**
- Inspect the Sysmon configuration source read-only (the service's active configuration is represented by Sysmon's configuration state/registry data) and establish the exact Sysmon command-line behavior/version before drawing conclusions from the silent `-c` invocation.
- Avoid installing, updating, reconfiguring or restarting Sysmon. No /ato retry.


### TEST-51 — Sysmon driver registry configuration inventory

**Timestamp:** 2026-11-13 15:06:13 +01:00  
**Raw log:** R:\\results.activation-spp-051.txt  
**Scope:** Read-only inventory of Sysmon service/driver registry configuration. Binary values were not modified or decoded.

**Results**
- Sysmon user-mode service remains Running, Automatic, LocalSystem, image `C:\\WINDOWS\\system32\\sysmon.exe`.
- Driver service key `HKLM\\SYSTEM\\CurrentControlSet\\Services\\SysmonDrv` exists:
  - ImagePath: `system32\\drivers\\sysmondrv.sys`
  - Start: 0
  - Type: 1
  - DisplayName: `@%systemroot%\\system32\\drivers\\sysmondrv.sys,-1001`
- Driver Parameters key exists and contains:
  - `CheckRevocation`: Binary, length 1, SHA-256 `4BF5122F344554C53BDE2EBB8CD2B7E3D1600AD631C385A5D7CCE23C7785459A`
  - `DnsLookup`: Binary, length 1, same SHA-256.
  - `ConfigFile`: String, literal data `"C:\\WINDOWS\\system32\\sysmon.exe" -i`
  - `ConfigHash`: String, empty.
- Only Sysmon and SysmonDrv service keys were listed under Services.
- Transcript output shows the script's `finally` block was again pasted separately after the try/catch had already completed, so PowerShell reported “finally is not recognized”. The transcript end marker was not captured in the posted output; this is a logging/script-pasting issue, not a registry query failure.

**Interpretation / limitations**
- The registry confirms the Sysmon driver and Parameters key are present. The one-byte binary settings were intentionally not decoded; their SHA-256 alone does not establish their semantic values.
- `ConfigFile` contains a command-like string referencing `sysmon.exe -i`, while `ConfigHash` is empty. This is not sufficient to conclude that this is the currently active XML configuration, that no XML configuration exists, or that Event 3 is disabled. It may represent install/configuration provenance or another internal value; interpretation requires version-specific authoritative documentation or corroborating evidence.
- The active configuration and Event 3 NetworkConnect filtering therefore remain unresolved. Do not infer a default configuration or assume all events are enabled.
- No registry, service, driver, Sysmon configuration, audit policy, ACL, Defender, licensing store or activation state was changed. No activation attempt occurred.

**Next diagnostic direction**
- Before further inspection, establish the documented meaning of these Sysmon version 10.0.26100.8457 Parameters values and determine whether the active configuration can be obtained through a supported read-only interface.
- No registry edits, Sysmon reconfiguration/restart, driver changes or /ato retry.


### TEST-51R — Microsoft documentation interpretation of Sysmon Parameters and missing Event 3

**Research date:** 2026-11-13  
**Sources:** Microsoft Learn Sysmon usage/configuration documentation.

- Microsoft documents `CheckRevocation` and `DnsLookup` as Boolean global configuration entries. Their documented defaults are True. `DnsLookup` controls reverse-DNS enrichment for network events; it does not enable NetworkConnect event generation.
- The one-byte registry values for both entries have SHA-256 `4BF5122F344554C53BDE2EBB8CD2B7E3D1600AD631C385A5D7CCE23C7785459A`, which is consistent with a single byte `0x01`; the original TEST-51 deliberately did not decode it. Do not use these values as evidence that NetworkConnect is enabled.
- Microsoft documents the default Sysmon installation command `sysmon -accepteula -i` as installing with default settings and explicitly describes that default as having no network monitoring. The Parameters `ConfigFile` string (`"C:\\WINDOWS\\system32\\sysmon.exe" -i`) and empty `ConfigHash` are consistent with a default/no-XML-config installation, but the exact internal meaning of these registry values is not independently documented by the sources consulted.
- This provides a strong explanation for TEST-49's absence of Event 3 NetworkConnect records: network monitoring may simply not have been configured. It is not evidence that the activation processes made no network connections.
- The configuration dump command's zero exit code with no captured text remains unexplained; the documented command should dump the active configuration. Do not treat it as a successful configuration capture.
- No Sysmon configuration change is justified for this historical investigation: enabling Event 3 now cannot recover past network connections, and modifying Sysmon would add unrelated system state changes.

**Sources**
- Microsoft Learn, Sysmon command reference: `-c` dumps current configuration when no configuration file is supplied; default install and command examples. https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sysmon
- Microsoft Learn, Sysmon usage: default install example and note that default installation has no network monitoring; global `CheckRevocation` and `DnsLookup` configuration entries. https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon
- Microsoft Learn, Sysmon configuration files: global entries do not select event types; event types must be enabled/filtered under EventFiltering. https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-configuration-files

**Disposition**
- Sysmon process-creation telemetry remains valid for the TEST-48/49 process attribution.
- Missing Event 3 is not a gap that should be filled by changing Sysmon during this incident review.
- Return focus to the SPP activation operation and existing Windows telemetry. No /ato retry.


### TEST-52 — Windows Security, DCOM and service-event correlation

**Timestamp:** 2026-11-13 15:08:05–15:08:07 +01:00  
**Raw log:** R:\\results.activation-spp-052.txt  
**Scope:** Read-only event queries around six activation windows, plus an attempted current audit-policy inventory.

**Results**
- The transcript showed no visible output from `auditpol.exe /get /category:*`; no exit code was captured. Therefore the current audit policy was not successfully documented by this test.
- No matching events were returned in these windows:
  - First failure: 2026-11-12 20:31:00–20:31:20.
  - Nov 13 05:05:25–05:05:55.
  - For each, the query returned “No events were found that match the specified selection criteria” for the selected System, Application and Security event IDs.
- Nov 13 05:07:20–05:08:05:
  - System Event 10016 at 05:07:47: DistributedCOM reports Local Activation permission not granted to `NT AUTHORITY\\NETWORK SERVICE` (S-1-5-20), CLSID `{9EA82395-E31B-41CA-8DF7-EC1CEE7194DF}`, APPID `{2ED83BAA-B2FD-43B1-99BF-E6149C622692}`, LocalHost/LRPC.
  - Two additional Event 10016 records at 05:07:55 refer to Local Service (S-1-5-19), CLSID `{6B3B8D23-FA8D-40B9-8DBD-B950333E2C52}`, APPID `{4839DDB7-58C2-48F5-8283-E1D1807D0D7D}`.
- Nov 13 13:13:15–13:13:45:
  - Service Control Manager Event 7023 at 13:13:27 and 13:13:32: Windows Search terminated with “Access is denied”.
  - Event 7034 at the same timestamps reports unexpected termination; cumulative counts 22 and 23.
- Nov 13 13:44:20–13:44:55:
  - DistributedCOM Event 10016 at 13:44:20 again reports Local Activation denied for Network Service (S-1-5-20), CLSID `{9EA82395-E31B-41CA-8DF7-EC1CEE7194DF}`, APPID `{2ED83BAA-B2FD-43B1-99BF-E6149C622692}`.
- Nov 13 13:50:40–13:51:05:
  - DistributedCOM Event 10016 at 13:50:47 twice reports Local Service (S-1-5-19), CLSID `{6B3B8D23-FA8D-40B9-8DBD-B950333E2C52}`, APPID `{4839DDB7-58C2-48F5-8283-E1D1807D0D7D}`.
  - Windows Search Event 7023 at 13:50:54 reports “Access is denied”; Event 7031 reports unexpected termination and a scheduled restart in 30 seconds.

**Correlation and interpretation**
- The Network Service DCOM 10016 events at 05:07:47 and 13:44:20 occur inside/adjacent to the automatic activation bursts previously attributed to `slui.exe` under Network Service in TEST-48/49. This is a significant lead, but it is not yet proof that the denied COM activation belongs to the SPP activation path or caused Event 8198. The CLSID/APPID must be resolved to its registered COM server and correlated with the exact event XML and process context before any conclusion.
- The Local Service DCOM events use a different identity and different CLSID/APPID; do not conflate them with the Network Service events.
- Windows Search access-denied crashes occur during the 13:13 and 13:50 windows, but no evidence links Windows Search to the activation process. Treat them as a separate service issue unless later evidence connects them.
- No matching Security 4656/4663/4658 or WFP 5152/5156/5157 records were returned. Because current audit policy was not captured and historical policy is unknown, absence of these records does not prove no object-access or network filtering denial occurred.
- The first failure and 05:05 burst had no matching events for the selected IDs in the queried windows.
- No DCOM permissions, registry values, audit policy, services, ACLs, Defender, licensing store or activation state were changed. No activation attempt occurred.

**Next diagnostic direction**
- Resolve the Network Service CLSID/APPID `{9EA82395-E31B-41CA-8DF7-EC1CEE7194DF}` / `{2ED83BAA-B2FD-43B1-99BF-E6149C622692}` and the separate Local Service CLSID/APPID from registry metadata, including AppID LocalService/RunAs and registered server paths.
- Read the exact XML/data fields for the two Network Service Event 10016 records and compare with Sysmon process creation/termination timestamps.
- Do not modify DCOM launch/access permissions or attempt a permission repair based solely on Event 10016.


### TEST-53 — Resolve DCOM CLSID/APPID registrations

**Timestamp:** 2026-11-13 15:09:01 +01:00  
**Raw log:** R:\\results.activation-spp-053.txt  
**Scope:** Read-only resolution of the Network Service and Local Service DCOM registrations and exact XML for the two Network Service Event 10016 records.

**Network Service DCOM registration**
- CLSID `{9EA82395-E31B-41CA-8DF7-EC1CEE7194DF}` resolves to **WaaSProtectedSettingsProvider**.
- APPID `{2ED83BAA-B2FD-43B1-99BF-E6149C622692}` resolves to **WaaSMedicSvc**.
- APPID registration has `LocalService = WaaSMedicSvc` and a binary `LaunchPermission` value (104 bytes; SHA-256 `9EE74A635598D1937840AF1FDC763BC5238C5949770FF1F0AE2905FCFCD060F2`). No `AccessPermission` or `Configuration` value was present.
- The CLSID key contained only its default name and AppID mapping; this query did not identify an in-process or local-server executable path.

**Local Service DCOM registration**
- CLSID `{6B3B8D23-FA8D-40B9-8DBD-B950333E2C52}` resolves to **ShellServiceHost**.
- APPID `{4839DDB7-58C2-48F5-8283-E1D1807D0D7D}` also resolves to **ShellServiceHost**.
- APPID registration has `RunAs = Interactive User` and a binary `LaunchPermission` value (360 bytes; SHA-256 `BE223FC163FFFB858C6D3D0FB72FD3A5B470291AA0E88BEEB18B3F25F1D459C4`). No `AccessPermission` or `Configuration` value was present.
- This is a separate COM registration from the Network Service/WaaSMedicSvc event and is not currently tied to SPP.

**Exact Event 10016 XML**
- Record 125167: 2026-11-13 05:07:47.085 local time; DCOM Event 10016; denied Local Activation for Network Service (S-1-5-20), CLSID WaaSProtectedSettingsProvider, APPID WaaSMedicSvc; LocalHost/LRPC.
- Record 125360: 2026-11-13 13:44:20.381 local time; same identity, CLSID, APPID and denial.
- Both records have DCOM provider execution PID 1368. That is the process hosting/reporting the DCOM event, not evidence that PID 1368 is the caller or the denied COM server. The XML has no caller image or client process PID. Both records' Security UserID is S-1-5-20.

**Interpretation**
- The Network Service DCOM lead resolves to the Windows Update Medic / WaaS Medic service family, not directly to the Software Protection Platform. The name alone does not prove a causal relationship to activation.
- The events' close timing to activation bursts remains noteworthy, but there is no evidence yet that `slui.exe` requested this COM class, that WaaSMedicSvc was the operation returning `0x80070005`, or that the DCOM denial caused Security-SPP Event 8198.
- The binary LaunchPermission was only measured for length/hash; it was not decoded, changed, or declared incorrect. An Event 10016 does not by itself justify editing DCOM permissions.
- The Local Service/ShellServiceHost events remain a distinct issue.
- No registry values, DCOM permissions, services, audit policy, ACLs, Defender, licensing store or activation state were changed. No activation attempt occurred.
- The pasted `finally` block was entered separately and produced a PowerShell command-not-found error; the test's substantive read-only queries had completed and the transcript output ended with TEST-53 COMPLETE. This is a shell-block handling issue, not a Windows failure.

**Next diagnostic direction**
- Inspect the WaaSMedicSvc service configuration, executable/service-host identity and relevant service events; inspect the CLSID/AppID registration's full merged registry view only if needed.
- Correlate WaaSMedicSvc activity and process identity with the Sysmon process timeline. Do not modify DCOM permissions or infer SPP causation from temporal proximity alone.

### TEST-54 — WaaSMedicSvc runtime and process timeline

**Timestamp:** 2026-11-13 15:09:49–15:11:12 +01:00  
**Raw log:** R:\\results.activation-spp-054.txt  
**Scope:** Read-only service configuration, current runtime state, System event windows, and Sysmon process-create/terminate records.

**Service configuration observed**
- CIM reported WaaSMedicSvc **Stopped**, PID 0, exit codes 0. CIM returned StartMode Unknown, no account or image path; this is incomplete service metadata, not proof the service is unregistered.
- The service registry key exists. Values: Start=3 (demand start), Type=32 (share process), ObjectName=LocalSystem, ImagePath=C:\\WINDOWS\\system32\\svchost.exe -k wusvcs -p, DependOnService=rpcss, LaunchProtected=2, ServiceSidType=1.
- Parameters: ServiceDll=C:\\Windows\\System32\\WaaSMedicSvc.dll, ServiceMain=ServiceMain, ServiceDllUnloadOnStop=1.
- Required privileges include SeTcbPrivilege, SeChangeNotifyPrivilege, SeImpersonatePrivilege, SeTakeOwnershipPrivilege, SeSecurityPrivilege, SeBackupPrivilege, SeRestorePrivilege, SeManageVolumePrivilege and SeAssignPrimaryTokenPrivilege.
- sc.exe qc, queryex and qtriggerinfo produced no visible output in this run; therefore their results are unavailable and no conclusions are drawn from them.
- At the observation time there was no active service PID to inspect.

**System event correlation**
- In the 05:07:35–05:08:10 local window, the Network Service/WaaSMedicSvc DCOM Event 10016 (record 125167, 05:07:47) is present. A separate Local Service/ShellServiceHost pair of Event 10016 records occurs at 05:07:55.
- Nearby SCM Event 7040 records at 05:07:46 and 05:08:08 describe start-type changes for Windows Modules Installer and IsolationSession, not WaaSMedicSvc.
- In the 13:44:10–13:44:50 local window, the Network Service/WaaSMedicSvc DCOM Event 10016 (record 125360, 13:44:20) is present. SCM Event 7026 at 13:44:24 reports boot/system-start drivers dam and wesp did not load; no WaaSMedicSvc-specific SCM event was shown.

**Sysmon process evidence**
- The query returned 19 matching Sysmon Event 1/5 records for the WaaSMedic service-host command line. The displayed matching records are process-create events for:
  C:\\Windows\\System32\\svchost.exe -k wusvcs -p -s WaaSMedicSvc
- Each shown process runs as NT AUTHORITY\\SYSTEM (French display: AUTORITE NT\\Système), integrity System, parent services.exe, with svchost file version 10.0.26100.8737 and SHA-256 1222A44A5FDB4EFDE4DFCB41093648627950E7EC02D8667F1C26CCAE31D922E2.
- Around the first DCOM denial, the closest shown process creation is 05:08:31 local (Sysmon UtcTime 04:08:31.479), about 44 seconds after the 05:07:47 denial. Another creation is 05:10:16 local. The displayed list does not show a WaaSMedicSvc process start before the 05:07:47 denial.
- Around the second denial at 13:44:20 local, the displayed process creations include 13:46:26 and 13:48:22 local, after the denial; no shown creation immediately precedes it.
- The output contains repeated service-host starts throughout the morning and early afternoon, but the pasted output does not provide a clean start/stop lifecycle or prove a process was alive at either DCOM event. Event 5 records were included in the query but none of the displayed matches was a termination event.

**Interpretation and limits**
- WaaSMedicSvc is a demand-start, protected, LocalSystem service hosted in the wusvcs svchost group. This corrects the earlier assumption that the registered AppID's LocalService name alone established the runtime service identity: the service registry explicitly specifies LocalSystem.
- The DCOM Event 10016 identifies Network Service as the requesting caller; the service configuration and Sysmon process events identify WaaSMedicSvc's service host as LocalSystem. These are different security identities. The event XML does not identify the client process or prove that WaaSMedicSvc itself was the denied caller.
- The observed WaaSMedicSvc process starts occur after, rather than before, the two DCOM denials in the supplied timeline. This weakens a simple theory that an already-running WaaSMedicSvc process caused the activation failures, although the incomplete event timeline cannot rule out a prior process instance or another COM activation path.
- No direct evidence connects WaaSMedicSvc to the SPP slui.exe AutoActivate operation. No DCOM permissions, service configuration, registry, ACLs, Defender, licensing store or activation state were changed; no activation attempt occurred.
- The script's separately pasted else blocks generated PowerShell command-not-found errors. The substantive registry, event and Sysmon queries nevertheless ran; the transcript ends with TEST-54 COMPLETE.

**Next diagnostic direction**
- Resolve the remaining identity/timing ambiguity using the raw Sysmon Event 1/5 XML and System SCM events around both DCOM timestamps, including a sufficiently wide window to identify process lifetimes. Do not edit DCOM permissions or service configuration based on these correlations.


## TEST-55 — WaaSMedicSvc process-lifetime and System-event reconstruction

**Timestamp:** 2026-11-13 15:12:45–15:13:23 +01:00  
**Raw transcript:** `R:\results.activation-spp-055.txt`  
**Scope:** Read-only Sysmon Event 1/5 and System Service Control Manager / DistributedCOM XML in windows 05:00–05:20 and 13:35–14:00 local time.

**Sysmon process-create findings**
- First window: two matching Event 1 records for `svchost.exe -k wusvcs -p -s WaaSMedicSvc`: PID 3136 at 05:08:31 local (Sysmon UTC 04:08:31.479) and PID 4764 at 05:10:16 local (UTC 04:10:16.028). Both run as LocalSystem at System integrity, parent `services.exe`, same image SHA-256 `1222A44A5FDB4EFDE4DFCB41093648627950E7EC02D8667F1C26CCAE31D922E2`.
- Second window: four matching Event 1 records: PID 7308 at 13:46:26, PID 2184 at 13:48:22, PID 11920 at 13:53:11 and PID 6344 at 13:59:21 local. Same service-host command line, LocalSystem/System integrity, parent `services.exe`, and same SHA-256.
- The first known DCOM denial in the first window (05:07:47) precedes the first displayed service-host creation by about 44 seconds. The targeted second denial (13:44:20) precedes the first displayed creation by about 2 minutes 6 seconds.

**Additional DCOM events visible in the windows**
- A further Network Service / `WaaSProtectedSettingsProvider` / `WaaSMedicSvc` Local Activation denial occurred at 05:10:41 (System record 125195), after the 05:10:16 service-host creation.
- A further matching Network Service denial occurred at 13:54:35 (System record 125405), after the 13:53:11 service-host creation.
- These later events add temporal overlap between service-host creation and repeated DCOM denials, but do not establish that the service host was still running at the event time or that it was the denied caller. The DCOM XML identifies Network Service as the caller identity; the WaaSMedicSvc service is configured to run as LocalSystem. The DCOM event does not identify the client process.

**Important instrumentation limitation**
- The query filtered Sysmon Event 1 and Event 5 records by `Message -match 'WaaSMedicSvc'`. Event 1 contains the service-specific command line, but Event 5 termination records may contain only the image/process identity and omit the service name. Therefore this filter can exclude the corresponding termination events. The absence of displayed Event 5 records is not evidence that no termination occurred.
- The supplied output therefore does not establish complete process lifetimes or prove whether any listed service-host PID was alive at the DCOM event timestamps. A follow-up, if needed, must retrieve Event 5 records by the Event 1 ProcessGuid/PID rather than filtering termination messages for the service name.

**Other System events**
- Windows Search repeatedly failed with SCM 7023/7031/7034 events in both windows; these remain a separate service issue with no demonstrated SPP link.
- SCM 7040 events concern TrustedInstaller, IsolationSession and BITS; none identifies WaaSMedicSvc.
- No service configuration, DCOM permissions, registry, ACL, Defender, licensing-store or activation state was changed. No activation attempt occurred.

**Interpretation / next direction**
- The original 05:07:47 and 13:44:20 DCOM denials both precede the first displayed WaaSMedicSvc process creation in their respective windows. The later repeated DCOM denials at 05:10:41 and 13:54:35 occur after service-host creation, so temporal association cannot be dismissed entirely.
- However, the identity mismatch and missing client-process attribution remain decisive limits. DCOM Event 10016 does not prove WaaSMedicSvc itself was the requesting client, and process creation alone does not prove that process was alive at the denial.
- Keep the DCOM/WaaSMedicSvc thread as an unresolved correlation, not an established cause of SPP `0x80070005`. Do not modify DCOM permissions or WaaSMedicSvc configuration. If pursuing this thread further, first reconstruct Event 5 lifetimes using ProcessGuid/PID; otherwise pivot to instrumentation of the SPP `slui.exe` AutoActivate operation and its actual denied resource/API.


### TEST-56 — WaaSMedicSvc Sysmon Event 5 termination by ProcessGuid
- Run timestamp: 2026-11-13 15:18:09 +01:00. Intended transcript path `R:\results.activation-spp-056.txt` was not created: Windows PowerShell 5.1 rejected `Start-Transcript -Encoding UTF8`, and `Stop-Transcript` consequently reported that transcription was not active. The results were captured in the interactive console; no raw transcript artifact is available for this test.
- Read-only query retrieved 3,089 Sysmon Event 5 records for 2026-11-13 05:00–15:30 local and matched six exact ProcessGuids supplied from the TEST-55 Event 1 results. All six matching termination records were found:
  - PID 3136, ProcessGuid `{f90187c8-8d3f-6af6-2b01-000000006b02}`, terminated 05:09:31.648 local (Sysmon UTC 04:09:31.648), record 2445380.
  - PID 4764, ProcessGuid `{f90187c8-8da8-6af6-5c01-000000006b02}`, terminated 05:11:40.486 local (UTC 04:11:40.486), record 2445435.
  - PID 7308, ProcessGuid `{f90187c8-06a2-6af7-ba00-000000006c02}`, terminated 13:47:26.440 local (UTC 12:47:26.440), record 2449102.
  - PID 2184, ProcessGuid `{f90187c8-0716-6af7-c300-000000006c02}`, terminated 13:49:22.563 local (UTC 12:49:22.563), record 2449113.
  - PID 11920, ProcessGuid `{f90187c8-0837-6af7-8701-000000006c02}`, terminated 13:54:11.832 local (UTC 12:54:11.832), record 2449450.
  - PID 6344, ProcessGuid `{f90187c8-09a9-6af7-b801-000000006c02}`, terminated 14:00:21.476 local (UTC 13:00:21.476), record 2449529.
- Correlation with TEST-55 Event 1 starts and System DCOM events:
  - The 05:07:47 Network Service / WaaSProtectedSettingsProvider DCOM denial preceded the first shown service-host creation (05:08:31) and therefore is not explained by one of these newly created processes.
  - A later matching DCOM denial at 05:10:41 occurred after PID 4764 was created at 05:10:16 and before it terminated at 05:11:40. This establishes temporal overlap for that one later denial, but not causation or proof that PID 4764 was the DCOM client. The DCOM event identifies Network Service as caller identity; WaaSMedicSvc is configured to run as LocalSystem, and the event XML does not identify the client process.
  - The 13:44:20 denial preceded the first shown service-host creation (13:46:26). The later 13:54:35 denial occurred after PID 11920 terminated at 13:54:11; the other shown afternoon processes also do not establish a client identity for that event.
- The Event 5 records close the specific termination-query gap identified in TEST-55: these six ProcessGuids have corresponding termination records. They do not establish that a WaaSMedicSvc process caused the SPP activation failure. The only demonstrated overlap is the 05:10:41 DCOM event and PID 4764's lifetime; the initial DCOM events closest to the activation bursts remain before the shown service-host starts.
- The separately pasted `else` generated a harmless command-not-found error after the `if` block had completed; it did not invalidate the six matches. No service, DCOM, registry, ACL, Defender, licensing-store or activation state was changed. No `/ato` attempt occurred.
- Interpretation: downgrade WaaSMedicSvc/DCOM from a candidate direct explanation of the SPP AutoActivate failures to a limited temporal correlation requiring client-process attribution before any remediation could be considered. Do not change DCOM permissions or WaaSMedicSvc configuration on this evidence. Prefer pivoting to instrumentation of the SPP `slui.exe` AutoActivate operation and its actual denied resource/API.


## TEST-56 — WaaSMedicSvc process termination correlation by ProcessGuid

**Timestamp:** 2026-11-13 15:18:09 +01:00  
**Raw log intended:** `R:\results.activation-spp-056.txt` (transcript did not start; see instrumentation note below)  
**Scope:** Read-only query of Sysmon Operational Event ID 5 from 2026-11-13 05:00–15:30 local time, matching six ProcessGuid values previously identified for `WaaSMedicSvc` service-host processes.

### Results

- Sysmon Event 5 query returned 3,089 records in the requested window.
- All six target ProcessGuids had a matching termination event:
  - PID 3136 — 05:09:31.648 local, Event Record 2445380.
  - PID 4764 — 05:11:40.486 local, Event Record 2445435.
  - PID 7308 — 13:47:26.440 local, Event Record 2449102.
  - PID 2184 — 13:49:22.563 local, Event Record 2449113.
  - PID 11920 — 13:54:11.832 local, Event Record 2449450.
  - PID 6344 — 14:00:21.476 local, Event Record 2449529.
- The matching records identify `C:\Windows\System32\svchost.exe`; the ProcessGuid values match the six previously identified WaaSMedicSvc service-host instances. Event 5 confirms process termination but does not provide an exit status or explain why each process ended.
- In the first DCOM window, the Network Service/WaaSProtectedSettingsProvider denial occurred at 05:07:47.085. The nearest identified WaaSMedicSvc process start was approximately 05:08:31, after the denial; its matching termination was 05:09:31.648. The next identified instance terminated at 05:11:40.486.
- In the second DCOM window, the denial occurred at 13:44:20.381. The nearest identified WaaSMedicSvc process start was approximately 13:46:26, after the denial; its matching termination was 13:47:26.440. Further instances terminated at 13:49:22.563, 13:54:11.832, and 14:00:21.476.

### Interpretation and limits

The process-lifetime evidence does not support a simple hypothesis that one of these already-running WaaSMedicSvc service-host processes was the client issuing either Network Service DCOM activation request: the nearest identified process instances began after the respective DCOM events. This weakens the DCOM/WaaSMedicSvc lead substantially. It does not exclude another COM activation path, an unobserved process instance, or a more complex interaction; the DCOM event XML still does not identify the client process.

The DCOM events identify Network Service (S-1-5-20) as the requesting identity, while the WaaSMedicSvc service configuration identifies LocalSystem as the service account. These identities must not be conflated. No causal link to the SPP `slui.exe` AutoActivate operation has been established.

### Instrumentation note

The attempted transcript start used `Start-Transcript -Encoding UTF8`, which is not a supported parameter in Windows PowerShell 5.1; therefore no transcript was created. A separately entered `else` block was not syntactically attached to its preceding `if`, and `Stop-Transcript` consequently reported that transcription was not active. These are logging/script-entry issues and do not invalidate the six returned Event 5 matches. No system configuration, service, DCOM permission, ACL, Defender setting, licensing data, or activation state was changed. No activation attempt was made.

## TEST-57 — SppExtComObj broker lifetime and parent/child correlation

- Timestamp: 2026-11-13 15:22:03–16:04:56 +01:00 (transcript start/end).
- Raw local log: `R:\results.activation-spp-057.txt`.
- Read-only Sysmon Event 1/5 query covering 2026-11-12 20:25 through 2026-11-13 14:05 local; 9,583 records parsed.
- 19 `slui.exe` process-creation records found. The Network Service/System-integrity instances have parent image `C:\Windows\System32\SppExtComObj.Exe`, command line `SppExtComObj.exe -Embedding`, and parent ProcessGuid values that identify the exact broker process instance. Other `slui.exe` records in the output ran as the interactive user at Medium integrity and were parented by `svchost.exe -k DcomLaunch -p`; these are distinct from the Network Service automatic-activation children.
- Six distinct `SppExtComObj.exe` broker instances were identified, all running as `NT AUTHORITY\NETWORK SERVICE` at System integrity. Each had a matching Sysmon Event 5 termination record with the same ProcessGuid:
  - PID 6644: start 2026-11-12 20:31:07.297 UTC / 20:31:07 local; exit 20:31:38.784 local; one `slui.exe` child.
  - PID 5904: start 2026-11-13 04:05:36.080 UTC / 05:05:36 local; exit 05:06:09.552 local; three `slui.exe` children.
  - PID 1544: start 04:07:32.323 UTC / 05:07:32 local; exit 05:09:12.760 local; three `slui.exe` children.
  - PID 13924: start 12:13:25.391 UTC / 13:13:25 local; exit 13:14:01.090 local; four `slui.exe` children.
  - PID 2888: start 12:44:31.128 UTC / 13:44:31 local; exit 13:45:09.410 local; two `slui.exe` children.
  - PID 1612: start 12:50:48.371 UTC / 13:50:48 local; exit 13:51:24.932 local; two `slui.exe` children.
- Parent ProcessGuid correlation establishes that the Network Service `slui.exe` children were launched by these exact broker instances, rather than merely by a process with the same PID or image name. This is strong process attribution for the SPP automatic-activation execution chain.
- DCOM timing: the Network Service/WaaSProtectedSettingsProvider Event 10016 at 05:07:47.085 occurred during the PID 1544 broker lifetime (broker started 05:07:32 and exited 05:09:12). The Event 10016 at 13:44:20.381 preceded the PID 2888 broker start at 13:44:31 by about 11 seconds. The Event 10016 at 13:50:47 preceded the PID 1612 broker start at 13:50:48 by about one second. These temporal relationships are noteworthy but do not establish causation.
- This test confirms a short-lived, repeatedly activated `SppExtComObj.exe` broker pattern, with each observed broker instance launching one or more `slui.exe` children and then terminating within roughly 31–100 seconds. Event 5 confirms process termination only; it does not provide exit status or reason.
- The two PowerShell `System.IO.Path.GetFileName` exceptions occurred while filtering records with malformed/non-path Image values. Despite those exceptions, the output contains the six matching broker lifecycle pairs and the unique broker ProcessGuids. Treat the displayed matches as valid, but do not claim the faulty filter was exhaustive for every possible record.
- This narrows the process chain but does not identify the specific API, COM method, RPC, file, registry, or other resource operation returning `0x80070005`. The DCOM 10016 events still identify Network Service as the requesting security identity but do not identify the client PID or prove that the WaaS DCOM denial caused the SPP activation failure.
- No services, DCOM permissions, ACLs, Defender settings, licensing data, or activation state were changed. No activation attempt was made.


## TEST-58 — operation-level tracing capability inventory

- Timestamp: 2026-11-13 16:07:17–16:07:35 +01:00.
- Raw local log: `R:\results.activation-spp-058.txt`.
- Read-only inventory; no application was launched, installed, or configured, and no activation attempt was made.
- Process Monitor was not found in PATH, common Sysinternals/Tools locations, Downloads, Desktop, or the inspected uninstall registry entries. Therefore no executable signature or version could be checked. The search was intentionally limited to common locations and does not prove the executable is absent everywhere.
- `wpr.exe` exists at `C:\Windows\System32\wpr.exe`. `wpr -profiles` returned no visible profile listing in the transcript but exit code 0. Profile availability and usable profile names remain unverified; do not infer that no profiles exist.
- `logman query providers` confirmed registration of these relevant ETW providers: Microsoft-Windows-CodeIntegrity, Microsoft-Windows-DistributedCOM, Microsoft-Windows-Kernel-File, Microsoft-Windows-Kernel-Process, Microsoft-Windows-Kernel-Registry, and Microsoft-Windows-Security-Auditing. Provider registration alone does not prove the required event keywords, access-denied status fields, or a useful trace configuration are available.
- Several `else` blocks were entered separately after their corresponding `if` blocks, producing command-not-found errors. The primary inventory results remain: no Process Monitor found in checked locations, no matching uninstall registration, WPR present with a silent `-profiles` result and exit code 0, and the listed ETW providers registered.
- This test establishes that built-in ETW/WPR components are present, but does not yet establish a safe, sufficiently detailed capture recipe for identifying the exact failed SPP operation. No audit policy, ETW session, service, DCOM permission, ACL, Defender setting, licensing data, or activation state was changed.


## TEST-59 — WPR profile and ETW provider metadata

- Timestamp: 2026-11-13 16:08:25–16:08:28 +01:00.
- Raw local log: `R:\results.activation-spp-059.txt`.
- `wpr.exe -help` succeeded (exit code 0) and identified dedicated help topics for start, stop, status, profiles, providers, tracing, and advanced commands.
- `wpr.exe -profiles` succeeded (exit code 0) and listed built-in profiles including `GeneralProfile`, `FileIO`, `Registry`, `Network`, `DiskIO`, and `Minifilter`, among others. This confirms usable profile names are exposed by this Windows Performance Recorder build.
- The inspected conventional WPR profile directories and Windows Performance Toolkit install directories were absent. `C:\Windows\System32\WPRProfiles` was not present, so no `.wprp` files were enumerated there. This does not invalidate the profiles enumerated by WPR itself; profile definitions may be embedded or stored elsewhere.
- The transcript did not establish whether `xperf.exe` is installed: the separate `else` block was entered after the `if` block and produced a command-not-found error. Treat xperf availability as unknown.
- `wevtutil gp Microsoft-Windows-Kernel-File /ge:true /gm:true` returned 575 lines of provider metadata. The displayed first 100 lines included file operation tasks such as Create, Cleanup, Close, Read, Write, SetInformation, Rename, QueryInformation, FSCTL, and OperationEnd.
- `wevtutil gp Microsoft-Windows-Kernel-Registry /ge:true /gm:true` returned 724 lines of provider metadata. The displayed first 100 lines confirmed Analytic and Performance channels and multiple registry operation opcodes. The transcript only displayed the first 100 lines of each metadata result, so status/result fields and relevant event templates were not yet inspected.
- The WPR profile listing makes built-in FileIO and Registry profiles available as plausible tracing components. However, this test did not establish whether their captured events include the operation result/status needed to identify `ACCESS DENIED`, nor whether their combined trace can be narrowly filtered to the SPP process chain.
- No trace was started, no audit policy or ETW provider configuration was changed, and no services, DCOM permissions, ACLs, Defender settings, licensing data, or activation state were changed. No activation attempt was made.



## TEST-58 — operation-level trace capability inventory

- Read-only inventory at 2026-11-13 16:07:17 +01:00; raw transcript: `R:\\results.activation-spp-058.txt`.
- Process Monitor was not found through PATH or the checked common installation/download/desktop/tool locations. No matching Process Monitor/Sysinternals application registration was found in the checked uninstall registry locations. This is a bounded search, not proof that no copy exists elsewhere.
- `wpr.exe` exists at `C:\\Windows\\System32\\wpr.exe`; initial `wpr -profiles` invocation returned exit code 0 but no profile text was captured in this test. TEST-59 subsequently confirmed the profile list.
- `logman query providers` confirmed registration of Microsoft-Windows-CodeIntegrity, Microsoft-Windows-DistributedCOM, Microsoft-Windows-Kernel-File, Microsoft-Windows-Kernel-Process, Microsoft-Windows-Kernel-Registry and Microsoft-Windows-Security-Auditing.
- The pasted script was entered in separate chunks: standalone `else` blocks produced command-not-found errors after their corresponding `if` blocks had already completed. These errors affect only optional display branches; positive/negative findings above are from the executed checks. No configuration or system state was changed.

## TEST-59 — WPR profile and ETW trace-definition inventory

- Read-only inventory at 2026-11-13 16:08:25 +01:00; raw transcript: `R:\\results.activation-spp-059.txt`.
- WPR version reported `10.0.26100`. `wpr -profiles` succeeded (exit code 0) and listed built-in profiles including `GeneralProfile`, `FileIO`, `Registry`, `DiskIO`, `Network`, and others. FileIO and Registry are available as candidate focused trace profiles.
- The checked WPR profile directories and Windows Performance Toolkit directories were not present. This does not negate the built-in profiles enumerated by WPR.
- `xperf.exe` availability was not conclusively recorded: the intended `else` block was pasted separately and failed as a standalone command. Do not classify xperf as absent based on this test.
- `wevtutil gp` returned provider metadata: 575 lines for Microsoft-Windows-Kernel-File and 724 lines for Microsoft-Windows-Kernel-Registry. The excerpts establish event/task/keyword definitions, but the displayed excerpts do not establish the full payload schema or identify a result/status field for the operations of interest.
- Standalone `else` command-not-found errors arose from chunked entry of conditional blocks. No WPR recording was started; no system configuration was changed.

## TEST-60 — ETW operation-result field inspection

- Read-only inspection at 2026-11-13 16:09:12 +01:00; raw transcript: `R:\\results.activation-spp-060.txt`.
- WPR help confirmed `wpr -start` accepts built-in or custom profiles and supports file-mode recording. Provider help documents provider enumeration. WPR status returned `WPR is not recording` (exit code 0).
- Kernel-File provider metadata search returned 107 matches for terms including status/result/NTSTATUS/access/denied/error and event/payload identifiers. The displayed first 100 matches showed operation/event definitions (including create, cleanup, close, read, write, set-information, rename, query-information, FSCTL and operation-end), keywords and event IDs, but did not expose a confirmed operation-result field in the captured excerpt.
- Kernel-Registry metadata search returned 106 matches. The displayed first 100 matches showed operation keywords/events including create/open/delete/query key, query/set security, enumerate/query/set/delete values and related operations, but did not expose a confirmed operation-result field in the captured excerpt.
- Therefore TEST-60 does not yet prove that the selected provider payloads will expose the failing NTSTATUS. It does establish that WPR is idle and the relevant provider metadata is queryable. No trace was started, no activation attempt was made, and no configuration, ACL, service, Defender or licensing state was changed.

### Trace-capture decision after TEST-58–60

WPR's built-in FileIO and Registry profiles are available, but the provider metadata excerpts collected so far are insufficient to guarantee that the trace will contain a usable status/result field or capture the relevant security check. Before recording, inspect the complete event template/payload definitions for the relevant Kernel-File and Kernel-Registry events, and determine whether WPR can capture the required process/thread correlation and access-denied result without an unnecessarily broad or long-running trace. The next step should remain a bounded capability/schema inspection; do not start a trace or trigger activation until its scope, output location, duration and stop procedure are defined.


## TEST-61 — ETW event template and payload schema inspection

- Read-only inspection at 2026-11-13 16:10:33 +01:00; raw transcript: `R:\\results.activation-spp-061.txt`.
- `Get-WinEvent -ListProvider` successfully enumerated 43 Kernel-File event definitions and 45 Kernel-Registry event definitions.
- Kernel-File event templates expose file-operation identity/context fields. Create event 12 includes IRP, thread/issuing-thread ID, file object and file name; read/write and related operation templates also include IRP/file object and issuing-thread information. The displayed event 24 `OperationEnd` template is especially important: `Irp [win:Pointer]; ExtraInformation [win:Pointer]; Status [win:UInt32]`. This is a concrete operation-result/status field, although the test has not yet established its exact semantics for every operation or verified which FileIO WPR variant records it.
- Kernel-Registry event templates directly expose `Status [win:UInt32]` on operation events, together with key identity/name and operation-specific fields. Examples include event 1 create key, 2 open key, 3 delete key, 4 query key, 5 set value, 6 delete value, 7 query value, 8/9 enumerate keys/values, 10 query multiple values, 11 set information, and 12 flush key. Additional registry event templates expose `StatusCode [win:HexInt32]` for selected non-operation events.
- The ETW event header supplies process/thread context in addition to the payload fields listed by the templates; the template output itself does not list header fields. A trace reader must retain those event-header fields to attribute operations to the SppExtComObj/slui process chain.
- This is the first direct evidence that the installed kernel registry provider has per-operation status fields and the kernel file provider has an operation-end status field. It makes a short WPR FileIO + Registry capture technically promising. It does not yet prove the built-in WPR profiles enable the relevant event keywords/versions, that the FileIO operation-end status can be joined to its initiating operation reliably, or that the resulting trace will contain the denied operation.
- No WPR recording was started, no activation attempt was made, and no audit policy, ETW configuration, service, DCOM permission, ACL, Defender setting, licensing data or system configuration was changed.

### Trace-capture decision after TEST-61

Proceed to a bounded WPR capture design using the built-in `FileIO` and `Registry` profiles, retaining process/thread headers and file-operation completion/status events. Before starting, verify the WPR profile variants and capture/stop syntax, ensure a dedicated output file on `R:\\`, and define a short capture window around one explicitly authorized reproduction of the existing automatic activation trigger. The trace must be stopped immediately after the relevant SPP broker/slui activity is observed. Do not change permissions or trigger `/ato` as part of this step; the reproduction mechanism and exact capture boundary must be agreed before recording.


## TEST-60 — ETW operation-result metadata inspection

- Timestamp: 2026-11-13 16:09:12–16:09:15 +01:00.
- Raw local log: `R:\\results.activation-spp-060.txt`.
- Read-only inspection; no ETW session was started and no activation attempt was made.
- `wpr -help start` confirmed WPR supports built-in or custom profiles and multiple profiles on one command line. `wpr -help providers` confirmed provider enumeration syntax.
- Kernel-File provider metadata exposed operation keywords for file create, read, write, delete, rename/link, and operation-end activity. Event metadata includes numerous file operation events; the keyword list itself does not establish that every operation reports a result.
- Kernel-Registry metadata exposed operation keywords including OpenKey, CreateKey, QueryKey, QueryValueKey, EnumerateKey/Value, SetValueKey, DeleteKey, QuerySecurityKey and SetSecurityKey.
- WPR status reported `WPR is not recording` (exit code 0).
- Important limitation: the broad text filter returned event IDs and keyword metadata, but did not establish event payload schemas or whether a given file event carries an NTSTATUS result. Follow-up template inspection was required.
- No provider configuration, audit policy, ETW session, service, DCOM permission, ACL, Defender setting, licensing data or activation state changed.
 
## TEST-61 — Kernel-File and Kernel-Registry event-template schema inspection

- Timestamp: 2026-11-13 16:10:33–16:10:35 +01:00.
- Raw local log: `R:\\results.activation-spp-061.txt`.
- Read-only inspection using `Get-WinEvent -ListProvider`; no ETW session was started and no activation attempt was made.
- Kernel-File provider exposed 43 event definitions. Most file create/read/write and metadata-operation templates inspected include file/IRP identifiers, file object/key, issuing thread ID and/or file name/path, but not an explicit Status field in the displayed templates. Event 24 version 0 contains `Irp`, `ExtraInformation`, and `Status` (UInt32). This is a potential I/O completion result source; correlation to the originating file operation would be required and has not yet been demonstrated.
- Kernel-Registry provider exposed 45 event definitions. Events 1–15 include a `Status` (UInt32) field on key create/open/delete/query/enumerate/set operations, with key name and, where applicable, value name and captured data. Additional hive-related events expose StatusCode fields.
- This is a meaningful lead: a registry trace may directly identify unsuccessful operations and the affected key. File tracing may require correlating Event 24 completion records with operation events using IRP/file/thread identifiers.
- The schema inspection does not yet prove which statuses will be emitted under the selected WPR profile, whether all relevant operations are captured, or whether the trace can be filtered to the SPP processes without losing correlation.
- No configuration, audit policy, ETW session, service, DCOM permission, ACL, Defender setting, licensing data or activation state changed.

## TEST-62 — WPR capture preflight

- Timestamp: 2026-11-13 16:12:04–16:12:06 +01:00.
- Raw local log: `R:\\results.activation-spp-062.txt`.
- Read-only preflight; no recording was started or stopped and no activation attempt was made.
- WPR start/stop help confirmed the supported command syntax. Available built-in profiles include `FileIO` and `Registry`, in addition to GeneralProfile and other profiles.
- `wpr -status` reported that WPR was not recording.
- Proposed output path `R:\\activation-spp-062.etl` did not already exist.
- R: RAM drive reported 4,149,526,528 bytes free (approximately 3.865 GiB), sufficient for a short, bounded capture subject to monitoring file growth.
- A separately entered `else` block produced a PowerShell command-not-found error after the preceding `if` block had already completed. The drive-capacity and path checks themselves returned the values above; the error does not invalidate them.
- WPR profile availability is now established, but profile event detail, capture size, process attribution, and the exact stop/analysis workflow remain to be validated. No trace has been recorded.
- No ETW session, service, DCOM permission, ACL, audit policy, Defender setting, licensing data or activation state changed.


## TEST-63 — Exported WPR FileIO + Registry profile inspection

- Timestamp: 2026-11-13 16:13:25–16:13:27 +01:00.
- Raw local log: `R:\\results.activation-spp-063.txt`.
- Exported WPR profile file: `R:\\activation-spp-063-profiles.wprp` (11,386 bytes; XML parsed successfully). WPR command exit code 0.
- Export command: `wpr -exportprofile FileIO+Registry R:\\activation-spp-063-profiles.wprp -filemode`.
- Exported profile ID: `FileIORegistry.Verbose.File`; profile name `FileIORegistry`; LoggingMode File; DetailLevel Verbose.
- Profile defines one system collector and one event collector, each with BufferSize 1024 and Buffers 40.
- SystemProvider explicitly enables keywords `FileIO`, `FileIOInit`, `Registry`, and `ProcessThread`, among other system keywords. This is direct evidence that the combined profile requests the kernel file, registry and process/thread event families needed for process attribution.
- SystemProvider requests stack capture for file create, cleanup, close, read, write, set-information, delete, rename, directory enumeration, flush, query-information, FSCTL, operation-end and directory-notify events; it also requests registry create/open/delete/query/set/enumerate/flush/security and related events.
- The exported profile includes additional EventProvider definitions, some with explicit keywords and levels and some without. The initial PowerShell display extracted the provider attributes in a confusing order (the XML's Name attributes are GUIDs and Id attributes are WPR aliases); no provider identity should be inferred from that display alone. The underlying XML was successfully parsed and the SystemProvider keywords/stacks above are explicit in the raw exported XML.
- The profile is verbose and system-wide, not restricted to sppsvc, SppExtComObj or slui. It can collect unrelated file/registry activity and potentially sensitive paths/data. A future recording must therefore be short, monitored, saved only to the user's R: diagnostic RAM drive, and stopped immediately after a relevant SPP automatic-activation event or at a strict time/size boundary.
- The displayed Get-FileHash section contained no hash output; no hash value is recorded for this profile artifact.
- No ETW recording was started. No activation attempt, service or system configuration change, audit policy change, DCOM permission change, ACL change, Defender change or licensing-store change occurred.


## TEST-64 — WPR profile re-export attempt (incomplete)

- Timestamp: 2026-11-13 16:15:11–16:15:15 +01:00.
- Raw local log: `R:\\results.activation-spp-064.txt`.
- The script checked the same profile destination used by TEST-63, `R:\\activation-spp-063-profiles.wprp`. Because that file already existed, the first `if` branch correctly declined to overwrite it.
- The separately pasted `else` block was not attached to the preceding conditional and produced a PowerShell command-not-found error. Consequently, the intended second export and profile inspection did not run.
- A subsequent `wpr -status` returned exit code 0 but no visible output. This is inconclusive as a standalone status observation; TEST-62 had already explicitly reported “WPR is not recording.”
- TEST-64 therefore adds no new profile-definition or ETW-session evidence. The successful TEST-63 export remains authoritative.
- No ETW recording was started, no existing profile file was overwritten, and no Windows configuration, service, ACL, DCOM permission, Defender setting, licensing data or activation state was changed.


## TEST-65 — WPR event-provider resolution (incomplete)

- Timestamp: 2026-11-13 16:16:14–16:16:16 +01:00.
- Raw local log: `R:\\results.activation-spp-065.txt`.
- The script loaded the exported TEST-63 WPR profile and prepared to resolve the event-provider GUIDs, but PowerShell 5.1 raised a parser error at two pipelines attached directly to `foreach` statement blocks.
- Because the script failed to parse, neither provider-resolution output nor provider-configuration output was produced. The separately pasted `else` block then failed as a standalone command; it does not indicate that the profile file was absent.
- No provider identity or event coverage conclusion can be drawn from TEST-65. The successfully exported profile from TEST-63 remains unchanged and authoritative for the system-provider keywords and requested stacks.
- No ETW recording was started, no profile file was modified, and no Windows configuration, service, ACL, DCOM permission, Defender setting, licensing data or activation state was changed.


## TEST-65R — Corrected WPR event-provider resolution attempt (incomplete)

- Timestamp: 2026-11-13 16:16:49–16:16:51 +01:00.
- Raw local log: `R:\\results.activation-spp-065R.txt`.
- The existing profile path had been confirmed by TEST-63. However, the script's initial `if (-not (Test-Path ...))` was entered and executed separately from its following `else` block. The condition was false because the file existed; the subsequent standalone `else` generated a command-not-found error.
- Consequently, the XML loading, provider GUID resolution, and provider configuration inspection did not execute. No provider identity or event coverage conclusion can be drawn from TEST-65R.
- No ETW recording was started, no profile file was modified, and no Windows configuration, service, ACL, DCOM permission, Defender setting, licensing data or activation state was changed.
- Process correction for the next attempt: remove conditional branching entirely and execute the known-existing profile read directly, avoiding split `if/else` blocks.


## TEST-63 — exported FileIO + Registry WPR profile inspection

- Timestamp: 2026-11-13 16:13:25–16:13:27 local.
- Raw transcript: `R:\\results.activation-spp-063.txt`.
- `wpr -exportprofile FileIO+Registry R:\\activation-spp-063-profiles.wprp -filemode` returned exit code 0 and created an 11,386-byte XML profile. XML parsed successfully. The attempted SHA-256 output was blank in the transcript, so no hash is recorded.
- Exported profile: `FileIORegistry.Verbose.File`, Name `FileIORegistry`, Description `RunningProfile:Registry.Verbose.File, FileIO.Verbose.File`, LoggingMode File, DetailLevel Verbose.
- System provider enables CpuConfig, CSwitch, DiskIO, DPC, FileIO, FileIOInit, HardFaults, IdealProcessor, Interrupt, Loader, MemoryInfo, ProcessCounter, Power, ProcessThread, ReadyThread, SampledProfile, ThreadPriority, WDFDPC, WDFInterrupt and Registry.
- Stack collection includes FileCreate, FileCleanup, FileClose, FileRead, FileWrite, FileSetInformation, FileDelete, FileRename, FileDirEnum, FileFlush, FileQueryInformation, FileFSCTL, FileOpEnd, FileDirNotify, ThreadDCEnd, and registry create/open/delete/query/set/enumerate/flush/security operations.
- System and event collectors each specify 1,024-KiB buffers and 40 buffers.
- The profile is broad, not SPP-process-filtered. It includes the FileIO and Registry instrumentation needed for the next investigation stage, but also CPU, disk, memory, power, and other system activity. Any recording should therefore be short and bounded.
- The initial provider listing printed EventProvider attributes rather than nested XML; the subsequent full profile XML was separately supplied and confirms the SystemProvider keywords and stacks above.
- TEST-63 did not start a recording or change system configuration.

## TEST-64 — WPR memory-mode profile preflight (incomplete)

- Timestamp: 2026-11-13 16:15:11–16:15:15 local.
- Raw transcript: `R:\\results.activation-spp-064.txt`.
- The attempt to export `FileIO+Registry` without `-filemode` did not execute as intended: the `else` block was pasted separately and PowerShell reported that `else` was not recognized.
- `wpr -status` returned exit code 0 with no output; this is consistent with WPR remaining idle, but does not establish whether the default/memory-mode profile can be exported.
- No trace was started and no system configuration was changed. Treat memory-mode profile behavior as untested.

## TEST-65 / TEST-65R — provider resolution attempts (incomplete)

- Raw transcripts: `R:\\results.activation-spp-065.txt` and `R:\\results.activation-spp-065R.txt`.
- TEST-65 failed at PowerShell parse time because a pipeline followed a `foreach` statement block in a form not accepted by Windows PowerShell 5.1. The separately pasted `else` in TEST-65R also failed. Neither attempt produced a valid provider-resolution result.
- No trace was started and no system configuration was changed.

## TEST-65S — WPR event-provider GUID resolution

- Timestamp: 2026-11-13 16:17:35–16:17:55 local.
- Raw transcript: `R:\\results.activation-spp-065S.txt`.
- Successfully parsed the exported TEST-63 WPR profile and extracted 19 unique EventProvider GUIDs.
- Seventeen GUIDs resolved through `Get-WinEvent -ListProvider *`:
  - `36b6f488-aad7-48c2-afe3-d4ec2c8b46fa` — Microsoft-Windows-Performance-Recorder-Control (56 events).
  - `57277741-3638-4a4b-bdba-0ac6e45da56c` — Microsoft-JScript (258).
  - `e13c0d23-ccbc-4e12-931b-d9cc2eee27e4` — Microsoft-Windows-DotNETRuntime (168).
  - `b675ec37-bdb6-4648-bc92-f3fdc74d3ca2` — Microsoft-Windows-Kernel-EventTracing (52).
  - `d49918cf-9489-4bf1-9d7b-014d864cf71f` — Microsoft-Windows-ProcessStateManager (8).
  - `e6835967-e0d2-41fb-bcec-58387404e25a` — Microsoft-Windows-BrokerInfrastructure (48).
  - `314de49f-ce63-4779-ba2b-d616f6963a88` — Microsoft-Windows-NCSI (57).
  - `8c416c79-d49b-4f01-a467-e56d3aa8234c` — Microsoft-Windows-Win32k (369).
  - `e7ef96be-969f-414f-97d7-3ddb7b558ccc` — unresolved by this enumeration.
  - `9580d7dd-0379-4658-9870-d5be7d52d6de` — Microsoft-Windows-WLAN-AutoConfig (255).
  - `8e92deef-5e17-413b-b927-59b2f06a3cfc` — Microsoft-Antimalware-RTP (29).
  - `0a002690-3839-4e3a-b3b6-96d8df868d99` — Microsoft-Antimalware-Engine (130).
  - `cfeb0608-330e-4410-b00d-56d8da9986e6` — Microsoft-Antimalware-AMFilter (11).
  - `e4b70372-261f-4c54-8fa6-a5a7914d73da` — Microsoft-Antimalware-Protection (7).
  - `751ef305-6c6e-4fed-b847-02ef79d26aef` — Microsoft-Antimalware-Service (75).
  - `a669021c-c450-4609-a035-5af59af4df18` — Microsoft-Windows-DotNETRuntimeRundown (45).
  - `0f67e49f-fe51-4e9f-b490-6f2948cc6027` — Microsoft-Windows-Kernel-Processor-Power (319).
- Two GUIDs were not resolved by this enumeration: `b7a19fcd-15ba-41ba-a3d7-dc352d5f79ba` and `e7ef96be-969f-414f-97d7-3ddb7b558ccc`. The latter also appears as a CaptureState provider in the exported profile. Failure to resolve through this cmdlet is not proof that the provider is unavailable to WPR.
- The profile's EventProvider definitions include several providers with explicit keyword masks and levels, and several with no explicit keyword/level attributes. The SystemProvider explicitly enables FileIO, FileIOInit, Registry, and ProcessThread plus the stack set documented in TEST-63.
- Interpretation: the profile contains the required kernel FileIO and Registry instrumentation and useful process/thread context. The two unresolved event-provider GUIDs and the broad ancillary providers should be noted, but do not invalidate the kernel SystemProvider configuration. This inspection does not prove that every event template/version will be emitted or that every denied operation will be captured.
- No WPR recording was started; no activation attempt, audit-policy change, service change, DCOM permission change, ACL change, Defender change, licensing-store change, or other system configuration change was made.


## TEST-66 — WPR custom profile start attempt (failed before recording)

- Timestamp: 2026-11-13 16:19:27 +01:00.
- Raw transcript: `R:\\results.activation-spp-066.txt`.
- Preflight showed approximately 3,957.2 MiB free on R:. `wpr -status` returned exit code 0 but no captured text.
- Start command attempted: `wpr -start "R:\\activation-spp-063-profiles.wprp!FileIORegistry.Verbose.File" -filemode`.
- WPR returned signed exit code `-983562735`, equivalent to `0xC5600611`. The command wrapper treated the nonzero result as a start failure; the capture loop was not entered. No ETL was created or confirmed, and no five-minute recording ran.
- The script's `finally` block was pasted as a separate command and was not executed. This is a PowerShell paste-boundary error; it does not establish a WPR problem. Transcript output ended without a normal Stop-Transcript footer.
- No activation attempt or Windows configuration change was made. No WPR trace was confirmed active. The WPR error code has not yet been conclusively decoded.
- Microsoft WPR command-line documentation specifies custom profile selector syntax as `[filename.wprp!]<profile name>[.{light|verbose}]`; the `.File` suffix is not part of the documented selector syntax, while file logging is selected separately with `-filemode`. Therefore the attempted selector is likely malformed. Confirm the exact profile name using `wpr -profiles <path>` before retrying. Do not infer a deeper WPR or ETW subsystem failure from this attempt.


## TEST-66R — WPR profile identifier and idle-state inspection

- Timestamp: 2026-11-13 16:20:09–16:20:11 +01:00.
- Raw transcript: `R:\\results.activation-spp-066R.txt`.
- Parsed the exported XML successfully. It contains one profile node with `Id="FileIORegistry.Verbose.File"`, `Name="FileIORegistry"`, `DetailLevel="Verbose"`, and `LoggingMode="File"`.
- WPR `-profiles <path>` and `-help start` returned exit code 0 / no captured output in this transcript. These outputs did not validate the start selector.
- `wpr -status` returned exit code 0 with no output. No ETL file was present at `R:\\results.activation-spp-066.etl`.
- Correction to TEST-66 interpretation: Microsoft WPR documentation defines custom profile start selector as `<path>.wprp!<ProfileName>[.light|.verbose]`; the LoggingMode component in XML profile Id is selected separately with `-filemode`. Thus the correct selector for this exported profile is expected to be `R:\\activation-spp-063-profiles.wprp!FileIORegistry.Verbose` together with `-filemode`, not the full XML Id ending in `.File`. The prior claim that `.File` was necessarily part of the CLI selector was incorrect.
- No trace was started or confirmed active, no ETL was created, and no Windows configuration or activation state was changed.


## TEST-66S — WPR start collision and active recording discovery

- Corrected custom-profile start selector was issued:
  `wpr -start "R:\\activation-spp-063-profiles.wprp!FileIORegistry.Verbose" -filemode`.
- WPR returned: "The profiles are already running", Error code `0xC5583001`; PowerShell exit code `-984076287`.
- Immediately following `wpr -status` confirmed an active recording: elapsed 00:00:27, 0 dropped events, Logging mode File; status command exit 0.
- This is not evidence that the requested custom FileIORegistry profile was successfully started by this command. It establishes that a WPR file-mode recording was already active when the start request was processed. Its active profile identity/configuration is not shown by the captured status output.
- No new start should be attempted while this session is active. Do not assume the current ETL will contain the intended FileIO/Registry events until the active session is identified or the trace is stopped and inspected.
- No activation attempt was made; no system configuration change was made. Recording remains active pending immediate safe disposition.


## TEST-66T — Stop and preserve the pre-existing WPR recording

- Stopped the already-active WPR session with `wpr -stop R:\\activation-spp-066S.etl "SPP diagnostic capture - active WPR session"`.
- WPR reported "The trace was successfully saved"; stop exit code 0.
- ETL exists at `R:\\activation-spp-066S.etl`, size 710,934,528 bytes (~678 MiB); filesystem creation time 2026-11-13 16:22:15 and last-write time 16:22:33 (local system time).
- Subsequent `wpr -status` reported "WPR is not recording".
- The prior status showed an active File-mode recording, but no profile identity. The stop operation preserves that session; it does not establish that it was the intended custom FileIORegistry profile.
- No activation attempt, service/configuration change, or new WPR start occurred. ETL retained locally on R: pending offline metadata/provider inspection; do not upload raw trace because it may contain sensitive system activity and paths.


## TEST-66U — ETL analysis utility inventory

- `wpa.exe` and `xperf.exe` not found in PATH or at the standard Windows Performance Toolkit installation paths under Program Files.
- `tracefmt.exe` not found in PATH.
- Built-in `C:\\Windows\\System32\\tracerpt.exe` is present (471,040 bytes; last-write 2026-10-30 04:13:03).
- No ETL parsing or export was performed in this test; the 710,934,528-byte ETL remains unchanged on R:.
- Next step: inspect tracerpt command-line help, then use its summary-only mode to inventory the trace before considering any event export. No additional software installation is currently justified.


## TEST-66V — TraceRpt command-line capability inspection

- Built-in TraceRpt version: 10.0.26100.9818.
- Help confirms ETL input syntax and supports `-summary [filename]` for a text summary report; event dump (`-o`) and workload report (`-report`) are separate options.
- Help also supports XML/HTML reports and XML/CSV/EVTX dumps, but none were generated in this test.
- No ETL processing was performed; source ETL remains unchanged.
- Next step: generate only a summary text report on R:, without `-o` or `-report`, to avoid exporting the full event stream.


## TEST-66W — WPR ETL summary report

- Source summary published in the repository: `tmp/summary.activation-spp-066S.txt`; source ETL remains local at `R:\\activation-spp-066S.etl` and was not uploaded.
- TraceRpt processed the ETL successfully. Reported 678 buffers, 4,100,685 total events, 0 lost events, and 84 seconds elapsed. Start and end dates both reported Friday 13 November 2026; the summary output used the system's French date localization.
- Kernel FileIO provider GUID `90cbdc39-4a3e-11d1-84f4-0000f80464e3` is present. The summary includes 102,927 FileIO OperationEnd events, 23,252 Create, 621 FileCreate, 6,907 Write, 14,230 Read, 16,207 Close, 16,420 Cleanup, 15,937 QueryInfo, and additional file operations.
- Kernel Registry provider GUID `ae53722e-c863-11d2-8659-00c04fa321a1` is present. The summary includes 285,618 QueryValue, 236,067 Open, 180,004 Query, 193,875 Close, 31,291 EnumerateKey, 30,721 EnumerateValueKey, 12,812 Create, 857 SetValue, 249 DeleteValue, and other registry operations.
- Process/thread events and stack-walk events are also present (including 26 Process Start, 16 Process End, and 1,279,615 StackWalk events). Numerous ancillary providers are present, including Microsoft Antimalware providers.
- Interpretation: the saved recording contains substantial kernel FileIO and Registry activity and operation-end events, with zero reported lost events. This makes it a potentially useful source for offline correlation of process activity and file/registry operations. The summary alone does not show event payloads, status values, process IDs for individual operations, whether the active session was exactly the intended custom profile, or whether an SPP-triggered activation occurred during the 84-second interval. It therefore does not yet identify the operation responsible for `0x80070005`.
- The trace is broad and includes system-wide activity and security-product providers. Keep the raw ETL local; do not publish/upload it. The text summary is suitable for repository documentation.
- No activation attempt, service restart, ACL/permission change, Defender change, licensing-store change, or other Windows state change occurred during this summary test.

## Investigation checkpoint — transition from inventory to targeted empirical diagnosis

- Established: Windows Pro is in Notification state; automatic activation attempts launched `slui.exe` under Network Service through `SppExtComObj.exe`; Security-SPP Event 8198 records `0x80070005` and `0x8007139F`; the ProfileList Network Service ACL correction did not resolve the failure.
- Established: no demonstrated Defender block, blanket SPP store ACL defect, SPP service descriptor defect, or causal DCOM/WaaSMedicSvc denial. Do not repeat broad ACL/Defender/DCOM changes or reset the licensing store on current evidence.
- New opportunity: the local ETL summary confirms kernel FileIO and Registry operation families, including FileIO OperationEnd events and process/thread context, with zero reported lost events. The next diagnostic objective is to extract only the relevant interval/process activity and identify any failed file or registry operation associated with the SPP broker/activation process. The summary is not itself proof of an access-denied operation.
- The next phase may include controlled state-changing experiments, but each must be tied to a specific finding, narrowly scoped, reversible where possible, and followed by verification and canonical documentation. Do not repeat `/ato` merely to generate another failure; the single approved TEST-36 attempt has already been consumed. Prefer a naturally occurring activation event for correlation unless a new activation attempt is separately justified and authorized.
- Candidate sequence: (1) offline ETL event-level extraction and correlation; (2) select one specific suspected resource/API only if the trace identifies it; (3) apply one minimal reversible intervention with a saved before-state; (4) observe service/broker behavior and natural activation result; (5) verify whether the notification state and Event 8198 outcome changed. If ETL cannot be parsed adequately with built-in tools, reassess the least invasive local analysis option before installing additional tooling.


## TEST-67 — Initial direct ETL read attempt (incomplete)

- User attempted a bounded PowerShell read of `R:\activation-spp-066S.etl` using `Get-WinEvent -Path ... -MaxEvents 8`.
- Windows PowerShell rejected the request because ETL/EVT files require forward chronological reading and the `-Oldest` parameter.
- No event records were read; no ETL modification, export, or Windows configuration change occurred.
- This is a command-parameter correction, not evidence of ETL corruption or unreadability.
- Retry as TEST-67R with `-Oldest -MaxEvents 8`.


## TEST-67R — Direct ETL read in chronological order

- `Get-WinEvent -Path R:\activation-spp-066S.etl -Oldest -MaxEvents 8` succeeded and returned eight records.
- All eight records were timestamped 2026-11-13 16:20:51 local. `ProviderName` was blank, `Id` was 0, `LevelDisplayName` was Information, and `Message` was blank for all eight.
- Three records exposed `ProcessId=10016`, `ThreadId=3268`; five exposed process/thread ID zero.
- The ETL is readable by this cmdlet, but these initial records are not usefully decoded by the displayed fields. This does not establish that the kernel FileIO/Registry payloads are inaccessible or absent.
- Next inspect the full metadata and XML of one record before choosing an extraction route. No Windows state or ETL content was changed.

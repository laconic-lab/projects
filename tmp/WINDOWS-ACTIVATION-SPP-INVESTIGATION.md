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

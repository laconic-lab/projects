# Dell Precision M4800 — Windows Integrity, Subsystem Failures & Recovery Assessment

**Document ID:** M4800-WINDOWS-INTEGRITY-RECOVERY  
**Version:** 1.0  
**Record date:** 2026-11-13  
**Status:** CONSOLIDATED ASSESSMENT — DIAGNOSIS PAUSED FOR RECOVERY DECISION; NO RESET / REINSTALL AUTHORIZED  
**System:** Dell Precision M4800 · Windows 11 Pro 25H2 · x64 · build 26200.9974 (latest recorded OS build)  
**Purpose:** One cross-issue handoff that separates the M4800's known failures, avoids false causal links, and evaluates whether Windows recovery is now justified.

> This is the new top-level handoff and decision document. It does not replace the detailed test histories. The two issue-specific audits linked below remain the authoritative evidence registers for their respective branches. This document is the place to understand the machine-wide situation and decide the next recovery strategy.

---

## 1. Executive assessment

The M4800 is in a **materially degraded and poorly understood Windows state**. Several important Windows subsystems have independently exhibited failures:

- Windows servicing could not install KB5132061 and encountered component-store payload corruption / missing repair content.
- Windows activation remains in Notification mode, with repeated SPP access-denied errors.
- Windows Search repeatedly failed to initialize, reporting a temporary-directory failure; later, its data directory disappeared, with no process attribution established.

That is enough to justify considering a controlled Windows recovery operation rather than continuing an open-ended sequence of narrow diagnostic tests.

It is **not yet enough to conclude that Windows is irreparable**, that all three problems share one root cause, or that a clean installation is the only viable option. The observed failures have different timestamps, mechanisms and evidence. No causal chain between servicing, activation and Search has been demonstrated.

### Current recommendation

**Prepare for a recovery decision, but do not launch recovery yet.**

The preferred decision sequence is:

1. Preserve the investigation records and any remaining diagnostic artifacts.
2. Confirm the user's data and application backup position, plus the exact recovery media / installation source available.
3. Decide whether a supported in-place repair installation is viable on this unsupported-hardware M4800 and whether it is likely to preserve the required applications and configuration.
4. If an in-place repair is unsuitable or fails, compare Reset this PC and a clean installation as separate, more destructive options.
5. Before any operation, document its expected effect on files, applications, settings, drivers, activation and the ability to boot / recover.

No recovery action is authorized by this assessment.

---

## 2. System baseline and scope

| Item | Latest recorded information |
|---|---|
| Hardware | Dell Precision M4800 |
| OS | Windows 11 Pro 25H2, x64 |
| Latest recorded build | 26200.9974 |
| Previous build in servicing investigation | 26200.9818 |
| Windows installation history | User reports Windows 11 installed 2025-03-10 using Rufus and a hardware-requirement bypass; originally installed 24H2, later upgraded to 25H2 |
| TPM / compatibility | Earlier Panther compatibility evidence marked TPM 2.0 as a hard block |
| Activation | Notification mode; not successfully reactivated |
| Windows Search | WSearch currently stopped; latest manual start failed with Win32 exit code 3 |
| Component store | Earlier DISM scan reported CSI payload corruption; later RestoreHealth repaired 107/110 detected payloads but ended with 0x800f0915 |
| Recovery state | No reset, repair-install or clean-install operation recorded in these investigations |

The machine's unsupported-hardware installation history is relevant to future Windows Setup compatibility checks. It does not prove that repair installation is impossible, but it means the compatibility path must be verified before starting Setup.

---

## 3. Separate incident branches

### 3.1 Windows servicing and component store — KB5132061

**Detailed evidence register:** [KB5132061_for_M4800.md](https://github.com/laconic-lab/projects/blob/main/tmp/KB5132061_for_M4800.md)

Key established findings:

- The machine was on build 26200.9818 during the original November 11 servicing investigation. KB5132061 targeted build 26200.9974.
- The attempted KB5132061 installation failed with **0x800f0993**, and CBS/CSI evidence identified missing target-version IIS FTP Service `ftpsvc.dll` hydration candidates.
- A separate WUSA extraction-only attempt failed with **0x80070057** (invalid parameter). This did not establish that the MSU itself was corrupt.
- A later online `DISM /Online /Cleanup-Image /RestoreHealth` attempt failed with **0x800f0915 / CBS_E_REPAIR_CONTENT_MISSING**.
- The correlated CBS session reported 110 CSI payload corruptions and repaired 107. Three audio-codec payload entries remained unresolved: two DolbyDecMFT entries (amd64 and WOW64) and one msmpeg2ac3dec entry.
- CBS explicitly recorded the installed baseline 10.0.26100.9818 IIS FTP Service `ftpsvc.dll` payload as fixed. This does not prove that the target 10.0.26100.9974 hydration candidate is available.
- The audit's last recorded decision was to hold further servicing remediation pending specific evidence / updated guidance. Do not treat that earlier hold as proof that the current component store is healthy.

**Assessment:** There is real servicing/component-store damage evidence, but the later repair operation improved the state. The unresolved codec payloads and original target-build hydration question must not be collapsed into a claim that all Windows components are corrupt.

**Do not:** retry KB5132061/KB5043080, rerun DISM/SFC, replace WinSxS files, reset Windows Update caches, or perform speculative component repair as part of this recovery assessment.

### 3.2 Windows activation and Software Protection Platform (SPP)

**Detailed evidence register:** [WINDOWS-ACTIVATION-SPP-INVESTIGATION.md](https://github.com/laconic-lab/projects/blob/main/tmp/WINDOWS-ACTIVATION-SPP-INVESTIGATION.md)

Key established findings:

- Windows was reportedly activated before the November 2026 servicing incident. The user's prior legitimate activation / digital entitlement has not been shown to be revoked or lost.
- Current recorded licensing state is **Notification**. `slmgr /xpr` reported Notification mode; the installed partial key ends in `3V66T`, which is the generic Windows Pro setup key suffix and does not establish whether the user's entitlement is absent.
- Earlier activation attempts returned **0x80070005**. On 2026-11-14 the user subsequently ran `slmgr.vbs /rilc` and `slmgr.vbs /ipk` with a Windows 11 Pro key; `/rilc` initiated licensing-file reinstallation/reinitialization and `/ipk` accepted the supplied key. A later `/ato` was attempted but did not complete activation. The user requested that the reason/result details of that manual attempt not be included in this document. A separate automatic activation / troubleshooting path still reports **0x80070005**.
- The ProfileList Network Service ACL discrepancy was corrected under explicit approval (TEST-35R), but the subsequent approved activation attempt still failed.
- Defender investigation did not demonstrate that Defender blocked SPP.
- Sysmon correlated three automatic Security-SPP Event 8198 failures on November 13 with short-lived `slui.exe` processes launched by `SppExtComObj.exe` as **NT AUTHORITY\NETWORK SERVICE**.
- This identifies the process identity and launch path, but not the exact denied file, registry key, COM/RPC endpoint, WMI operation, database or other resource.
- The observed DCOM Default Access Permissions already contained SELF. No DCOM permission change was justified.
- SPP scheduled tasks and the Microsoft-signed `sppcext.dll` registration were found present; no demonstrated task/registration defect justified repair.

**Assessment:** Activation remains unresolved. The licensing-file reinstallation and key installation commands were accepted / initiated, but Windows activation has not been confirmed. A separate automatic activation / troubleshooting path still reports 0x80070005. The evidence narrows the execution path but does not prove that the activation failure is caused by the component-store or Search problems.

**Do not:** repeat `/ato`, retry or replace product keys, run `slmgr /upk`, rearm, reset the licensing store, change DCOM permissions, or modify SPP service / registry ACLs without a separate reviewed plan and explicit approval.

### 3.3 Windows Search subsystem

**Evidence source:** Windows Search investigation recorded in the November 13 conversation; this branch is consolidated here pending a dedicated standalone audit if investigation resumes.

Key established findings:

- On November 12 at 01:59:42, Windows Search Event 3030 reported **0x80070660** and a French message stating that the drive containing the temporary directory was full or inaccessible, or that write access was unavailable.
- The same startup cycles produced TripoliIndexer / gatherer initialization failures and later **0x80070005** access-denied events. These may be dependent failures; the logs do not identify the denied object.
- The Search service repeatedly stopped after failed initialization.
- On November 13, the service was observed Stopped / Manual and runs as LocalSystem. Its image path was `C:\Windows\System32\SearchIndexer.exe /Embedding`.
- A manual start attempt at approximately 21:19:30 failed with Win32 exit code **3** (path not found). Do not repeat the start attempt yet.
- At approximately the same time, NTFS USN journal records showed deletion of the Search `Data` directory and then the parent `Search` directory under `C:\ProgramData\Microsoft`. The USN records do not identify the process, executable, user or service responsible.
- Defender Operational and Security object-access queries supplied for that time window did not identify the deletion actor. Their lack of matching events does not prove that no process performed the deletion.
- The Search registry configuration still pointed to `%ProgramData%\Microsoft\Search\Data\` after the directory disappeared.
- A narrow inheritance repair was performed on two Search child directories before the deletion was observed. No evidence establishes that this ACL repair or WSearch caused the deletion.
- The historical TEMP/TMP chronology matters: on November 11, TEST-28 documented a full reboot after which Process/User TEMP/TMP were on C: and Machine TEMP/TMP were `C:\Windows\TEMP`, with both directories present and substantial free space. The first recorded Search 3030 was later, on November 12. Therefore, the earlier `R:\Temp` DISM scratch failure is **not established as the cause** of the Search failure.
- The RAM-drive scratch path `R:\Temp` is confirmed as the cause of the earlier DISM error 112 in TEST-23/24B. That is a separate confirmed finding, not proof of the Search root cause.

**Assessment:** Windows Search has a serious unresolved startup / data-path failure. The original temporary-directory cause remains unknown, and the later Search directory deletion is unattributed. The evidence does not justify recreating the directory, resetting its ACL tree or starting WSearch before a recovery decision.

**Do not:** start WSearch again, recreate/delete Search data, reset recursive ACLs, change TEMP/TMP, or run a SYSTEM-context test task until a specific plan is reviewed.

---

## 4. Cross-incident chronology and causal discipline

| Time | Branch | Confirmed event | What it does not prove |
|---|---|---|---|
| Nov 11, 17:31 | Servicing | DISM TEST-23 failed with error 112 while using `R:\Temp` as scratch | Does not establish the cause of later Search or activation failures |
| Nov 11, after TEST-23 | Environment | User/Machine TEMP/TMP reset to C:; stale process environment persisted temporarily | Does not prove what every service process used |
| Nov 11, after full reboot | Environment | TEST-28 recorded Process/User TEMP/TMP on C: and Machine TEMP/TMP at `C:\Windows\TEMP` | Does not reconstruct the exact environment of a service process many hours later |
| Nov 11, 22:19–22:20 | Servicing | RestoreHealth repaired 107/110 CSI payload issues, including installed 9818 `ftpsvc.dll`, then failed 0x800f0915 | Does not prove target 9974 hydration content was repaired |
| Nov 12, 01:59 | Search | First recorded Event 3030 / 0x80070660 | Does not establish R: as the cause |
| Nov 12, 20:31 | Activation | First documented activation failure in the activation audit | Does not establish that KB5132061 caused the activation failure |
| Nov 13, 20:33 | Activation | Sysmon correlated automatic SPP failures to `slui.exe` running as Network Service | Does not identify the denied resource |
| Nov 13, 21:19 | Search | WSearch start failed with path-not-found; USN records showed Search/Data and Search directory deletion | Does not identify the deleting process or establish that WSearch deleted them |

**Causal rule:** temporal proximity is not proof of causation. The servicing, activation and Search branches remain separate unless new evidence demonstrates a shared failing component or operation.

---

## 5. Is Windows recovery now justified?

**Yes — planning a recovery path is justified. Starting recovery immediately is not yet justified.**

The combination of unresolved activation, servicing and Search failures creates a reasonable threshold for preparing a controlled repair strategy. Continuing indefinitely with more isolated tests has diminishing value, especially where the exact failing operation is unknown.

However, each recovery option has different consequences:

| Option | General effect | Relative disruption | Current position |
|---|---|---:|---|
| Repair install / in-place upgrade | Reinstalls Windows while potentially preserving personal files, applications and settings, depending on method and compatibility | Lower than reset / clean install | **First option to assess**, not yet approved |
| Settings → System → Recovery → Fix problems using Windows Update (if offered) | Reinstalls the current Windows version to repair system components; availability and behavior depend on the installed build and configuration | Moderate | Assess whether available and applicable; do not assume it will resolve activation or all servicing issues |
| Reset this PC — Keep my files | Reinstalls Windows, retains personal files but removes applications and resets many settings | High | Fallback only after backup and application inventory |
| Reset this PC — Remove everything | Reinstalls Windows and removes personal files, applications and settings | Very high | Not preferred while less destructive routes remain viable |
| Clean installation from installation media | Fresh OS installation; applications and settings must be rebuilt; data must be restored | Highest | Last resort / deliberate rebuild |

These descriptions are general Windows recovery behavior, not a guarantee that every option will be offered or work on this unsupported-hardware machine. Before selecting any option, verify the exact Windows 11 installation media/build, edition, language, architecture, driver availability, activation entitlement, and hardware compatibility path.

### Why not immediately use Reset this PC?

A reset may repair some operating-system files, but it can also remove applications, settings and driver configuration. It may not resolve an activation entitlement / licensing authorization problem. It could also make the existing evidence harder to investigate. It is therefore not the automatic first choice.

### Why consider an in-place repair first?

An in-place repair can replace Windows system components while preserving applications and user data when the chosen Setup path supports those choices. It is the least disruptive broad recovery candidate. But this M4800 has an unsupported TPM / compatibility history, so the actual Setup compatibility result and available keep options must be checked before committing.

---

## 6. Pre-recovery gates — no action until reviewed

Before any repair install, reset or clean install:

1. **Data protection:** identify the actual backup destination and verify that important user files are readable from it. A backup is not confirmed merely because a copy command completed.
2. **Application inventory:** record installed applications, installers, license/activation requirements, configuration and data locations. Distinguish reinstallable applications from applications whose configuration or data is difficult to reconstruct.
3. **Device / driver readiness:** inventory required M4800 drivers, especially chipset, storage, network, graphics and audio. Confirm that required installers are available offline if network connectivity is lost.
4. **Windows identity:** confirm edition, language, architecture, current build, activation state and installation media identity. Do not expose product keys or other secrets in logs.
5. **Recovery source:** verify the exact ISO/media source, its authenticity, edition/language compatibility and build/release. Do not assume an older ISO is a suitable repair source.
6. **BitLocker / device encryption:** inspect protection state and ensure recovery-key availability before any operation that may change boot configuration. Do not publish recovery keys.
7. **Power and storage:** ensure stable AC power and sufficient free space for the selected operation.
8. **Keep-option confirmation:** read the actual Windows Setup screen and verify whether “keep personal files and apps” is offered. Stop if the offered option differs from the intended plan.
9. **Rollback boundary:** document what can and cannot be rolled back. A reset or clean install must be treated as destructive unless a verified backup exists.
10. **Explicit authorization:** present the exact operation, expected consequences and fallback plan for approval before starting it.

No commands to initiate recovery are included in this document.

---

## 7. Current hold list

Until a recovery strategy is selected:

- Do not run further activation attempts or change the SPP licensing store.
- Do not retry KB5132061 / KB5043080 or run additional DISM/SFC repair attempts.
- Do not restart Windows Search, recreate its data directory or reset its ACLs.
- Do not change TEMP/TMP or the RAM-drive configuration to test a theory.
- Do not perform broad registry, service, DCOM, security or ACL repairs.
- Do not reset Windows, reinstall Windows or launch Setup as an experiment.
- Preserve existing logs, MSU files, test directories and repository records.

This is a deliberate decision pause, not a claim that the machine is stable or healthy.

---

## 8. Next practical step

The next step should be a **recovery-readiness review**, not another diagnostic test:

- confirm what data is already backed up and where;
- establish which applications and configurations must be preserved;
- determine which Windows 11 25H2 / 26200.9974 installation media is available;
- assess whether an in-place repair path can retain applications on this M4800 despite the TPM compatibility block;
- then choose between in-place repair, Reset this PC, or clean installation.

Once those facts are known, prepare one exact recovery plan and stop before execution for user approval.

---

## 9. Related canonical records

- [Windows Activation / SPP Investigation](https://github.com/laconic-lab/projects/blob/main/tmp/WINDOWS-ACTIVATION-SPP-INVESTIGATION.md) — detailed activation tests, SPP process attribution, ACL and DCOM evidence.
- [KB5132061 for M4800](https://github.com/laconic-lab/projects/blob/main/tmp/KB5132061_for_M4800.md) — detailed Windows Update, DISM, CBS, component-store and package investigation.
- [Search ACL backup record](https://github.com/laconic-lab/projects/blob/main/tmp/Search-Data-ACLs.txt) — DACL capture for the Search data tree before the later directory disappearance.

---

## 10. Handoff instructions

A new session must read this assessment first, then read the relevant detailed branch before proposing any action.

- Treat this file as the cross-incident status and recovery decision record.
- Treat the activation and KB5132061 files as detailed historical evidence registers, not as proof of current state after subsequent changes.
- Do not repeat completed tests.
- Do not infer a common root cause without direct evidence.
- Keep all recovery operations behind the pre-recovery gates and explicit user approval.
- Update this assessment whenever a branch materially changes or a recovery decision is made.


---

## 11. Recovery action log — KB5132061 rollback and post-reboot observations

**Record date:** 2026-11-14  
**Operation:** User-initiated uninstall of the November 2026 Security Update KB5132061 through Windows Settings, followed by a reboot.  
**Evidence level:** User-reported post-operation observations; no post-rollback package/build/event-log inspection has yet been performed.

### Action sequence and results

| Sequence | Action / observation | Result | Evidence status |
|---|---|---|---|
| 1 | User opened Settings → Windows Update → Update history → Uninstall updates. | UI listed KB5054156 (25H2 Enablement Package, installed 2026-07-01), KB5127690 (Microsoft Windows update, installed 2026-10-14), and KB5132061 (Security Update, installed 2026-11-13). | Screenshot supplied by user in conversation. |
| 2 | User initiated uninstall of KB5132061. | The uninstall progress dialog was visible. At that point completion had not yet been established. | Screenshot supplied by user. |
| 3 | User allowed the reboot process to complete. | User subsequently reported: **“reboot done.”** | User report, 2026-11-14. |
| 4 | Post-reboot activation check. | User reports the activation licence/state is **still in error**. No new activation code, event details or entitlement check were supplied in this update. | User-reported result; exact current licensing state not independently re-collected. |
| 5 | Post-reboot Windows Search check. | User reports Windows Search **still cannot start**. No new service output, error code or directory inspection was supplied in this update. | User-reported result; exact current service error not independently re-collected. |

### Interpretation

1. The attempted KB5132061 uninstall and subsequent reboot did **not**, according to the user's immediate post-reboot checks, restore either activation or Windows Search to working condition.
2. This weakens the simple hypothesis that the currently installed KB5132061 binaries alone are the complete cause of both failures, and that removing that update would automatically reverse them.
3. The user's proposed interpretation is plausible: uninstalling an update may revert or remove package binaries and registrations without repairing an independently damaged authorization state, licensing store, permissions, service configuration, or Search data-path state.
4. However, the current evidence does **not** establish that the uninstall removed only binaries, that activation's underlying authorization state is the specific damaged object, or that the two failures share one cause. The actual post-uninstall package state and detailed subsystem errors have not yet been inspected.
5. The prior activation evidence remains relevant but is not a fresh post-rollback measurement: Notification mode, earlier SPP Event 8198 failures, 0x80070005, and the SppExtComObj.exe → slui.exe Network Service execution path were previously observed. The exact denied resource remained unknown.
6. The prior Search evidence also remains historical: WSearch start previously failed with Win32 exit code 3, and NTFS USN records showed deletion of the Search Data and parent Search directories without identifying the deleting process. The current report that Search still cannot start is consistent with persistence of that problem, but its present error and filesystem state are not yet confirmed.
7. No evidence currently demonstrates that KB5127690 caused either remaining failure. It is a separate .NET Framework 3.5 / 4.8.1 security update, not the November Windows cumulative security update. It was **not** reported as uninstalled and should remain untouched unless separate evidence implicates it.
8. KB5054156 is the earlier Windows 11 25H2 Enablement Package and was not reported as uninstalled.

### Action boundary / current hold

- Record KB5132061 as **user-initiated uninstall followed by completed reboot; activation and Search remain reported as failing**. Do not mark the rollback as a successful system repair.
- Do not uninstall KB5127690 or KB5054156 as an experiment.
- Do not repeat activation attempts, change product keys, reset the licensing store, or modify SPP / DCOM / ACL settings.
- Do not start WSearch again, recreate its data directory, or reset Search ACLs without a separate reviewed plan.
- Do not rerun DISM/SFC, retry KB5132061, reset Windows Update caches, or initiate another repair/reinstall operation as part of this rollback.
- The next evidence collection, if approved, should be read-only and should first establish the actual post-rollback OS build and KB/package state, then capture the exact current activation status/error and Search service start error/path state. Collect one bounded set of evidence before proposing any repair.

### Current verdict after KB5132061 rollback

**ROLLBACK / REBOOT: USER REPORTS REBOOT COMPLETED. ACTIVATION: STILL IN ERROR. WINDOWS SEARCH: STILL UNABLE TO START. THE ROLLBACK DID NOT RESTORE THESE TWO SUBSYSTEMS TO WORKING CONDITION. THE UNDERLYING CAUSE AND EXACT POST-ROLLBACK PACKAGE STATE REMAIN UNVERIFIED. NO FURTHER REPAIR OR UPDATE REMOVAL AUTHORIZED.**


---

## 12. Activation action log — licensing-file reinstallation and key installation

**Record date:** 2026-11-14  
**Operation:** User-performed Software Protection Platform commands following the KB5132061 rollback.  
**Evidence level:** Commands and results reported directly by the user. The actual product key is intentionally not recorded.

### Commands and results

| Sequence | Command / action | Result |
|---|---|---|
| 1 | `slmgr.vbs /rilc` | Initiated licensing-file reinstallation / reinitialization. After some time, a Windows dialog opened and displayed a process reinitializing numerous files. User reports that this operation proceeded. |
| 2 | `slmgr.vbs /ipk [redacted Windows 11 Pro key]` | Windows accepted the supplied key through PowerShell. The key value is deliberately omitted from this record. |
| 3 | `slmgr.vbs /ato` | Attempted after key installation, but did not complete activation. Detailed result intentionally omitted at the user's request. |

### Additional activation error still observed

The user reports that system / activation troubleshooting continues to show a separate failure:

- **Error:** 0x80070005 (Access denied).
- **Message:** License Activation (slui.exe) failed with the following error code: hr=0x80070005.
- **Command-line context:** RuleId=3482d82e-ca2c-4e1f-8864-da0267b484b2; Action=AutoActivate; AppId=55c92734-d682-4d71-983e-d6ec3f16059f; SkuId=4de7cb65-cdf1-4de9-8ae8-e3cce27b9f2c; NotificationInterval=1440; Trigger=NetworkAvailable.

This 0x80070005 report is recorded separately from the manual activation attempt. The precise resource denied by the automatic activation / troubleshooting path remains unidentified. Do not assume the two paths have the same cause.

### Interpretation and status

1. `/rilc` was used to reinstall / reinitialize licensing files. This is a material change to the licensing subsystem and must be included in the activation investigation chronology.
2. `/ipk` accepted the supplied Windows 11 Pro key. Acceptance by the command does not itself establish successful activation or entitlement validity.
3. `/ato` was attempted but did not complete activation; detailed result is intentionally omitted at the user's request.
4. A separate automatic activation / troubleshooting path continues to report **0x80070005**. Its denied object or operation has not been identified.
5. The previous SPP process-path observations remain historical context; no new process attribution or ACL diagnosis is established by these command results.
6. This action log intentionally excludes the user's explanation for the key's status and any organizational / subscription history.

### Current action boundary

- Record `/rilc` and `/ipk` as initiated / accepted, respectively; record `/ato` as attempted but unsuccessful.
- Do not store or reproduce the actual product key in repository documentation, logs or chat transcripts.
- Do not repeat activation attempts, change keys, run `/upk`, rearm, reset the licensing store, or modify SPP / DCOM / ACL settings without a separately reviewed plan and explicit approval.
- Treat the separate **0x80070005** automatic activation / troubleshooting error as unresolved; its denied resource is unknown.
- Windows Search remains separately reported as unable to start; these licensing commands do not establish any change to Search.

### Current activation verdict

**LICENSING FILE REINSTALLATION: INITIATED VIA /RILC. PRODUCT KEY INSTALLATION: ACCEPTED VIA /IPK. MANUAL ACTIVATION: ATTEMPTED BUT NOT SUCCESSFUL (DETAILS OMITTED AT USER REQUEST). SEPARATE AUTOMATIC ACTIVATION / TROUBLESHOOTING ERROR: 0x80070005 STILL REPORTED. WINDOWS ACTIVATION IS NOT CONFIRMED.**

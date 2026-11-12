# Windows VM Disposable I/O, RAM-Backed Temporary Storage and SSD Lab

**Platform:** Steam Deck OLED / SteamOS / rootless Podman / Dockur Windows / QEMU/KVM  
**Guest:** Windows 11 Pro 24H2, build 26100 (user-confirmed)  
**Document type:** Experimental lab plan and evidence register  
**Status:** LAN noVNC access verified; replacement-guest groundwork and read-only storage analysis in progress; no tuning experiments applied  
**Priority:** Understand the I/O and memory model and collect baselines before removing the current guest or creating its replacement. Protect SteamOS and the Steam Deck NVMe first.

## 1. Purpose

This Windows VM is a disposable laboratory for learning and testing QEMU, KVM, rootless Podman and Dockur. It is not a precious workstation installation. The user is comfortable discarding a damaged guest and creating a fresh one rather than spending time repairing a compromised or confusing experimental state.

The lab will investigate whether selected Windows write-heavy and disposable data can be moved to memory-backed storage, whether the Windows pagefile can be reduced or disabled safely for this workload, and how Windows SSD optimization and TRIM behave through the virtual-disk stack.

The guiding rule is:

> Never endanger the Steam Deck. Windows performance or convenience is secondary to host stability, free storage, memory headroom and safe host operation.

This document is an experiment plan, not a claim that any proposed optimization is already active or recommended.

## 2. Explicit disposable-VM policy

- Do not create Windows guest backups, snapshots or copies of `data.img`.
- Do not create routine copies of the VM configuration scripts unless the user explicitly requests a specific configuration backup.
- Preserve important configuration parameters, environment-variable names, image digest, command procedures, measurements and test results in project documentation.
- If the guest becomes damaged, diagnose the cause where useful; prefer creating a fresh guest over attempting prolonged repair.
- Recreating a container wrapper while retaining the current guest disk is a separate operation from discarding/rebuilding the guest. Confirm the intended scope before either.
- Do not delete or alter the Steam Deck host's swap, zram, memory settings, filesystem, NVMe configuration or system services as a Windows optimization.
- No automated VM startup, background tuning or host-level write-cache experiment is authorized by this document.

The existing `backups/` directory is historical project structure only; it is not an instruction to create VM backups. It may remain unused.

## 3. Current architecture and storage path

```text
Windows 11 guest
  C:\
   +-- pagefile.sys
   +-- Windows\Temp
   +-- Users\<user>\AppData\Local\Temp
   +-- caches, logs, update and servicing data
          |
          v
QEMU virtual disk
  /storage/data.img (raw, growable)
          |
          v
Podman bind mount
  /home/deck/WindowsVM/storage/data.img
          |
          v
Steam Deck host filesystem
  /dev/nvme0n1p8 mounted at /home
          |
          v
Physical NVMe SSD
```

Windows guest filesystems and paths are inside the virtual disk. Windows does not directly manage the Steam Deck's physical NVMe device. Guest writes are stored in the host-backed raw image. A guest delete, pagefile write or temporary-file write therefore has an effect on the host file and its backing filesystem allocation.

The current image is raw and growable, not fully preallocated. The logical virtual capacity is not the same as the host blocks currently allocated.

## 4. Baseline evidence — 2026-11-12

### 4.1 Steam Deck host storage and memory

User supplied the following read-only output while `windows-box` was running:

| Measurement | Observed value | Interpretation |
|---|---:|---|
| `data.img` allocated usage (`du -h`) | 8.5 GiB | Host blocks currently attributed to the image |
| `data.img` apparent size | 128 GiB | Logical file capacity |
| Host filesystem | `/dev/nvme0n1p8` | Backing filesystem for the VM directory |
| Host filesystem size | 939 GiB | Reported total |
| Host filesystem used | 441 GiB | Point-in-time usage |
| Host filesystem available | 498 GiB | Point-in-time free capacity |
| Host filesystem usage | 47% | Point-in-time percentage |
| Host RAM total | 14 GiB | Host-wide memory |
| Host RAM used | 11 GiB | Host-wide reading while VM running |
| Host RAM available | 3.0 GiB | Important headroom constraint |
| zram swap | 7.2 GiB total / 1.1 GiB used | SteamOS host swap device |
| Disk-backed host swapfile | 1 GiB total / 3.6 MiB used | SteamOS host swapfile |
| `nvme` utility | `/usr/bin/nvme` | Available for a future read-only health check |
| `smartctl` utility | `/usr/bin/smartctl` | Available for a future read-only health check |

These are point-in-time readings, not long-term wear measurements. Host memory used/available does not reveal the Windows guest's internal memory commitment or pagefile use. Do not infer that all 6 GiB configured guest RAM is permanently resident in host physical memory from the VM setting alone.

**Resource caution:** the host reported only 3.0 GiB available while the 6 GiB guest was running. Do not increase guest RAM or allocate a large RAM disk until a better host/guest memory baseline is collected and the noVNC workflow is complete. A RAM disk competes with Windows applications and the host for finite physical memory; it is not free storage.

### 4.2 Windows guest inspection status

The initial PowerShell inspection block was mistakenly entered into the SteamOS Bash shell over SSH. Bash reported `Write-Host: command not found`, `Get-CimInstance: command not found` and related errors.

**No PowerShell inspection ran and no Windows setting was changed by that attempt.** Re-run the PowerShell commands inside the Windows guest, in PowerShell (preferably elevated where required), after LAN noVNC access is working.

Current guest findings for pagefile configuration, TEMP/TMP locations, virtual disk media type, TRIM status and scheduled optimization are all **UNKNOWN / NOT TESTED**.

## 5. Technical questions and candidate experiments

### 5.0 Proposed replacement-guest resource envelope

The next guest is currently proposed at 4 vCPUs, 8 GiB RAM and a 72 GiB growable raw disk. These are draft values, not a deployment approval.

The previous guest used 6 GiB RAM and a 128 GiB logical disk. Its earlier host-memory reading showed only 3.0 GiB available while running; that is a historical point-in-time reading, not a current measurement. Before assigning 8 GiB, collect fresh host idle and guest-running memory/PSI/swap readings. Keep RAM_CHECK=Y. Do not add a RAM disk or enable ballooning at the same time as the initial 8 GiB change.

Dockur documents optional BALLOONING controls. Ballooning can return guest memory to the host under pressure, but it can also impose memory pressure inside Windows and is not guaranteed to reclaim memory instantly. It is a separate, later experiment requiring guest balloon-driver verification. No ballooning experiment is run or approved by this plan.

The 72 GiB disk setting describes the guest disk's logical capacity. With ALLOCATE=N, the raw image remains growable/sparse; it does not reserve all 72 GiB immediately. Actual host allocation still depends on guest writes, filesystem allocation and discard behavior.

The user specifically wants to investigate volatile system/user temporary storage (including RAM-disk options such as the toolkit they referred to as “AIM Toolkit”) and whether `pagefile.sys` can be reduced or eliminated in this disposable guest. The exact RAM-disk product name is not yet confirmed. No tool has been selected or installed.

### 5.1 RAM-backed temporary storage

A Windows RAM disk can provide a volatile drive whose contents disappear when the RAM disk is removed or the guest shuts down/crashes. Selected temporary directories or application caches could potentially be redirected to it.

Candidate targets, to be considered separately:

- User temporary directory: `%TEMP%` and `%TMP%`.
- System temporary directory: `C:\Windows\Temp`.
- Selected application caches that are explicitly safe to recreate.
- Build/conversion scratch space only if the relevant application supports a volatile target.

Do not move every cache or all of `AppData` by default. Some installers, Windows servicing operations, update workflows, applications and recovery operations may expect temporary data to persist across a reboot or may require more space than available in RAM.

A RAM disk must be created early enough for the configured paths to exist before dependent services use them. Its capacity must be conservative and justified by measured free/available guest memory. Avoid a RAM disk that causes Windows to page more heavily, because that can increase rather than reduce disk writes.

**Experiment sequence:**

1. Measure guest memory, commit limit, current commit, available memory and current temporary-directory sizes.
2. Identify a RAM-disk implementation compatible with the Windows guest and confirm its lifecycle, driver, licensing, persistence and crash behavior.
3. Start with a small, non-critical user TEMP test directory; do not redirect system TEMP first.
4. Verify the application works, the directory is actually on volatile storage, and the expected data disappears after a controlled guest restart.
5. Measure guest memory pressure and host memory headroom before/after.
6. Only then consider a separate system TEMP experiment with a clear recovery path.
7. Do not redirect Windows Update/servicing scratch paths until their persistence requirements and supported configuration are understood.

A RAM disk is a lab option, not an automatic best practice. The host safety budget takes precedence over reducing guest writes.

### 5.2 Windows pagefile

The pagefile is guest-managed virtual memory backing and may also be involved in crash-dump support. Its size and usage depend on Windows commit requirements, workload, memory pressure and dump configuration.

The user's preference is to investigate reducing or eliminating `pagefile.sys` because the VM is disposable and guest temporary state does not need preservation. This is a valid experiment to evaluate, but it is not yet a recommendation.

Potential trade-offs:

- Disabling the pagefile does not create additional physical RAM.
- Applications and Windows components can fail when the system commit limit becomes insufficient.
- A RAM disk consumes memory and can make commit pressure worse.
- Some crash-dump types require a pagefile or a dedicated dump file with appropriate sizing.
- Pagefile activity is not necessarily constant; measure actual current/peak usage under representative tasks before deciding.
- A smaller system-managed or explicitly bounded pagefile may be a safer intermediate experiment than immediate removal.

**Experiment sequence:**

1. Record `AutomaticManagedPagefile`, pagefile path, allocated size, current usage and peak usage.
2. Record total/available guest RAM, committed bytes and commit limit during idle and representative UUP conversion work.
3. Confirm crash-dump configuration and decide whether guest crash dumps are useful to this lab.
4. Test system-managed configuration as the baseline.
5. If measurements justify it, test a smaller pagefile in a disposable guest, one change at a time.
6. Only test no pagefile after the smaller-pagefile test, and only with an explicit acceptance that guest applications may fail or the guest may become unstable under memory pressure.
7. Record workload, duration, errors, commit headroom and whether a restart was required.

Do not change SteamOS swap or zram to influence the guest pagefile. They are separate memory-management layers.

### 5.3 SSD identification, TRIM and Optimize Drives

Windows sees a virtual disk device, not the physical NVMe directly. Its reported media type and the virtual device's discard/unmap capabilities must be inspected. The complete path is:

`Windows filesystem -> virtual disk device -> QEMU/Dockur disk backend -> raw image -> host filesystem -> NVMe`.

Windows may schedule Optimize Drives. For SSD-class devices, this is not equivalent to repeatedly performing legacy HDD-style defragmentation; Windows can issue retrim operations and perform storage maintenance. Do not disable the scheduled task merely because its name contains “Defrag”.

The following remain unverified for this exact pinned image and deployed guest:

- What media type Windows detects for the virtual disk.
- Whether guest TRIM is enabled.
- Whether discard/unmap is enabled in the QEMU virtual disk configuration.
- Whether discard requests propagate through QEMU and the host filesystem to the sparse raw image.
- Whether Windows scheduled optimization runs and what action it performs.
- Whether the current host filesystem and storage stack reclaim the corresponding blocks after guest deletion.

Do not run a manual retrim, host `fstrim`, discard experiment or QEMU cache-mode change as part of the initial read-only audit. First establish the configuration and current state.

### 5.4 Host NVMe health and write monitoring

The host has both `nvme-cli` and `smartmontools` installed. A future read-only health audit can inspect the controller's reported health, percentage used, data units written, critical warnings, media errors and temperature, where supported.

A single SMART/NVMe reading is a baseline, not proof of wear rate. To estimate workload impact, compare counters over a known period with the VM idle and during a representative workload. Record the exact counter units and avoid comparing unlike counters.

Do not use destructive self-tests, firmware updates, secure erase, sanitize, namespace changes or host filesystem changes in this lab.

## 6. Windows baseline commands — run inside the guest

These are PowerShell commands, not Bash. Run them inside the Windows VM, not in the Steam Deck SSH shell.

```powershell
Write-Host "===== PAGEFILE USAGE ====="
Get-CimInstance Win32_PageFileUsage |
    Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

Write-Host "`n===== PAGEFILE CONFIGURATION ====="
Get-CimInstance Win32_ComputerSystem |
    Select-Object AutomaticManagedPagefile

Get-CimInstance Win32_PageFileSetting |
    Select-Object Name, InitialSize, MaximumSize

Write-Host "`n===== GUEST MEMORY / COMMIT ====="
Get-CimInstance Win32_OperatingSystem |
    Select-Object TotalVisibleMemorySize, FreePhysicalMemory, TotalVirtualMemorySize, FreeVirtualMemory

Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit','\Memory\Available MBytes'

Write-Host "`n===== TEMPORARY FOLDER LOCATIONS ====="
"User TEMP: $env:TEMP"
"User TMP: $env:TMP"
"Process TEMP path: $([System.IO.Path]::GetTempPath())"
[Environment]::GetEnvironmentVariable('TEMP','Machine')
[Environment]::GetEnvironmentVariable('TMP','Machine')

Write-Host "`n===== VIRTUAL DISK DETAILS ====="
Get-PhysicalDisk |
    Select-Object FriendlyName, MediaType, BusType, Size, HealthStatus

Write-Host "`n===== WINDOWS TRIM STATUS ====="
fsutil behavior query DisableDeleteNotify

Write-Host "`n===== DRIVE OPTIMIZATION SCHEDULE ====="
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' |
    Select-Object TaskName, State
```

Interpretation cautions:

- `DisableDeleteNotify = 0` indicates delete notifications/TRIM are enabled for the corresponding filesystem type; it does not alone prove end-to-end discard reaches the NVMe.
- An empty `Win32_PageFileSetting` result does not by itself mean no pagefile exists; correlate with `Win32_PageFileUsage` and `AutomaticManagedPagefile`.
- `Get-PhysicalDisk` may report a virtualized media type. Do not assume it identifies the physical host SSD.
- Scheduled task state is not proof of the last run or its exact operation.

## 7. SteamOS host baseline commands — read-only

Run on SteamOS (SSH or Konsole):

```bash
echo "===== VM IMAGE ALLOCATION ====="
du -h /home/deck/WindowsVM/storage/data.img
du -h --apparent-size /home/deck/WindowsVM/storage/data.img

echo
echo "===== HOST FILESYSTEM ====="
df -h /home/deck/WindowsVM/storage

echo
echo "===== HOST SWAP ====="
swapon --show

echo
echo "===== HOST MEMORY ====="
free -h

echo
echo "===== NVME TOOL AVAILABILITY ====="
command -v nvme || true
command -v smartctl || true
```

A later approved read-only NVMe health query should first identify the exact device and supported command options. Do not assume `/dev/nvme0` is the only controller or that every SMART field is supported.

## 8. Host safety gates

Stop an experiment if any of the following occurs:

- SteamOS becomes sluggish, unstable, unresponsive or begins sustained host swapping.
- Host available memory becomes critically low or swap activity rises sharply.
- The host filesystem approaches an agreed free-space floor.
- The VM consumes storage unexpectedly or the sparse image grows much faster than the workload explains.
- The NVMe reports critical warnings, media/data-integrity errors or abnormal temperatures.
- A proposed change requires host package replacement, kernel/module changes, privileged containers, broad permissions, disabling host protections or altering SteamOS swap.
- The impact on Windows servicing, UUP conversion, crash handling or guest recovery is not understood.

No numerical host memory or free-space thresholds have been approved yet. Establish them from actual Steam Deck idle and workload measurements rather than inventing universal limits.

## 9. Test order and current priority

LAN noVNC access is already verified from the PC in Brave and Chrome. RDP work is deliberately deferred. The user wants the current guest retained until the following groundwork is complete.

1. Collect the Windows PowerShell baseline in Section 6 inside the existing guest. This is read-only.
2. Collect a fresh SteamOS host memory/swap/PSI and filesystem baseline while idle and while the guest is running.
3. Collect a read-only NVMe health/counter baseline; do not run destructive tests or change host storage settings.
4. Establish guest idle and representative-workload memory/commit/pagefile measurements.
5. Inspect the current QEMU disk arguments and guest TRIM/media reporting; distinguish guest TRIM enablement from end-to-end discard propagation.
6. Research RAM-disk implementations and their lifecycle; do not install one before reviewing requirements and memory cost.
7. Model user TEMP, system TEMP and pagefile options separately. No redirection or pagefile change yet.
8. Only after the analysis is complete, design one-variable-at-a-time experiments for the replacement disposable guest.
9. Update this document after each completed test with exact settings, evidence, results and limitations.

Do not delete/recreate the current guest merely to begin these tests. Do not create guest backups, snapshots or virtual-disk copies.

The LAN console milestone is complete. The PC client at 192.168.1.169 successfully opened the guest console at http://192.168.1.161:8006/ in both Brave and Chrome simultaneously. Both viewers display the same Windows guest desktop; they are not separate guest sessions. Windows-side inspection and all storage-tuning experiments remain pending until performed through this working console.

## 10. Evidence and change register

| Date | Item | Status | Evidence / note |
|---|---|---|---|
| 2026-11-12 | Virtual disk format and configured capacity | VERIFIED | Project configuration identifies raw, growable 128 GiB guest disk |
| 2026-11-12 | Current host allocation of `data.img` | USER-SUPPLIED / OBSERVED | `du -h`: 8.5G; apparent size: 128G |
| 2026-11-12 | Host filesystem free capacity | USER-SUPPLIED / OBSERVED | `df`: 498 GiB available, 47% used |
| 2026-11-12 | Host RAM and swap | USER-SUPPLIED / OBSERVED | 14 GiB RAM total, 3.0 GiB available; zram 7.2 GiB with 1.1 GiB used; host swapfile 1 GiB with 3.6 MiB used |
| 2026-11-12 | NVMe utilities | VERIFIED FROM PATH OUTPUT | `nvme` and `smartctl` available; no health query performed |
| 2026-11-12 | Windows PowerShell baseline | NOT RUN | PowerShell block was mistakenly entered in SteamOS Bash; no guest settings were changed |
| 2026-11-12 | Windows pagefile settings and usage | UNKNOWN / PENDING | Must inspect inside guest |
| 2026-11-12 | Guest TEMP/TMP paths | UNKNOWN / PENDING | Must inspect inside guest |
| 2026-11-12 | Guest virtual media type and TRIM | UNKNOWN / PENDING | Must inspect inside guest and correlate with QEMU configuration |
| 2026-11-12 | Windows Optimize Drives schedule | UNKNOWN / PENDING | Must inspect inside guest |
| 2026-11-12 | RAM-disk implementation | PROPOSED | Research and resource review required |
| 2026-11-12 | Pagefile reduction/disable | PROPOSED EXPERIMENT | Not applied; requires commit and workload baseline |
| 2026-11-12 | Host NVMe health | PENDING | Tools available; read-only health baseline not yet collected |
| 2026-11-12 | RAM-disk product reference | UNRESOLVED | User mentioned “AIM Toolkit”; confirm exact product name before evaluating/installing a RAM-disk implementation |
| 2026-11-12 | LAN noVNC access | VERIFIED / COMPLETE | Container recreated with publication 192.168.1.161:8006; Podman and ss confirmed listener; user successfully opened the same guest console in Brave and Chrome on the PC client |

---

*Living lab document. Record tested behavior, not assumptions. Any optimization that threatens SteamOS stability is rejected, regardless of Windows performance benefit.*


## 11. LAN console milestone — 2026-11-12

**VERIFIED:** The start script publishes TCP 8006 on `192.168.1.161`. The previous container was stopped and only its container object was removed; the replacement was created from the updated script. The existing `/home/deck/WindowsVM/storage` bind mount and `data.img` were retained. No guest backup or snapshot was created.

Host-side verification reported `8006/tcp -> 192.168.1.161:8006` from `podman port`, and `ss` showed a listener on `192.168.1.161:8006` owned by `passt.avx2`. The user then confirmed successful access from PC client `192.168.1.169` in both Brave and Chrome at the same time. Both browser windows mirror the same Windows guest display/input session.

The earlier PowerShell command block was mistakenly entered into SteamOS Bash over SSH. It did not execute in Windows and made no guest changes. Re-run the guest-side baseline in Section 6 through noVNC PowerShell.


## 12. Replacement-guest preparation note — 2026-11-13

The planned replacement guest is 8 GiB RAM and a 72 GiB growable raw disk, but neither value has been empirically tested yet. The earlier 6 GiB guest's historical host reading showed only 3.0 GiB available. Before starting an 8 GiB guest, remeasure host memory availability and memory pressure. A RAM disk would consume guest memory backed by the same finite host RAM budget; it must not be treated as a free way to reduce SSD writes.

The user's preferred order is to finish UUP/ISO and Windows setup groundwork first, then complete the read-only storage analysis, and only then run disposable I/O experiments. RDP publication is not a prerequisite for this work and is deferred.

The current official Dockur environment reference documents BALLOONING, BALLOONING_MIN_MEM and host-pressure thresholds. Ballooning is not equivalent to freely changing the guest's configured maximum RAM at runtime. Its behavior and guest driver support must be verified before enabling it. Do not enable it in the initial replacement configuration by assumption.

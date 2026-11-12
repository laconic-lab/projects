# Windows VM — Memory, Temporary Storage & SSD Lab

**Status:** Planning document; experiments not yet performed  
**Environment:** Steam Deck OLED / SteamOS host, rootless Podman, Dockur Windows, QEMU/KVM  
**Current guest:** `windows-box`, Windows 11 Pro 24H2, 6 GiB configured RAM, 128 GiB sparse raw virtual disk  
**Purpose:** Explore safe ways to reduce unnecessary persistent writes from a disposable Windows laboratory guest without endangering SteamOS or the host NVMe.

## 1. Lab philosophy and safety boundary

This Windows VM is a disposable sandbox for learning QEMU, KVM, rootless Podman and Dockur. The guest may be discarded and recreated when experiments damage it. The priority is to preserve accurate configuration knowledge, observations, commands and recovery procedures—not the guest's state.

- Do not create Windows guest backups, snapshots or copies of `data.img` during this lab unless the user explicitly changes this policy.
- Preserve configuration parameters and verified findings in project documentation.
- Prefer read-only diagnosis before changes.
- Test one variable at a time and record the result.
- Do not trade SteamOS stability or host data integrity for guest performance.
- Never apply host swap, memory, filesystem, NVMe, QEMU cache or discard changes without a separate risk review and explicit approval.
- A disposable guest does not make host-level changes disposable.

## 2. Current verified baseline

### Guest and storage configuration

| Parameter | Current value | Evidence/status |
|---|---|---|
| Container | `windows-box` | Verified 2026-11-12 |
| Image | Dockur Windows, pinned by digest | Verified from prior container inspection |
| Guest OS | Windows 11 Pro 24H2, build 26100 | User-confirmed |
| Configured guest RAM | 6 GiB | Current environment configuration |
| Virtual disk | 128 GiB, raw, sparse/growable | Current environment configuration |
| Host disk image | `/home/deck/WindowsVM/storage/data.img` | Verified |
| Host allocation for image | 8.5 GiB | `du -h`, 2026-11-12 |
| Apparent virtual image size | 128 GiB | `du --apparent-size -h`, 2026-11-12 |
| Host filesystem | `/dev/nvme0n1p8`, mounted at `/home` | Verified |
| Host filesystem free | 498 GiB of 939 GiB | `df -h`, 2026-11-12 |
| Host RAM | 14 GiB total; 3.0 GiB available at observation | `free -h`, 2026-11-12 |
| Host swap | 7.2 GiB zram + 1 GiB swapfile | `swapon --show`, 2026-11-12 |
| Host swap in use | 1.1 GiB total at observation | `swapon --show`, 2026-11-12 |
| NVMe tools | `nvme` and `smartctl` available | `command -v`, 2026-11-12 |

These are point-in-time observations, not fixed limits or health diagnoses. In particular, 3.0 GiB available host memory is a reason not to increase guest RAM blindly. Configured guest RAM is not necessarily equal to QEMU's resident host memory at every moment.

### Important interpretation

The 128 GiB virtual disk is not currently consuming 128 GiB of host storage. The raw image's apparent size is 128 GiB, while its reported allocated host space was 8.5 GiB. The image can grow as guest writes allocate additional host blocks. The host filesystem must retain sufficient free space for SteamOS and all other workloads.

The Windows pagefile, Windows temporary directories, caches, update data and application files are guest files stored inside the virtual disk image unless explicitly redirected elsewhere.

## 3. Research and experiment questions

### 3.1 RAM-backed system and user temporary directories

Investigate whether Windows system and user temporary paths can be redirected to a RAM disk for this disposable guest.

Potential targets include:

- System `TEMP` and `TMP`.
- User `TEMP` and `TMP`.
- Application-specific caches where safe and practical.
- Browser caches and other high-churn temporary data.

A RAM disk could reduce persistent writes, but it consumes guest RAM. It may also create compatibility issues:
- Some installers and servicing operations expect temporary paths to exist early during boot.
- Services may start before a RAM disk is ready.
- System and user permissions must remain correct.
- Some applications expect temporary paths to support particular filesystem semantics or sufficient capacity.
- A crash or power-off loses RAM-disk contents by design.
- A RAM disk can increase memory pressure and thereby increase paging, potentially offsetting the intended write reduction.

Investigate tools such as ImDisk Toolkit or other suitable Windows RAM-disk implementations, but do not assume a specific tool is compatible or appropriate until tested. The user mentioned an “AIM Toolkit”; confirm the exact product/name before selecting it.

Preferred experiment design:
1. Establish current TEMP/TMP locations and usage.
2. Measure guest memory headroom and host memory impact.
3. Create a temporary, non-persistent RAM disk in a controlled test.
4. Test user TEMP redirection first, not system-wide redirection.
5. Verify behavior after sign-out, reboot and service startup.
6. Only consider system TEMP after compatibility evidence.
7. Record how to revert the experiment without relying on a guest backup.

### 3.2 Windows pagefile

The user would prefer to eliminate `pagefile.sys` because the VM is disposable and the Deck does not have abundant RAM to share.

This is a hypothesis to test, not a recommended default.

Consider:
- Windows commit limit and application behavior without a pagefile.
- Crash-dump requirements.
- Installer, browser and application compatibility.
- Whether reducing the pagefile actually reduces total host writes or merely causes failures / memory pressure.
- Whether a small fixed pagefile is a safer compromise than disabling it.
- The effect of guest RAM allocation on host memory pressure and SteamOS stability.

Do not disable the pagefile until the guest-side audit and a specific test plan are reviewed. Do not increase guest RAM until host headroom is measured under the intended workload.

### 3.3 Windows storage optimization, TRIM and virtual disk discard

Determine what Windows detects for the virtual disk and whether discard/TRIM is propagated through the full stack:

Windows guest → virtual disk interface → QEMU → Dockur container → host filesystem → NVMe.

Inspect, without changing:
- Guest media type and disk characteristics.
- Windows Optimize Drives schedule and reported optimization behavior.
- Windows TRIM status.
- QEMU disk options and discard/unmap configuration for the pinned Dockur image.
- Host filesystem and NVMe discard support.

Do not run manual TRIM, fstrim, defragmentation or storage maintenance experiments as part of a read-only audit. Do not assume that Windows' SSD optimization is conventional HDD defragmentation; modern Windows uses SSD-aware maintenance, including retrim where supported.

### 3.4 Host NVMe health and write activity

Use the already available `nvme` and `smartctl` tools for read-only health inspection after the console is available and the baseline is documented.

Potential measurements:
- NVMe model, firmware and health information.
- Percentage used / available spare, if reported.
- Data units written and host read/write counters, if supported.
- Host filesystem free space before and after defined guest workloads.
- Image allocated size before and after a test.

Counters are device-wide and include SteamOS and all other host activity; do not attribute all changes to Windows. Avoid frequent polling and do not write benchmark workloads solely to measure endurance.

## 4. Safety principles for any SSD/RAM tuning

- Do not disable SteamOS swap or zram.
- Do not change host swappiness, memory limits or cgroup policy as an initial optimization.
- Do not use unsafe QEMU cache modes or disable flush/barrier semantics.
- Do not assume guest TRIM guarantees immediate host block reclamation.
- Do not run guest defragmentation tools against host filesystems.
- Do not disable Windows Defender, updates or general maintenance solely to reduce writes without a separate security/compatibility assessment.
- Do not put all temporary files in RAM without checking memory pressure and service startup dependencies.
- Do not let the VM consume host storage until SteamOS is at risk of running out of space.
- Stop experiments if SteamOS becomes sluggish, starts swapping heavily, reports filesystem/storage errors, or shows NVMe health warnings.

## 5. Lab sequence

The web console is the immediate priority. Guest-side PowerShell audits and tuning are deferred until the PC can connect to the Windows guest.

1. Complete LAN noVNC access from the PC client.
2. Confirm the PC browser reaches the guest console at `http://192.168.1.161:8006/`.
3. Run the Windows-side read-only baseline from PowerShell inside the guest.
4. Capture the QEMU/Dockur virtual-disk settings and host storage baseline.
5. Review RAM-disk options and design a reversible user-TEMP experiment.
6. Separately evaluate pagefile alternatives.
7. Test SSD optimization and discard behavior only after the stack is understood.
8. Record results, limitations and a final recommended lab configuration.

## 6. Commands and shell boundary

Windows PowerShell commands must be entered inside the Windows guest's PowerShell console, reached through noVNC. They must not be pasted into SteamOS Bash or the Windows PC's local PowerShell if the target is the guest.

SteamOS Bash commands belong in Konsole or an SSH session to the Deck.

A prior attempt to run `Write-Host`, `Get-CimInstance` and other PowerShell commands in the Deck Bash shell returned `command not found`. This was a shell mismatch; it did not execute the intended Windows audit.

## 7. Current pending Windows-side baseline

Run only from PowerShell inside the Windows guest after LAN console access is confirmed:

```powershell
Write-Host "===== WINDOWS PAGEFILE ====="
Get-CimInstance Win32_PageFileUsage |
    Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

Write-Host "`n===== PAGEFILE CONFIGURATION ====="
Get-CimInstance Win32_ComputerSystem |
    Select-Object AutomaticManagedPagefile

Get-CimInstance Win32_PageFileSetting |
    Select-Object Name, InitialSize, MaximumSize

Write-Host "`n===== TEMPORARY FOLDER LOCATIONS ====="
$env:TEMP
$env:TMP
[System.IO.Path]::GetTempPath()

Write-Host "`n===== VIRTUAL DISK DETAILS ====="
Get-PhysicalDisk |
    Select-Object FriendlyName, MediaType, BusType, Size

Write-Host "`n===== WINDOWS TRIM STATUS ====="
fsutil behavior query DisableDeleteNotify

Write-Host "`n===== DRIVE OPTIMIZATION SCHEDULE ====="
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' |
    Select-Object TaskName, State
```

These commands are an initial inventory only. Their output must be interpreted before any settings are changed.

## 8. Current LAN console transition

The start script has been changed to publish noVNC on `192.168.1.161:8006`, and `bash -n` passed. The currently running container was still using the old binding `127.0.0.1:8006` at the last inspection.

Current script settings:
- `--publish 192.168.1.161:8006:8006`
- Persistent storage bind mount: `/home/deck/WindowsVM/storage:/storage:rw`
- ISO bind mount: read-only
- Shared directory bind mount: `/home/deck/WindowsVM/shared:/shared:rw`

Next operation is to stop the current guest/container cleanly, remove only the Podman container object, and recreate it from the updated script. Do not remove or alter the host storage directory, `data.img`, ISO or shared directory. No VM backup or snapshot is part of this procedure.

After recreation, verify the published port and host listener, then test from the PC client:
`http://192.168.1.161:8006/`

## 9. Decision log

| Topic | Current decision |
|---|---|
| VM backups/snapshots | Not wanted for this disposable lab |
| Preserve guest state | Not required; recreate guest when preferable |
| Preserve technical knowledge | Required; document settings and test evidence |
| RAM disk for TEMP | Investigate; not yet approved |
| Disable pagefile | User interested; not yet tested or approved |
| Disable SSD optimization | Not recommended without evidence |
| Increase guest RAM | Deferred; measure host headroom first |
| Windows-side audit | Deferred until LAN console works |
| Immediate priority | Finish PC-to-Deck noVNC access |

---
**Evidence discipline:** distinguish verified host observations, user-confirmed guest facts, hypotheses, and pending tests. Update this document as experiments complete.

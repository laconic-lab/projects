# EFI / Windows–Linux Dual-Boot Roadbook

**Current position (2026-11-18):** The original reason for this work is that Windows Setup, during the Windows 11 Pro installation with both SSDs connected, placed/reused Windows boot files on the Kingston EFI partition instead of creating a dedicated EFI on the Crucial. This made Windows dependent on Kingston. We then created and populated a separate Windows EFI on the Crucial and successfully boot-tested Windows with Kingston disabled: Windows EFI independence from Kingston is now achieved. The Kingston's Microsoft EFI files are expected historical residue from the original installation. Windows drive letters S: (Crucial) and T: (Kingston) were assigned later by our PowerShell inspection commands for convenience; they are not native EFI identifiers and do not record when a firmware entry was created. In BCDEdit output, `partition=T:` is the current Windows resolution/display of a device path to the Kingston EFI partition, not evidence that the entry was created while T: existed. The Kingston also contains an old GRUB installation from a failed Arch Linux test; it launches but its Arch root filesystem fails. The next goal is to boot the actual Linux installation on Kingston and rebuild its correct GRUB configuration.

## Firmware entry register

The latest complete `bcdedit /enum firmware` output (after the user's attempted Ubuntu-entry promotion) uses a new set of NVRAM identifiers. These are the current identifiers to use; do not reuse the earlier `{eefc...}` identifiers without rechecking.

| Current firmware entry | Description / target | Result / evidence | Status |
|:---|:---|:---|:---:|
| `{ed3424b2-e286-11f1-b05c-a9157e3a9c2c}` | GRUB — `\\EFI\\GRUB\\grubx64.efi` | The current BCDEdit output resolves this entry's device to `partition=T:` after we assigned T: to the Kingston ESP. This does not mean T: existed when the NVRAM entry was created. It launched successfully, but its old Arch configuration failed at rootfs/emergency shell. | **NOK — failed Arch test** |
| `{ed3424b3-e286-11f1-b05c-a9157e3a9c2c}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | No matching shim found on either currently mounted ESP (S: or T:). BCDEdit shows no device field for this entry, so its partition association is unresolved in this output; absence of a drive letter is not proof that the entry was created incorrectly. | **UNVERIFIED — loader not found** |
| `{ed3424b4-e286-11f1-b05c-a9157e3a9c2c}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | No matching shim found on S: or T:. No device field shown. | **UNVERIFIED — loader not found** |
| `{ed3424b5-e286-11f1-b05c-a9157e3a9c2c}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | No matching shim found on S: or T:. No device field shown. | **UNVERIFIED — loader not found** |
| `{ed3424b6-e286-11f1-b05c-a9157e3a9c2c}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | No matching shim found on S: or T:. No device field shown. | **UNVERIFIED — loader not found** |
| `{38f288c3-e2eb-11f1-b8d8-806e6f6e6963}` | UEFI: CT500MX500SSD1 — Crucial EFI (S:) | Firmware device entry. Independent Crucial-only Windows boot was previously successful. | **OK — Windows disk** |
| `{38f288c4-e2eb-11f1-b8d8-806e6f6e6963}` | UEFI: KINGSTON SKC600MS1024G — Kingston disk | Generic disk UEFI entry. BCDEdit currently resolves its device to `partition=T:` because T: was assigned to the Kingston ESP for inspection. It may invoke the disk's fallback loader `\\EFI\\Boot\\bootx64.efi`; that file's contents have not been identified. | **UNTESTED — target not confirmed** |
| `{bootmgr}` | Windows Boot Manager — latest BCDEdit output says `partition=T:`, path `\\EFI\\Microsoft\\Boot\\bootmgfw.efi` | `T:` is the temporary Windows letter assigned to the Kingston ESP during our audit; it is not an original EFI drive letter. The original Windows Setup did place/reuse Windows boot files on Kingston. Separately, the Crucial ESP was created and populated, and Windows successfully booted with Kingston disabled. Thus Windows independence is proven, but this particular firmware entry currently resolves to Kingston. Preserve both copies. | **OK — Windows runs; Crucial independence proven** |

The firmware displayorder in the latest output begins with `{bootmgr}`, followed by the five `{ed3424...}` entries, then Kingston/Crucial generic UEFI entries. The attempted `/set "{fwbootmgr}" displayorder "{eefc...}" /addfirst` returned success but did not produce the expected first-entry result; the output also showed newly changed identifiers. Do not assume the requested Ubuntu entry was promoted.

**Drive-letter interpretation:** S: and T: were assigned by our later PowerShell commands solely to make the EFI partitions accessible in Windows. At the beginning, these EFI partitions had no Windows drive letters; the pre-existing GRUB and Ubuntu NVRAM entries were therefore not created using S: or T:. A later BCDEdit display of `device partition=T:` means Windows can now resolve that firmware device path to the partition currently mounted as T:. It does not establish when the entry was created. Conversely, an Ubuntu entry with no `device` line has no partition association displayed/resolved by this BCDEdit output; do not infer more than that.

**Status rule:** NOK means a tested entry failed its intended boot; UNVERIFIED means evidence is insufficient; UNTESTED means no direct boot test; OK means the intended operating system was confirmed to boot. Do not delete an entry solely because it is duplicated or unverified.

## Chronological test and action log

| Date | Entry | Actions / Results / Remarks |
|:---:|:---|:---|
| 17/11/26 | **Windows 11 Pro installed on Crucial** | Windows 11 Pro was clean-installed on the Crucial MX500 while the Kingston SSD was connected. Windows Setup did not create a dedicated EFI on Crucial; it placed/reused the existing Kingston EFI for Windows boot files. This caused boot dependence on Kingston and is the reason for the EFI independence correction. The separate WDC data disk (D:) is not part of this work and must remain untouched. |
| 17/11/26 | **WinRE checked** | `reagentc /info` reported Windows Recovery Environment enabled. The recovery partition is on Disk 0 (Crucial). Preserve the existing recovery configuration; revalidate only if later evidence indicates a problem. |
| 17/11/26 | **Dedicated Crucial EFI created** | C: was shrunk by 1 GiB. A 1 GiB FAT32 EFI System Partition was created on Disk 0, labelled `EFI-WIN`, and temporarily assigned S:. |
| 17/11/26 | **Crucial EFI populated successfully** | Ran `bcdboot.exe C:\\Windows /s S: /f UEFI /v`. It reported “Boot files successfully created” (exit 0). Verified Microsoft boot manager, fallback loader and BCD files. |
| 17/11/26 | **Crucial-only boot test — SUCCESS** | Disabled Kingston / other SATA ports, leaving only SATA0 (Crucial) enabled. Windows booted successfully using the newly created Crucial EFI. This proves Windows no longer depends on Kingston. The old Windows files on Kingston are expected residue from Setup's original EFI placement. |
| 17/11/26 | **Both SSDs restored** | Kingston was re-enabled. Both SSDs are visible to Windows. Do not disturb the WDC data disk or Kingston Linux partitions. |
| 18/11/26 | **Firmware entries inspected** | BCDEdit showed one GRUB entry, four duplicate Ubuntu shim entries without device fields, a Kingston disk entry, a Crucial disk entry and Windows Boot Manager. At this point the later S:/T: assignments must be distinguished from the firmware entries' original creation: the drive letters are Windows mount points, not EFI identifiers. See register above. |
| 18/11/26 | **Kingston EFI inspected from Windows** | Assigned T: to Kingston Disk 2, Partition 1 (1 GiB FAT32 ESP). This only added a temporary Windows drive letter; no EFI files were intentionally changed. T: contained `EFI\\GRUB`, `EFI\\Boot`, and `EFI\\Microsoft`. The letter did not exist on the ESP before this audit assignment and does not indicate how/when the firmware entries were created. |
| 18/11/26 | **GRUB configuration inspected — Arch mismatch** | `T:\\grub\\grub.cfg` was generated for an Arch Linux test, not confirmed Linux Mint. It referenced root UUID `5c2ce4ff-93be-402f-90c3-c7b79ebf2c21`, EFI UUID `2CE5-D0E8`, and contained no Windows entry. |
| 18/11/26 | **GRUB added first in UEFI order — SUCCESS** | The first `bcdedit /displayorder {GRUB-GUID} /addfirst` attempt did not change the order. The explicit command `bcdedit /set "{fwbootmgr}" displayorder "{eefc7669-e2de-11f1-b8d5-806e6f6e6963}" /addfirst` succeeded. A subsequent `bcdedit /enum firmware` confirmed GRUB first in firmware displayorder. |
| 18/11/26 | **GRUB launch test — NOK for intended Linux** | Reboot successfully launched GRUB from Kingston. Selecting its Arch Linux entry failed with a root-filesystem error and entered an emergency shell. This proves the GRUB EFI executable launches, but the Arch test configuration is not a viable route to the intended Linux installation. |
| 18/11/26 | **Returned to Windows** | User rebooted from the emergency shell and returned to Windows. |
| 18/11/26 | **GRUB removed from active boot sequence** | User reports removing the GRUB entry from the firmware boot sequence after the failed Arch test. A fresh `bcdedit /enum firmware` is still needed to record the exact current displayorder. The GRUB NVRAM entry itself has not been reported deleted. |
| 18/11/26 | **Ubuntu EFI loader search — no match** | Read-only PowerShell inspection of `S:\\EFI` showed only `Boot` and `Microsoft`. Inspection of `T:\\EFI` showed only `GRUB`, `Boot`, and `Microsoft`. Recursive search found no `shimx64.efi` on either mounted EFI partition. Therefore none of the four Ubuntu entries is currently confirmed as the Mint loader. |
| 18/11/26 | **Latest firmware order / Ubuntu promotion attempt — anomalous result** | User ran `bcdedit /set "{fwbootmgr}" displayorder "{eefc766c-e2de-11f1-b8d5-806e6f6e6963}" /addfirst`; BCDEdit reported success. Verification did not show the requested Ubuntu entry first. Instead, NVRAM identifiers had changed to `{ed3424...}` for GRUB/Ubuntu entries and `{38f288...}` for generic disk entries; displayorder began with `{bootmgr}`. The `partition=T:` display is the current Windows mapping of the Kingston ESP, whose T: letter was assigned for this audit; it is not evidence that the NVRAM entry was created with a T: letter. No reboot/test was performed after this output. |
| 18/11/26 | **EFI partition mapping rechecked — READ-ONLY** | `Get-Partition` confirmed Disk 0 Partition 3 = S: (Crucial, 1 GiB FAT32 ESP); Disk 2 Partition 1 = T: (Kingston, 1 GiB FAT32 ESP). S:\\EFI contains only `Boot` and `Microsoft`; T:\\EFI contains `GRUB`, `Boot`, and `Microsoft`. No `shimx64.efi` found. Kingston Disk 2 Partitions 2–4 remain Linux/unknown to Windows. |
| 18/11/26 | **PowerShell/Linux command mismatch — no changes** | Linux commands were accidentally pasted into Windows PowerShell and rejected. No Linux inspection ran and no system changes resulted. Linux commands must only be run in a Linux terminal. |

## Current disk map

- **Disk 0 — Crucial MX500, GPT:** Windows 11 Pro (C:), 1 GiB EFI-WIN (S: when assigned), and Windows Recovery partition.
- **Disk 1 — WDC 1 TB, MBR:** data drive D:. Do not modify.
- **Disk 2 — Kingston 1 TB, GPT:** 1 GiB EFI (T: when assigned), 16 GiB swap, and two Linux filesystem partitions (about 500 GiB and 437 GiB). Exact Linux roles/distributions remain to be identified.
- **Disk 3 — RAM drive:** ignore.

## Next steps

1. Do not run more BCDEdit writes or reboot based solely on the duplicate Ubuntu entries: their referenced shim file is absent from both S: and T:.
2. Treat the latest `{bootmgr}` `device partition=T:` as a current mapping to the Kingston ESP, not as a historical drive-letter fact. The Crucial-only boot test independently proves that the Crucial EFI can boot Windows. Preserve both Microsoft EFI directories; if we need to identify which firmware route was used during the isolation test, inspect the current NVRAM device paths and boot behavior separately.
3. Identify the actual Linux distribution and root filesystem on Kingston Disk 2 Partitions 3 and 4 using a Linux live environment (read-only identification first). Do not assume Mint until `/etc/os-release` is inspected.
4. From the live environment, inspect filesystem UUIDs, partition contents, installed kernels, and the intended installation's existing boot configuration. Do not mount Linux filesystems read-write or run GRUB installation until the target is confirmed.
5. Then plan a minimal repair of the confirmed Linux installation's EFI bootloader; rebuild GRUB from the installed Linux environment or a carefully prepared chroot, including Windows detection/chainloading.
6. Verify both operating systems boot independently before removing temporary Windows drive letters or deleting stale NVRAM entries.

## Safeguards

- Never format either EFI partition or overwrite Microsoft boot files.
- Do not modify the Kingston Linux partitions, swap, or WDC data disk during identification.
- Keep the Crucial Windows EFI independent and working.
- Do not delete the four Ubuntu NVRAM entries until their targets are identified and both boot paths are verified.
- Treat the failed Arch GRUB route as NOK for the intended OS; do not reuse its configuration as if it were Mint.
- After each test, update the entry register (OK / NOK / UNVERIFIED / UNTESTED) and append the chronological result. Do not silently rewrite history.

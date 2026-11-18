# EFI / Windows–Linux Dual-Boot Roadbook

**Current position (2026-11-18):** Windows 11 Pro boots independently from the Crucial MX500. The Kingston EFI launches the old GRUB installation, but that GRUB configuration belongs to a failed Arch Linux test and stops with a root-filesystem error. GRUB has been removed from the active firmware boot sequence by the user. The next objective is to identify the real Linux Mint EFI loader / installation, boot it, then rebuild GRUB from Linux.

## Firmware entry register

Entries below are from the latest complete `bcdedit /enum firmware` output supplied before the GRUB test. The user subsequently removed the GRUB entry from the active boot sequence; a fresh firmware listing has not yet been supplied.

| Firmware entry | Description / target | Result / evidence | Status |
|:---|:---|:---|:---:|
| `{eefc7669-e2de-11f1-b8d5-806e6f6e6963}` | GRUB — `T:\\EFI\\GRUB\\grubx64.efi` on Kingston | Firmware successfully launched GRUB. Its menu booted the Arch Linux test configuration and ended at a rootfs error / emergency shell. This is not the intended viable Linux installation. User removed it from active boot sequence. | **NOK — failed Arch test** |
| `{eefc766a-e2de-11f1-b8d5-806e6f6e6963}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | No `shimx64.efi` was found in either currently mounted EFI partition (S: or T:). Firmware entry has no device field in BCDEdit output. | **UNVERIFIED — loader not found** |
| `{eefc766b-e2de-11f1-b8d5-806e6f6e6963}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | Same path and no device field. No matching shim found on S: or T:. | **UNVERIFIED — loader not found** |
| `{eefc766c-e2de-11f1-b8d5-806e6f6e6963}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | Same path and no device field. No matching shim found on S: or T:. Cannot distinguish it from the other duplicate entries. | **UNVERIFIED — loader not found** |
| `{eefc766d-e2de-11f1-b8d5-806e6f6e6963}` | Ubuntu — `\\EFI\\ubuntu\\shimx64.efi` | Same path and no device field. No matching shim found on S: or T:. | **UNVERIFIED — loader not found** |
| `{eefc766e-e2de-11f1-b8d5-806e6f6e6963}` | UEFI: CT500MX500SSD1 — Crucial EFI (S:) | Windows 11 boots independently when Kingston / other SATA ports are disabled. This is the Crucial disk firmware entry, not Linux Mint. | **OK — Windows disk** |
| `{515a4b13-e2e1-11f1-b8d7-806e6f6e6963}` | UEFI: KINGSTON SKC600MS1024G — Kingston EFI (T:) | Device entry only; no loader path shown. Not yet tested as a direct boot choice. | **UNTESTED** |
| `{bootmgr}` | Windows Boot Manager — `S:\\EFI\\Microsoft\\Boot\\bootmgfw.efi` | Windows 11 starts successfully from Crucial. | **OK — Windows** |

**Status rule:** NOK means a tested entry failed its intended boot; UNVERIFIED means evidence is insufficient; UNTESTED means no direct boot test; OK means the intended operating system was confirmed to boot. Do not delete an entry solely because it is duplicated or unverified.

## Chronological test and action log

| Date | Entry | Actions / Results / Remarks |
|:---:|:---|:---|
| 17/11/26 | **Windows 11 Pro installed on Crucial** | Windows 11 Pro was clean-installed on the Crucial MX500 while the Kingston SSD was connected. Windows initially reused the Kingston EFI partition. The separate WDC data disk (D:) is not part of this work and must remain untouched. |
| 17/11/26 | **WinRE checked** | `reagentc /info` reported Windows Recovery Environment enabled. The recovery partition is on Disk 0 (Crucial). Preserve the existing recovery configuration; revalidate only if later evidence indicates a problem. |
| 17/11/26 | **Dedicated Crucial EFI created** | C: was shrunk by 1 GiB. A 1 GiB FAT32 EFI System Partition was created on Disk 0, labelled `EFI-WIN`, and temporarily assigned S:. |
| 17/11/26 | **Crucial EFI populated successfully** | Ran `bcdboot.exe C:\\Windows /s S: /f UEFI /v`. It reported “Boot files successfully created” (exit 0). Verified Microsoft boot manager, fallback loader and BCD files. |
| 17/11/26 | **Crucial-only boot test — SUCCESS** | Disabled Kingston / other SATA ports, leaving only SATA0 (Crucial) enabled. Windows booted successfully. This confirms independent Windows boot from Crucial. |
| 17/11/26 | **Both SSDs restored** | Kingston was re-enabled. Both SSDs are visible to Windows. Do not disturb the WDC data disk or Kingston Linux partitions. |
| 18/11/26 | **Firmware entries inspected** | BCDEdit showed one GRUB entry pointing to Kingston T:, four duplicate Ubuntu shim entries without device fields, a Kingston device entry, a Crucial device entry and Windows Boot Manager. See register above. |
| 18/11/26 | **Kingston EFI inspected from Windows** | Assigned T: to Kingston Disk 2, Partition 1 (1 GiB FAT32 ESP). This only added a temporary drive letter; no EFI files were intentionally changed. T: contained `EFI\\GRUB`, `EFI\\Boot`, and `EFI\\Microsoft`. |
| 18/11/26 | **GRUB configuration inspected — Arch mismatch** | `T:\\grub\\grub.cfg` was generated for an Arch Linux test, not confirmed Linux Mint. It referenced root UUID `5c2ce4ff-93be-402f-90c3-c7b79ebf2c21`, EFI UUID `2CE5-D0E8`, and contained no Windows entry. |
| 18/11/26 | **GRUB added first in UEFI order — SUCCESS** | The first `bcdedit /displayorder {GRUB-GUID} /addfirst` attempt did not change the order. The explicit command `bcdedit /set "{fwbootmgr}" displayorder "{eefc7669-e2de-11f1-b8d5-806e6f6e6963}" /addfirst` succeeded. A subsequent `bcdedit /enum firmware` confirmed GRUB first in firmware displayorder. |
| 18/11/26 | **GRUB launch test — NOK for intended Linux** | Reboot successfully launched GRUB from Kingston. Selecting its Arch Linux entry failed with a root-filesystem error and entered an emergency shell. This proves the GRUB EFI executable launches, but the Arch test configuration is not a viable route to the intended Linux installation. |
| 18/11/26 | **Returned to Windows** | User rebooted from the emergency shell and returned to Windows. |
| 18/11/26 | **GRUB removed from active boot sequence** | User reports removing the GRUB entry from the firmware boot sequence after the failed Arch test. A fresh `bcdedit /enum firmware` is still needed to record the exact current displayorder. The GRUB NVRAM entry itself has not been reported deleted. |
| 18/11/26 | **Ubuntu EFI loader search — no match** | Read-only PowerShell inspection of `S:\\EFI` showed only `Boot` and `Microsoft`. Inspection of `T:\\EFI` showed only `GRUB`, `Boot`, and `Microsoft`. Recursive search found no `shimx64.efi` on either mounted EFI partition. Therefore none of the four Ubuntu entries is currently confirmed as the Mint loader. |
| 18/11/26 | **PowerShell/Linux command mismatch — no changes** | Linux commands were accidentally pasted into Windows PowerShell and rejected. No Linux inspection ran and no system changes resulted. Linux commands must only be run in a Linux terminal. |

## Current disk map

- **Disk 0 — Crucial MX500, GPT:** Windows 11 Pro (C:), 1 GiB EFI-WIN (S: when assigned), and Windows Recovery partition.
- **Disk 1 — WDC 1 TB, MBR:** data drive D:. Do not modify.
- **Disk 2 — Kingston 1 TB, GPT:** 1 GiB EFI (T: when assigned), 16 GiB swap, and two Linux filesystem partitions (about 500 GiB and 437 GiB). Exact Linux roles/distributions remain to be identified.
- **Disk 3 — RAM drive:** ignore.

## Next steps

1. Obtain a fresh `bcdedit /enum firmware` and record the current displayorder after the user removed GRUB from it.
2. Identify which Linux filesystem partition contains the intended Linux Mint installation, without changing partitions.
3. Determine where that installation's EFI loader should reside. The current S: and T: EFI partitions contain no `ubuntu\\shimx64.efi`; do not assume the duplicate Ubuntu NVRAM entries point to a valid loader.
4. Boot the actual Mint installation using a verified boot path. If necessary, use a suitable live environment only after confirming the intended target and recovery plan.
5. Once Mint boots, inspect its EFI mount, root filesystem, installed kernel and GRUB configuration; then rebuild GRUB from Mint and add Windows detection/chainloading.
6. Verify both operating systems boot independently before removing temporary Windows drive letters from either EFI partition.

## Safeguards

- Never format either EFI partition or overwrite Microsoft boot files.
- Do not modify the Kingston Linux partitions, swap, or WDC data disk during identification.
- Keep the Crucial Windows EFI independent and working.
- Do not delete the four Ubuntu NVRAM entries until their targets are identified and both boot paths are verified.
- Treat the failed Arch GRUB route as NOK for the intended OS; do not reuse its configuration as if it were Mint.
- After each test, update the entry register (OK / NOK / UNVERIFIED / UNTESTED) and append the chronological result. Do not silently rewrite history.

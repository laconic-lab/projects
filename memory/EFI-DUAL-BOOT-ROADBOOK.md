# EFI / Windows–Linux Dual-Boot Roadbook

**Current position (2026-11-18):** Windows 11 Pro boots independently from the Crucial SSD. The Kingston EFI contains GRUB files, but the machine currently boots Windows even when Kingston is placed first in BIOS order. GRUB has not yet been repaired. The next task is to correct the UEFI boot selection using the existing GRUB firmware entry, then validate the Linux installation and rebuild GRUB from Linux if required.

| Date | Entry | Actions / Results / Remarks |
|:---:|:---|:---|
| 17/11/26 | **Windows 11 Pro installed on Crucial** | Windows 11 Pro was clean-installed on the Crucial MX500 while the Kingston SSD was connected. Windows initially reused the Kingston EFI partition. The separate WDC data disk (D:) is not part of this work and must remain untouched. |
| 17/11/26 | **WinRE checked** | `reagentc /info` reported Windows Recovery Environment enabled. The recovery partition is on Disk 0 (Crucial). Preserve the existing recovery configuration; revalidate only if later evidence indicates a problem. |
| 17/11/26 | **Dedicated Crucial EFI created** | C: was shrunk by 1 GiB. A 1 GiB FAT32 EFI System Partition was created on Disk 0, labelled `EFI-WIN`, and temporarily assigned S:. |
| 17/11/26 | **Crucial EFI populated successfully** | Ran `bcdboot.exe C:\Windows /s S: /f UEFI /v`. It reported “Boot files successfully created” (exit 0). Verified `S:\EFI\Microsoft\Boot\bootmgfw.efi`, `S:\EFI\Boot\bootx64.efi`, and `S:\EFI\Microsoft\Boot\BCD`. The BCD points Windows Boot Manager to S: and the Windows loader to C:\Windows. |
| 17/11/26 | **Crucial-only boot test — SUCCESS** | Disabled the Kingston in BIOS / disabled the other SATA ports, leaving only SATA0 (Crucial) enabled. Windows booted successfully. Disk Management showed Disk 0 and the RAM drive only. This confirms that Windows boots independently from the Crucial SSD. |
| 17/11/26 | **Both SSDs restored** | Kingston was re-enabled. Both SSDs are visible to Windows. Do not disturb the WDC data disk or the Kingston Linux partitions. |
| 18/11/26 | **Firmware boot entries inspected** | `bcdedit /enum firmware` showed a dedicated Crucial entry (`UEFI: CT500MX500SSD1`) pointing to the new S: EFI, a Kingston entry (`UEFI: KINGSTON SKC600MS1024G`), and a GRUB entry with GUID `{eefc7669-e2de-11f1-b8d5-806e6f6e6963}` pointing to Kingston `\EFI\GRUB\grubx64.efi`. Four older Ubuntu entries point to `\EFI\ubuntu\shimx64.efi`; their validity is unverified. |
| 18/11/26 | **BIOS boot order test — Windows still starts** | User placed Crucial and Kingston in the BIOS boot order, with Kingston ahead of the remaining entry, and tested booting. The machine still starts Windows. Changing disk priority alone has not restored the GRUB menu. |
| 18/11/26 | **Kingston EFI inspected from Windows** | Assigned T: to Kingston Disk 2, Partition 1 (1 GiB FAT32 ESP). This only added a temporary drive letter; no EFI files were intentionally changed. T: contains `EFI\GRUB`, `EFI\Boot`, and `EFI\Microsoft`. |
| 18/11/26 | **Kingston GRUB files inspected** | `T:\EFI\GRUB\grubx64.efi` exists (151,552 bytes); GRUB modules and `T:\grub\grub.cfg` are present. `T:\EFI\Boot\bootx64.efi` is 3,087,240 bytes, the same size as the Crucial Windows boot manager; it is likely a Windows fallback loader, but file identity has not been hash-verified. |
| 18/11/26 | **GRUB configuration inspected — important mismatch** | Existing `T:\grub\grub.cfg` is generated for **Arch Linux**, not confirmed Linux Mint. It uses root UUID `5c2ce4ff-93be-402f-90c3-c7b79ebf2c21`, EFI UUID `2CE5-D0E8`, and contains no Windows entry in its os-prober section. The configuration's `hd2,gpt3` reference may be stale. Do not assume which Kingston Linux partition is the intended Mint root until identified from Linux. |
| 18/11/26 | **PowerShell/Linux command mismatch — no changes** | Linux commands (`test`, `lsblk`, `blkid`) were pasted into Windows PowerShell and rejected with a parser error at `&&` / `||`. No Linux inspection ran and no system changes resulted. Those commands must only be run in a Linux terminal. |
| 18/11/26 | **Current diagnosis / pending repair** | User reports that selecting Kingston / placing it first still results in Windows. The explicit GRUB NVRAM entry exists, but in the previously captured `{fwbootmgr}` display order it was not listed. This is the leading explanation to test; it is not yet proven. No GRUB reinstall, configuration rebuild, EFI overwrite, NVRAM edit, or Linux partition change has been performed. |

## Current disk map

- **Disk 0 — Crucial MX500, GPT:** Windows 11 Pro (C:), 1 GiB EFI-WIN (currently S: when assigned), and Windows Recovery partition.
- **Disk 1 — WDC 1 TB, MBR:** data drive D:. Do not modify.
- **Disk 2 — Kingston 1 TB, GPT:** 1 GiB EFI (T: when assigned), 16 GiB swap, and two Linux filesystem partitions (about 500 GiB and 437 GiB). Exact Linux roles/distributions remain to be identified.
- **Disk 3 — RAM drive:** ignore.

## Next steps

1. Re-read the latest `bcdedit /enum firmware` output and verify the current `{fwbootmgr}` display order and GRUB entry.
2. If still absent from display order, add the existing GRUB firmware entry first using the exact GUID above; verify the order before rebooting.
3. Test whether firmware now launches GRUB. Do not delete the stale Ubuntu entries or change fallback EFI files yet.
4. Once Linux boots, identify the actual installed distribution and root partition. The current GRUB config says Arch Linux; do not assume Mint.
5. Rebuild GRUB from the confirmed installed Linux environment, adding Windows detection/chainloading as appropriate. Do not rebuild GRUB from Windows.
6. Verify both operating systems boot independently before removing temporary Windows drive letters from either EFI partition.

## Safeguards

- Never format either EFI partition or overwrite Microsoft boot files.
- Do not modify the Kingston Linux partitions, swap, or WDC data disk during boot-order diagnosis.
- Keep the Crucial Windows EFI independent and working.
- Do not remove stale NVRAM entries until the working GRUB and Windows boot paths are confirmed.
- Distinguish observed results from hypotheses; append new entries chronologically and do not silently rewrite history.

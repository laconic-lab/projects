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


## 18/11/26 — Linux Mint Live USB recovery and agreed repair architecture

This section supersedes the earlier uncertainty in the disk map and the old “identify the Linux distribution” next step. It records evidence gathered from a Linux Mint Live USB booted in UEFI mode. No repair or intentional writes to the installed Kingston system have been performed.

### Live environment and disk isolation

- The Live USB booted successfully in UEFI mode (/sys/firmware/efi exists).
- BIOS configuration had the Crucial and WDC disks disabled for this recovery session. The live environment's block-device inventory showed only the Kingston SSD and the SanDisk Live USB. This is evidence of isolation at the OS level; it does not erase or remove stale firmware NVRAM records.
- /dev/sda is the Kingston SKC600MS1024G (953.9 GiB); /dev/sdb is the SanDisk Live USB (28.7 GiB).
- Firmware reported BootCurrent: 000C (USB) and BootOrder: 0003,000B,000C. Boot000B is the generic UEFI entry for Kingston and points to its first GPT partition. Boot0003 is a stale Windows Boot Manager NVRAM entry referring to a GPT partition path; its presence is not evidence that the Crucial disk is accessible in this isolated session.
- The installed Mint root and home filesystems were automatically mounted read-write by the live desktop during inspection. This was observed, not an intentional repair write. Before any repair, mount state must be deliberately controlled and the EFI contents inspected. No write operation has yet been approved or executed.

### Kingston partition map — confirmed

| Device | Size | Filesystem / role | UUID | Current evidence |
|:---|---:|:---|:---|:---|
| /dev/sda1 | 1 GiB | FAT32 EFI System Partition | 2CE5-D0E8 | Kingston ESP; partition retained for the planned repair. Its current contents and exact mountpoint still require controlled inspection. |
| /dev/sda2 | 16 GiB | Linux swap | d6475051-4ba4-4aa2-966a-309575fe1d13 | Swap partition; observed active in the Live session. |
| /dev/sda3 | 500 GiB | ext4, installed Mint root / | 19705670-12b0-4218-b537-1664f375df4c | Contains Linux Mint 22 Wilma installation. |
| /dev/sda4 | 436.9 GiB | ext4, installed /home | 7b6ff1ad-f835-4440-966c-d2c147008b2f | Contains the user's /laco home tree and is configured as /home in installed fstab. |

Installed /etc/os-release confirms Linux Mint 22 (Wilma), Ubuntu Noble base. Installed kernels include 6.8.0-90, 6.8.0-139 and 6.8.0-147; the current kernel and initramfs symlinks point to 6.8.0-147. The installed GRUB configuration directory, grub.cfg, and /etc/default/grub exist. This confirms the installed OS and its existing boot configuration are present; it does not yet prove the installed GRUB EFI loader is valid or bootable.

### Confirmed EFI UUID discrepancy

The installed /etc/fstab contains an EFI mount entry using UUID=72EC-1F03 for /boot/efi. However, the actual Kingston EFI partition /dev/sda1 has UUID 2CE5-D0E8. This mismatch is confirmed. It is consistent with the possibility that Mint was originally configured to use an EFI partition on another disk, but the historical location is not yet proven. The planned repair must use the actual Kingston ESP UUID after a backup and explicit review.

### Agreed target architecture — not yet executed

The user approved the approach of retaining the existing 1 GiB Kingston EFI partition and replacing/rebuilding its boot files, rather than deleting or repartitioning the ESP.

- Kingston remains independently bootable into Linux Mint through a clean GRUB EFI installation on Kingston's existing ESP.
- Crucial retains its existing independent Microsoft EFI installation. Its Microsoft boot files must not be overwritten or moved.
- Once the Crucial disk is re-enabled, the Kingston GRUB menu should offer both Linux Mint and Windows 11. The Windows menu entry should chainload the existing Microsoft EFI loader on the Crucial, not relocate Windows boot files.
- The WDC data disk remains out of scope and untouched.
- During the isolated recovery phase, only Mint on Kingston can be tested. Windows chainloading/detection must be validated later with the Crucial re-enabled.

### Requested GRUB menu behaviour

The user wants GRUB to remember the last operating system selected, with a 10-second menu timeout. This is intended to make Windows Update's multiple automatic restarts practical: after Windows is selected once, GRUB should keep Windows as the saved default on subsequent reboots until another OS is selected.

Planned GRUB settings (to be applied only during the reviewed repair stage):

    GRUB_DEFAULT=saved
    GRUB_SAVEDEFAULT=true
    GRUB_TIMEOUT=10
    GRUB_TIMEOUT_STYLE=menu

This saves the OS selected from the GRUB menu; it does not detect which OS initiated a reboot. With Windows saved as the selection, the 10-second timeout should expire into Windows on each subsequent restart. Selecting Mint later changes the saved default to Mint.

### Next controlled actions

1. Continue with read-only verification of the current mount table and the exact mount status of /dev/sda1; inspect the Kingston ESP contents without changing them.
2. Before any write, establish a backup of the current Kingston ESP contents and verify the backup. Do not format or repartition the ESP.
3. Review the installed fstab and GRUB configuration in context, including the confirmed EFI UUID mismatch. Present the exact proposed changes and rollback path before executing them.
4. Only after explicit approval, correct the installed EFI mount reference to UUID 2CE5-D0E8, prepare the installed root/home/ESP mounts, and reinstall/rebuild GRUB for UEFI on the Kingston ESP.
5. Verify the expected EFI files, generated GRUB menu, saved-default settings and Kingston UEFI boot entry before rebooting.
6. Boot-test Mint with the Crucial still disabled. Then re-enable Crucial and validate Windows chainloading and the remembered-default behaviour, including a Windows restart sequence.
7. Do not run Boot Repair's automatic/recommended repair blindly; inspect its proposed target and actions first.

**Current state:** Linux Mint 22 installation identified; partition roles identified; independent Crucial Windows boot previously proven; Kingston ESP retained as repair target; architecture and saved-default GRUB behaviour agreed. **No EFI rebuild, fstab edit, GRUB installation, formatting, or partition changes have yet been performed.**


### 18/11/26 — Kingston EFI read-only inspection (LIV-INSPECT-01/02)

- Confirmed /dev/sda1 is the Kingston 1 GiB FAT32 ESP, UUID 2CE5-D0E8, PARTUUID da38cc52-46f9-4f68-85dd-fc2555c3c0ed.
- The ESP was not mounted before inspection. It was mounted at /mnt/kingston-efi with verified read-only options (ro,relatime). No write operation was performed.
- The complete file inventory shows a mixed historical EFI:
  - EFI/GRUB/grubx64.efi and EFI/Boot/bootx64.efi are present.
  - EFI/Microsoft/Boot contains bootmgfw.efi, bootmgr.efi, BCD and supporting Microsoft boot resources.
  - A separate root-level grub/ tree contains GRUB configuration, environment, themes, locales and x86_64-efi modules.
  - Root-level vmlinuz-linux, vmlinuz-linux-lts and matching initramfs images are old Arch Linux boot artifacts.
  - System Volume Information is also present.
- This confirms the Kingston ESP contains old Arch/GRUB material and Microsoft boot files; it is not a clean Mint-only EFI. The earlier Windows isolation test already proved that Windows can boot independently from Crucial. The Microsoft files found on Kingston are therefore not required as the Windows independence path, but must be preserved in the pre-repair backup and must not be overwritten during the repair.
- The EFI mount verification showed /dev/sda1 mounted read-only. The earlier mount-state report showed /dev/sda3 and /dev/sda4 automatically mounted read-write by the Live desktop. No evidence in these inspection steps indicates an intentional write to those installed filesystems.
- No content-level validation has yet been made of the fallback EFI executable, the GRUB executable, or the BCD store. Their presence alone does not prove that they are functional or identify the exact boot target.
- The user-facing command output was supplied in chat; the user has local Desktop reports LIV-INSPECT-01-kingston-efi.txt, LIV-INSPECT-01-efi.txt and LIV-INSPECT-02-efi-contents.txt as applicable to the runs.

**Next action:** keep the Kingston ESP mounted read-only while we inspect the installed Mint GRUB defaults/configuration and plan a verified full ESP backup. Before any write, unmount the read-only ESP and prepare an explicit backup destination outside the ESP (preferably the Live USB or another confirmed safe location); verify file count, byte totals and archive integrity. Do not remove or overwrite EFI/Microsoft, EFI/Boot or other existing content until the backup is verified and the exact replacement plan is approved. No fstab edit, GRUB installation, NVRAM write, format or partition change is authorized by this inspection.


## 2026-11-18 — Mint GRUB configuration inspection (LIV-INSPECT-03)

### Verified installed Mint GRUB settings

Read-only inspection of the installed Linux Mint 22 system on Kingston `/dev/sda3` confirmed:

- `GRUB_DEFAULT=saved`
- `GRUB_SAVEDEFAULT=true`
- `GRUB_TIMEOUT_STYLE=menu`
- `GRUB_TIMEOUT=10`
- `GRUB_DISABLE_OS_PROBER=false`

These settings implement the requested remembered-selection behaviour: GRUB saves the selected entry, then defaults to that entry on subsequent boots, with a visible 10-second menu. Preserve these settings in the repaired installation. This is useful for Windows updates that trigger multiple restarts, because Windows remains the saved selection until another entry is selected.

### Stale references identified

- Installed `/boot/grub/grubenv` contains `saved_entry=osprober-efi-72EC-1F03`.
- Installed `/boot/grub/grub.cfg` contains an old Windows Boot Manager entry searching for EFI UUID `72EC-1F03`.
- Actual Kingston EFI partition `/dev/sda1` has UUID `2CE5-D0E8` (PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed`).
- The old Windows entry therefore must not be assumed valid for the current Kingston EFI layout. Regenerate GRUB configuration after mounting the correct EFI partition and correcting the installed fstab.
- The Kingston EFI contains Microsoft boot files as well as legacy GRUB/Arch artefacts. Preserve a full backup before any replacement; do not delete the Microsoft directory as part of the Mint repair.

### Package evidence

Installed package records show `grub-efi-amd64-bin`, `grub-efi-amd64-signed`, `grub2-common`, and `os-prober` installed. The generic `grub-efi` and `grub-efi-amd64` package names are not installed. Confirm the exact package requirements for the repair before installing anything.

### Safety and scope

This inspection was read-only. No partition contents, installed configuration, NVRAM entries, or boot order were changed. Crucial Windows EFI remains outside the repair scope. The next step is to prepare and verify a backup of Kingston EFI, then review the exact proposed file and configuration changes before authorizing writes.


## 2026-11-18 — Kingston EFI backup verified (LIV-BACKUP-01/02)

A full archive of the Kingston EFI partition was created while `/dev/sda1` was mounted read-only at `/mnt/kingston-efi`.

- Source: Kingston `/dev/sda1`, FAT32, UUID `2CE5-D0E8`, PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed`.
- Destination: `/dev/sda4` mounted at `/media/mint/7b6ff1ad-f835-4440-966c-d2c147008b2f`, under `laco/EFI-RECOVERY-BACKUP`.
- Archive: `kingston-efi-20261118T035437Z.tar`.
- Archive size: 542 MiB (reported by `ls -lh`).
- `tar -tf` readability check passed.
- `tar -df archive -C source` reported no differences.
- Entry counts matched after excluding tar's root marker `./`: 581 source entries, 581 archived entries.
- SHA-256: `f724be2e16a11b6ce00ae3b4edb685cb7f169c04dd6085b984dddc4e59566507`.
- Backup destination filesystem had approximately 394 GiB free after archive creation.

The first backup script stopped at an incorrect entry-count comparison because it counted tar's `./` root marker. The follow-up verification corrected this and all checks passed. The second report reached its final line; the user observed a terminal crash/closure, but the report proves verification completed.

This backup is on the same physical Kingston SSD as the EFI, so it protects against mistakes during EFI rebuilding but not whole-drive failure. It may be deleted later at the user's discretion after the repaired boot path is proven and an independent backup is available.

No EFI contents or installed Mint configuration were modified during backup or verification.


## 2026-11-18 — Mint filesystem indicators (LIV-DIAG-05)

Read-only review of the Live USB kernel log and current mounts:

- Kingston `/dev/sda3` (Mint root, ext4 UUID `19705670-12b0-4218-b537-1664f375df4c`) mounted read/write successfully; 492 GiB total, 36 GiB used, 431 GiB available.
- Kingston `/dev/sda4` (Mint home, ext4 UUID `7b6ff1ad-f835-4440-966c-d2c147008b2f`) mounted read/write successfully; 429 GiB total, 14 GiB used, 394 GiB available.
- Kernel log showed normal Kingston device detection, partition discovery, and ext4 mounts.
- The filtered log contained no reported I/O errors, buffer I/O errors, ext4 filesystem errors, journal aborts, or corruption messages for these partitions.

This is encouraging evidence that the earlier legacy Arch/GRUB boot attempts have not left visible filesystem error symptoms in the captured kernel log. It is not a full filesystem integrity check and does not prove every file is intact.

No filesystem repair, partition modification, or installed-system configuration change was performed. Both ext4 filesystems were already mounted read/write by the Live desktop before this diagnostic.


## LIV-INSPECT-06 — Installed Mint GRUB integrity (2026-11-18 04:01 UTC)

Read-only inspection of the installed Mint root filesystem at `/media/mint/19705670-12b0-4218-b537-1664f375df4c`.

- Installed packages include `grub-common`, `grub2-common`, `grub-efi-amd64-bin`, `grub-efi-amd64-signed`, `grub-pc-bin`, and `os-prober`. Query for `grub-common-bin` returned no package; this is not evidence of a missing required component.
- `grub-install`, `update-grub`, `grub-mkconfig`, and `grub-editenv` executables are present.
- EFI module tree `/usr/lib/grub/x86_64-efi` is populated; signed EFI binaries are present under `/usr/lib/grub/x86_64-efi-signed`.
- Package MD5 verification passed for inspected `grub-install`, `update-grub`, the enumerated x86_64-efi modules and signed EFI binaries. This supports package-file integrity for those checked files; it is not a full validation of every installed file or configuration.
- Installed kernel and initramfs files for 6.8.0-90, 6.8.0-139, and 6.8.0-147 are present; current symlinks target 6.8.0-147.
- Existing `/boot/grub/grub.cfg` and `grubenv` are present. The previously inspected generated Windows menu entry and saved_entry still reference EFI UUID `72EC-1F03`, whereas the Kingston ESP UUID is `2CE5-D0E8`.
- Installed `/etc/fstab` still references `72EC-1F03` for `/boot/efi`; the installed `/boot/efi` directory was empty when inspected with the ESP not mounted there.
- No package reinstall, GRUB regeneration, fstab edit, EFI write, NVRAM write, or filesystem repair was performed.

Assessment: installed Mint GRUB package files and kernel/initramfs inventory show no identified corruption in this inspection. The remaining known mismatch is the stale EFI UUID reference in fstab and generated GRUB state. This supports treating the next phase as a controlled EFI mount/configuration repair, subject to a reviewed plan and explicit approval. It does not prove complete filesystem integrity or successful bootability.

## LIV-PREP-09 — Kingston Mint root visibility (2026-11-18 04:24 UTC)

Read-only verification after the user reported that Nemo displayed the Kingston `/home` volume but not the system/root partition:

- Kingston Mint root `/dev/sda3` is mounted at `/mnt/mint-root` as ext4 with `ro,relatime`.
- Installed system directories `/boot`, `/etc`, `/usr`, and `/var` are present.
- Installed `/mnt/mint-root/root` exists with permissions `drwx------` (root-owned, mode 0700).
- Installed `/mnt/mint-root/home` is present as the mount-point directory; the separate `/dev/sda4` home partition is a distinct filesystem.
- `/dev/sda3` capacity report: 492 GiB total, 36 GiB used, 431 GiB available.
- The expected Live-session automount path under `/media/mint/19705670-12b0-4218-b537-1664f375df4c` is not mounted. This is consistent with the root partition having been mounted manually at `/mnt/mint-root`, rather than automatically by the desktop.

Conclusion: the installed Mint root filesystem and its `/root` directory are present and readable. Nemo's failure to show it as a separate automatically mounted volume is a mount-location/UI distinction, not evidence of deletion or loss. The partition remains mounted read-only for recovery inspection.

No files, mounts, permissions, partitions, EFI contents, or boot configuration were changed by this verification.


## 2026-11-18 — Kingston Mint EFI repair in progress (LIV-PREP-10, LIV-REPAIR-01–05)

This section supersedes earlier statements that no fstab, EFI, GRUB, or NVRAM changes had been made. The user approved the Kingston-only repair. Crucial and WDC remain disabled/out of scope during the isolated repair.

### LIV-PREP-10 — signed boot components
- Signed GRUB binary exists at `/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed` (2,660,232 bytes); shim and supporting EFI files are present.
- Secure Boot was confirmed disabled. Inspection itself made no changes.

### LIV-REPAIR-01 — fstab and mount preparation (04:26 UTC)
- Verified Kingston identities: ESP `/dev/sda1` UUID `2CE5-D0E8`; Mint root `/dev/sda3` UUID `19705670-12b0-4218-b537-1664f375df4c`; home `/dev/sda4` UUID `7b6ff1ad-f835-4440-966c-d2c147008b2f`.
- Backed up installed fstab to `/mnt/mint-root/etc/fstab.pre-grub-repair-20261118T042653Z`.
- Corrected only the EFI UUID in fstab from stale `72EC-1F03` to `2CE5-D0E8`.
- Mounted root, home and ESP read-write at the installed-system paths. No repartitioning or formatting.

### LIV-REPAIR-02 — signed UEFI GRUB installation (04:27 UTC)
- Ran from chroot: `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --uefi-secure-boot --no-nvram --recheck`. Installer reported success without errors.
- Created `EFI/ubuntu/grubx64.efi` (2,660,232 bytes), `shimx64.efi` (966,664), `mmx64.efi` (856,280), `BOOTX64.CSV` (108), and `grub.cfg` (126).
- Existing `EFI/Boot`, `EFI/GRUB`, and `EFI/Microsoft` directories remained present. `--no-nvram` avoided firmware changes in this stage.

### LIV-REPAIR-03 — GRUB menu regenerated (04:28 UTC)
- `update-grub` detected kernels/initramfs 6.8.0-147, 6.8.0-139, and 6.8.0-90.
- Mint menu ID: `gnulinux-simple-19705670-12b0-4218-b537-1664f375df4c`; generated root references use the correct Mint root UUID.
- Old EFI UUID `72EC-1F03` is absent from regenerated grub.cfg.
- GRUB settings remain `GRUB_DEFAULT=saved`, `GRUB_SAVEDEFAULT=true`, `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=10`, `GRUB_DISABLE_OS_PROBER=false`.
- os-prober found Windows Boot Manager on `/dev/sda1`, the historical Kingston ESP. This is not the independent Crucial Windows installation and is not evidence that Crucial Windows was detected.

### LIV-REPAIR-04 — syntax and saved default (04:28 UTC)
- `grub-script-check /boot/grub/grub.cfg` passed.
- Set grubenv saved_entry to the Mint menu ID above, replacing the stale saved Windows ID.
- Confirmed requested timeout and saved-selection settings. Existing BootOrder before new registration was `0003,000B,000C`.

### LIV-REPAIR-05 — Mint UEFI entry registered (04:29 UTC)
- Created entry with `efibootmgr --create-only --disk /dev/sda --part 1 --label "Linux Mint (Kingston)" --loader '\EFI\ubuntu\shimx64.efi'`.
- Firmware created Boot0000* Linux Mint (Kingston), targeting Kingston ESP PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed` and loader `\EFI\ubuntu\shimx64.efi`.
- BootOrder remained `0003,000B,000C`; Windows Boot0003, generic Kingston Boot000B and USB Boot000C remain unchanged.
- New Mint entry is registered but not yet boot-tested.

### Current state / next actions
Repair stages 1–5 completed; Mint has not yet booted from the new entry. Before reboot, verify Boot0000 and set one-time BootNext=0000 (do not permanently reorder BootOrder), then cleanly unmount installed filesystems and chroot bind mounts. Keep Crucial and WDC disabled for the first Mint boot test. Retain the verified Kingston EFI backup and historical EFI directories.

After Mint boots, re-enable Crucial in a separate phase and configure/test Windows chainloading from Crucial's independent Microsoft EFI. The os-prober Windows entry currently points to the historical Kingston EFI and must not be used as the final Windows path.

Thermal instability may be related to Live-session fan/graphics behaviour, as the user suspects, but causation has not been established. Keep remaining Live-session work brief and stop if the machine becomes unusually hot or unstable.

## 2026-11-18 — Kingston standalone Mint boot SUCCESS (LIV-REPAIR-06)

The rebuilt Kingston EFI boot path has now completed its first real boot into the installed Linux Mint Cinnamon desktop. This supersedes the previous status that Boot0000 was registered but not yet tested.

### One-time boot and clean shutdown of recovery environment
- Before leaving the Live USB, verified Boot0000* `Linux Mint (Kingston)` points to Kingston ESP PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed` and loader `\EFI\ubuntu\shimx64.efi`.
- An initial preparation script stopped because it checked an obsolete temporary mountpoint (`/mnt/kingston-efi`). No unmount or BootNext operation occurred in that failed attempt.
- Corrected the check to the actual installed-system mount path `/mnt/mint-root/boot/efi`. The second run successfully unmounted chroot bind mounts, installed EFI, installed home and installed root without force/lazy unmounting.
- Set one-time `BootNext=0000`. Verified permanent `BootOrder=0003,000B,000C` was unchanged. Kingston root and EFI were unmounted before reboot; the Live session's separate `/dev/sda4` backup/home mount remained mounted.
- The user rebooted and reached the installed Mint Cinnamon desktop. This is a successful standalone Kingston boot with Crucial and WDC still disabled. It validates the new Kingston firmware entry, signed shim/GRUB path, generated Mint GRUB configuration and installed Mint system working together. The exact GRUB menu display/timeout behaviour was not separately reported, so retain that as pending visual confirmation.

### Installed system evidence after successful boot
User-provided system report:
- OS: Linux Mint 22 x86_64; Cinnamon 6.4.8; X11/Muffin.
- Host: Dell Precision M4800.
- Running kernel: `6.8.0-147-generic`.
- External Samsung U28D590 display active at 3840×2160, 60 Hz.
- Root filesystem: 35.77 GiB used of 491.08 GiB; `/home`: 13.61 GiB used of 428.94 GiB.
- NVIDIA Quadro K2100M detected; NVIDIA 470.256.02 loaded and verified.
- `secureupdate` pre- and post-upgrade checks both confirmed NVIDIA 470.256.02 loaded and its DKMS module installed for kernel 6.8.0-147.

### Package update performed after first boot
The user's `secureupdate` completed an APT upgrade:
- 56 packages upgraded, 0 newly installed, 0 removed; 16 not upgraded.
- 497 MB downloaded; package configuration and initramfs regeneration completed.
- Initramfs regenerated for kernel 6.8.0-147 and reported resume UUID `d6475051-4ba4-4aa2-966a-309575fe1d13` (Kingston swap).
- APT reported phased updates for Mesa-related packages and kept back `linux-generic`, `linux-headers-generic`, `linux-image-generic`, `nvidia-dkms-470-server`, and `nvidia-driver-470-server`.
- No autoremove candidates were proposed.
- Post-upgrade verification still showed kernel 6.8.0-147 running and NVIDIA 470.256.02 loaded/installed for that kernel.
- DKMS inventory also showed `nvidia/580.178.04` installed for kernel 6.8.0-139 and built for 6.8.0-147, alongside the active 470.256.02 module. This is an observed coexistence state; do not remove, switch, or rebuild drivers without a separate reviewed diagnosis.

### Updated status and next phase
- **Kingston standalone Linux Mint boot: OK / SUCCESS.**
- **Crucial independent Windows boot: previously OK**, tested with Kingston disabled.
- **WDC data disk: untouched / out of scope.**
- Kingston EFI recovery archive remains at `/dev/sda4` under `laco/EFI-RECOVERY-BACKUP`; retain it until the complete dual-boot configuration is validated and an independent backup exists.
- Do not change kernel or NVIDIA driver state as part of the EFI work.
- Next, perform a short read-only audit from the installed Mint system: current firmware BootCurrent/BootOrder, `findmnt` for `/`, `/home`, `/boot/efi`, `grub-editenv list`, and GRUB defaults. Confirm the remembered Mint saved entry and inspect the visible GRUB timeout behaviour if it was not observed during the successful boot.
- Only after the Kingston boot is stable, re-enable the Crucial disk (leave WDC disabled initially if practical), identify its current ESP PARTUUID from Linux, and add a deliberate GRUB chainloader entry to the Crucial `EFI/Microsoft/Boot/bootmgfw.efi`. Do not use the historical Kingston Microsoft entry found by os-prober as the final Windows route. Preserve the independent Crucial Windows EFI.
- Later test Windows via the new GRUB entry, then test the user's desired saved-default/10-second behaviour. Update the firmware-entry register only from fresh `efibootmgr -v` evidence; do not assume the one-time BootNext entry was promoted into permanent BootOrder.

## 2026-11-18 — Post-boot firmware audit (LIV-REPAIR-07)

The installed Mint system reported the following read-only audit at 04:43:12 UTC:

- `BootCurrent: 0000`: the machine booted through the newly registered `Linux Mint (Kingston)` entry.
- `BootNext` is absent, confirming the one-time boot request has been consumed.
- Permanent `BootOrder=0003,0001,000B` does **not** include `Boot0000`. Therefore the successful Mint boot is not yet the default firmware boot route.
- `Boot0003` remains the Windows Boot Manager entry targeting Crucial ESP PARTUUID `775149ef-10c2-4c7b-8192-fe8786b1ad41`.
- `Boot0001` is the older `grub` entry targeting Kingston `EFI/GRUB/grubx64.efi`; retain it, but do not prefer it over the newly tested Mint shim path.
- `Boot000B` remains the generic Kingston device entry.
- GRUB saved environment still contains `saved_entry=gnulinux-simple-19705670-12b0-4218-b537-1664f375df4c`.
- GRUB defaults remain `GRUB_DEFAULT=saved`, `GRUB_SAVEDEFAULT=true`, `GRUB_TIMEOUT_STYLE=menu`, and `GRUB_TIMEOUT=10`.
- Running kernel remains `6.8.0-147-generic`.

### Next controlled change

Before any further reboot, make the tested Mint entry permanent first in firmware BootOrder while preserving the existing Windows and legacy entries. Proposed order: `0000,0003,0001,000B`. This changes only NVRAM boot priority; it does not delete or rewrite any EFI files or boot entries. Verify the resulting BootOrder immediately. The mounted-filesystem audit command returned no rows for its multi-target invocation, so separately verify `/`, `/home`, and `/boot/efi` mount state during the next read-only check; do not infer mount failure from that ambiguous output.

GRUB menu visibility and actual 10-second timeout behaviour remain pending direct visual confirmation.


## 2026-11-18 — Permanent Mint-first firmware order verified (LIV-REPAIR-08)

From the installed Mint system, the user applied `efibootmgr -o 0000,0003,0001,000B` and immediately re-read the full firmware state.

- Verified permanent `BootOrder=0000,0003,0001,000B`.
- `Boot0000*` is Linux Mint (Kingston), targeting Kingston ESP PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed`, loader `\EFI\ubuntu\shimx64.efi`.
- `Boot0003` Windows Boot Manager remains present and targets the Crucial ESP PARTUUID `775149ef-10c2-4c7b-8192-fe8786b1ad41`.
- `Boot0001*` legacy Kingston GRUB and `Boot000B*` generic Kingston device entry remain present.
- `BootCurrent=0000`; no BootNext is shown.
- No EFI files or partitions were changed by this NVRAM priority operation.

Status: **Mint-first permanent firmware order — PASS.** Do not infer the separate mounted-filesystem state from the earlier empty multi-target `findmnt` output; inspect each mount explicitly before proceeding with Crucial reactivation.


## 2026-11-18 — Installed Mint mount topology verified (LIV-REPAIR-09)

Read-only mount and block-device audit from the installed Mint session:

- Root `/`: `/dev/sda3`, ext4, mounted read-write; UUID `19705670-12b0-4218-b537-1664f375df4c`.
- Home `/home`: `/dev/sda4`, ext4, mounted read-write; UUID `7b6ff1ad-f835-4440-966c-d2c147008b2f`.
- EFI `/boot/efi`: `/dev/sda1`, vfat, mounted read-write; UUID `2CE5-D0E8`, PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed`.
- Kingston swap: `/dev/sda2`, UUID `d6475051-4ba4-4aa2-966a-309575fe1d13`, active as swap.
- The block-device listing shows only the Kingston SSD (`/dev/sda`) in this running system. Crucial and WDC were not present in this inventory.

Status: **Installed Mint root/home/EFI mount topology — PASS.** The EFI partition is mounted read-write, but this audit performed no writes. Before re-enabling other drives, retain the scope boundary: re-enable Crucial only; keep WDC data disk disabled. Once booted, identify Crucial by model/size/partition UUID rather than assuming a device letter/name, and inspect its ESP read-only.

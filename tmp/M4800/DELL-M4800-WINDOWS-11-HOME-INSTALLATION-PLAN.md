# Dell Precision M4800 — Windows 11 Home Clean Installation Plan

**Project status:** Preparation / evidence collection  
**Target device:** Dell Precision M4800  
**Target OS edition:** Windows 11 Home x64  
**Last updated:** 2026-11-14  
**Installation status:** NOT APPROVED — do not format or begin installation until the pre-flight gates below are closed.

> This document is a controlled installation plan. It is deliberately not a one-shot install recipe. Exact hardware IDs, BIOS mode, disk layout, current driver versions, licence activation, and the iPhone/iTunes migration state must be captured before selecting final binaries.

## 1. Project objectives and non-negotiable risks

The M4800 was reported fully operational before the recent Windows update sequence. The current Windows 11 Pro installation developed several problems after that sequence, including loss of activation. The decision is to stop spending time repairing that Pro installation and prepare a clean Windows 11 Home installation using the user's unused physical Windows 10 Home retail package.

Primary goals:

1. Establish a known, reproducible Windows 11 Home installation baseline.
2. Select the Windows build and installation media deliberately; avoid unnecessary post-install update churn.
3. Preserve the known-good NVIDIA driver path for the Quadro K2100M.
4. Identify every required Dell/Intel/Realtek/O2 Micro/device driver from the actual machine inventory.
5. Preserve the iTunes library, playlists, media, and iPhone state so that the new installation does not trigger a destructive re-sync.
6. Keep Windows Update under manual review after the baseline is proven.

**Critical stop condition:** Do not erase or repartition any disk until the iTunes preservation gate, licence gate, hardware inventory, and target-disk identification are complete.

## 2. Known hardware and software facts

| Item | Current evidence | Status |
|---|---|---|
| Laptop | Dell Precision M4800 | Confirmed |
| Platform generation | 4th-generation Intel Core platform; Mobile Intel QM87 chipset | Dell specification |
| GPU | NVIDIA Quadro K2100M | Confirmed from project history |
| TPM | TPM 1.2; no TPM 2.0 | Reported; verify in BIOS / Windows |
| Current OS | Windows 11 Pro 25H2 x64 | Confirmed from recent troubleshooting |
| Current build | 26200.9974 after November 2026 update sequence | Confirmed from recent troubleshooting |
| Target OS | Windows 11 Home x64 | Decision |
| Home licence | Physical Windows 10 Home retail package, USB + key, reportedly unused and purchased from Microsoft Store | User-reported; activation not yet proven |
| iTunes app | Microsoft Store iTunes package currently installed; package path recorded as `C:\Program Files\WindowsApps\AppleInc.iTunes_12139.10003.61011.0_x64__nzyj5cx40ttqa\iTunes.exe` | Package identity recorded; media/library location unknown |
| CPU exact model | Not yet captured | Speccy / read-only inventory required |
| RAM, disks, partition map, BIOS version/mode | Not yet captured in this project document | Required |
| Wi-Fi, Ethernet, Bluetooth, audio codec, touchpad, card reader, webcam, fingerprint reader | Exact IDs unknown | Required |

Dell's M4800 specification sheet lists 4th-generation Intel Core processors, QM87, and Quadro K2100M as an available graphics option: https://i.dell.com/sites/doccontent/shared-content/data-sheets/en/Documents/CSG-EN-XX-ALL-Dell-Precision-M4800-Spec-Sheet.pdf

## 3. Windows edition, release and build decision

### 3.1 Edition

Target **Windows 11 Home x64**. Home and Pro share the same core hardware compatibility requirements; changing edition does not remove the TPM/CPU unsupported-hardware warning. The Home retail key must be validated before the current installation is wiped.

### 3.2 Recommended initial release target

**Provisional target: Windows 11, version 25H2, x64, build 26200.9974 (November 10, 2026 cumulative update level).**

Why this is the starting candidate:

- The current M4800 has already been running the 25H2 servicing branch (build 26200).
- It avoids introducing a new feature-version transition at the same time as a clean installation and driver migration.
- Microsoft's release information identifies the November 10, 2026 25H2 security update as KB5132061, build 26200.9974: https://support.microsoft.com/en-gb/servicing/os/windows-11/2026/11/kb5132061-windows-11-24h2-25h2-26h2-security-update
- The Windows release-health page is the authority to re-check immediately before generating media: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information

This is a **candidate baseline, not a guarantee that 25H2 is the newest Windows 11 feature release**. A newer feature release may exist by the time the USB is built. Do not automatically choose it: first assess its hardware/driver changes and whether it offers a meaningful benefit to this 2013-era platform. Record the exact ISO/UUP build and date in the final installation record.

### 3.3 Avoiding post-install updates

The objective should be to create installation media with the selected servicing level already integrated, not to install an old base image and immediately expose it to a large update backlog.

Important distinction:

- A UUP-converted ISO can include the selected cumulative update packages if the selected UUP set/build includes them.
- An ISO at build 26200.9974 should not need KB5132061 applied again after installation.
- This does **not** mean Windows will never request servicing-stack, Defender, Store, driver, or later security updates. Nor can the media prevent Windows from discovering later updates if online update services are enabled.
- Microsoft documents checkpoint cumulative updates for 24H2+; a later MSU installation may require checkpoint packages in order. KB5132061's instructions explicitly list KB5043080 as a required checkpoint package for manual Catalog installation. Do not assume a generated UUP ISO or an offline installation has successfully installed a checkpoint until the image/build state is verified.

### 3.4 UUP / ISO / Rufus media policy

Provisional media recipe:

1. Select **Windows 11 25H2 x64**, consumer edition set that includes **Home**.
2. Select the exact target build and cumulative update level after checking Microsoft's release-health page on the day media is generated. Current candidate: **26200.9974 / KB5132061**.
3. Use UUP files sourced from Microsoft's update infrastructure; the UUP conversion script/tool is third-party and must be reviewed as such. Preserve the source package list, conversion logs, and generated ISO SHA-256.
4. Verify the generated image contains Windows 11 Home. Record the `install.wim` or `install.esd` edition index list (for example with DISM `/Get-WimInfo`) before writing the USB.
5. Use current Rufus to write the ISO. Rufus' unsupported-hardware bypass options are presented after selecting START; verify the exact options in the version being used. The M4800 does not meet the TPM 2.0 requirement. A bypass does not make the device officially supported.
6. Do not pre-integrate random driver packs, debloat scripts, registry tweaks, or third-party customisations into the ISO. Keep OS media and hardware drivers separate so each change can be diagnosed.
7. Preserve the ISO, UUP package list, conversion logs, Rufus version/settings, and USB verification result.

**Do not select an older 25H2 build merely to avoid updates** unless a documented compatibility issue justifies it. An older image creates a servicing backlog and does not inherently make the machine safer. Prefer the latest tested 25H2 cumulative level available at the time of installation, but do not jump feature versions without a separate decision.

Rufus FAQ: https://github.com/pbatard/rufus/wiki/FAQ  
Microsoft Windows 11 download page: https://www.microsoft.com/software-download/windows11

## 4. Unsupported hardware / M4800 field evidence

The M4800 is a Haswell-generation workstation. Its TPM 1.2 status alone is enough to fail the Windows 11 TPM 2.0 requirement. Exact CPU model and Secure Boot/UEFI state must still be inventoried.

A directly relevant M4800 user report describes a Windows 11 installation/upgrade using Rufus media and discusses MBR-to-GPT conversion and UEFI settings. It is a single community report, not a validated procedure and not evidence that every M4800 configuration works: https://www.reddit.com/r/WindowsHelp/comments/1o5hc30/win_10_to_win_11_upgrade_of_dell_pression_m4800/

**Important:** Do not copy that report's MBR-to-GPT commands. The correct process depends on the actual partition map, boot mode, and disk number. We will inspect first. No conversion command is authorised by this document.

Dell's support page for the M4800 should be checked for original model-specific packages and service-tag-specific options: https://www.dell.com/support/home/en-us/product-support/product/precision-m4800-workstation/drivers

## 5. NVIDIA Quadro K2100M driver decision

**Known preferred driver: NVIDIA Quadro Release 418 R418 U9, version 426.78, Windows 10 64-bit.**

- Driver version: **426.78**
- Windows driver version string: **25.21.14.2678**
- NVIDIA release: **R418 U9 / WHQL**
- NVIDIA's official package lists Quadro K2100M among supported notebook products.
- NVIDIA states that R418 is the final professional driver branch for Quadro Kepler notebook GPUs; later Quadro branches do not support these products.
- Official driver page: https://www.nvidia.com/fr-fr/drivers/details/160529/
- NVIDIA Kepler notebook support notice: https://nvidia.custhelp.com/app/answers/detail/a_id/4788

The driver is officially listed for Windows 10 64-bit, not Windows 11. Using it on Windows 11 is therefore a compatibility choice based on the existing working configuration, not a claim of official Windows 11 certification.

**Policy:** Preserve the exact 426.78 installer that was used successfully. Do not chase a higher version number, install an R470 package, use a modified INF, or let Windows Update replace the driver during baseline setup. First verify the hardware ID and current driver details with Speccy/Device Manager. Test display, external monitor(s), resolution, sleep/resume, video acceleration, and NVIDIA Control Panel before accepting the baseline.

Intel integrated graphics is also likely present on this generation, but its exact GPU and driver must be derived from the CPU/hardware inventory. Do not assume the Intel HD Graphics model until verified.

## 6. Post-installation driver checklist

This is a **discovery checklist**, not an instruction to install every listed category. Install only packages that match a detected device/hardware ID.

| Order | Component | Candidate / source | Verification |
|---|---|---|---|
| 1 | Intel chipset device identification (QM87) | Dell M4800 support package / Intel chipset INF | Device Manager: no unknown chipset/system devices |
| 2 | Intel Management Engine Interface | Dell M4800 MEI package; exact version to match hardware | MEI device status and event logs |
| 3 | Intel integrated graphics | Match exact CPU/GPU ID; Dell/Intel legacy package | Internal display, brightness, sleep/resume |
| 4 | NVIDIA Quadro K2100M | 426.78 / 25.21.14.2678 candidate | Device status, NVIDIA Control Panel, external display |
| 5 | Realtek HD Audio codec | Match detected codec and Dell package | Speakers, headphone jack, microphone, HDMI audio if applicable |
| 6 | Ethernet controller | Identify exact Intel/Broadcom/other PCI ID | Wired network, link negotiation, sleep/resume |
| 7 | Wi-Fi adapter | Identify exact adapter (e.g. Intel 7260/7265 family only if confirmed) | 2.4/5 GHz, throughput, reconnect |
| 8 | Bluetooth | Match Wi-Fi/Bluetooth module and hardware ID | Pairing, audio/peripherals, reconnect |
| 9 | O2 Micro card reader | Only if present; model-specific Dell package | SD card mount/read/write |
| 10 | ST Microelectronics free-fall sensor | Only if present | Device Manager and no errors |
| 11 | Touchpad / pointing device | Identify Alps/Synaptics/etc. from hardware ID | Gestures, buttons, external mouse |
| 12 | Webcam | Usually USB class driver; confirm device ID | Camera app / video call test |
| 13 | Fingerprint reader / smart-card reader | Only if physically fitted | Device Manager and reader test |
| 14 | Dell hotkeys / function keys / QuickSet components | Only if needed and compatible | Brightness, volume, keyboard Fn functions |
| 15 | Dock / port replicator / external display interfaces | Based on actual dock and ports | All required dock ports, monitors, Ethernet, USB |
| 16 | USB controllers / storage controllers | Windows inbox first; Dell package only if device requires it | USB 2/3 ports, external storage, sleep/resume |

Historical package references worth validating against Dell's official M4800 page (not yet approved as final binary versions): Intel Chipset 10.1.1.18 A04; Intel MEI 11.7.0.1035; Realtek ALC32xx audio 6.0.1.6098 A12; O2 Micro card reader 3.0.8.38 A04; ST Micro free-fall sensor 4.10.55 A00. These are legacy package candidates, not a blanket recommendation to install them. Confirm hardware IDs, package signatures, OS compatibility, and current Dell download availability before use.

### Driver installation rules

- Keep a local offline driver folder on a separate storage device.
- Download only from Dell, Intel, NVIDIA, or the actual component vendor.
- Record filename, version, release date, source URL, signature status, and SHA-256.
- Install in dependency-aware order; reboot only when required.
- Do not install Dell SupportAssist or automatic driver-updater utilities as a prerequisite.
- Do not allow Windows Update to replace the known-good NVIDIA driver during baseline validation.
- After each driver group, capture Device Manager status and test relevant functions.

## 7. iTunes and iPhone preservation — critical project gate

### 7.1 Why this is the highest-risk part

Apple explicitly distinguishes a device backup from a media sync. A computer backup does **not** include content synced from a PC, such as imported MP3s/CDs, videos, books, and photos. Therefore, an iPhone backup alone cannot be relied upon to restore the music and playlists that were synced from this iTunes library.

Apple references:
- Move the complete iTunes library to another computer: https://support.apple.com/guide/itunes/move-your-itunes-library-to-another-computer-itns3230/windows
- Apple backup exclusions: https://support.apple.com/en-gb/108771
- Apple Devices backup and restore: https://support.apple.com/guide/devices-windows/back-up-and-restore-your-device-mchla3c8ed03/windows
- iTunes sync guide: https://support.apple.com/en-gb/108347

### 7.2 Existing iTunes installation evidence

The current machine uses the Microsoft Store iTunes package. Recorded executable path:

`C:\Program Files\WindowsApps\AppleInc.iTunes_12139.10003.61011.0_x64__nzyj5cx40ttqa\iTunes.exe`

This is the application package path, **not proof of the media-library location**. We must discover the actual library and media paths from iTunes Preferences and the filesystem before migration.

### 7.3 Preservation protocol before Windows reinstall

Do not connect the iPhone to the new iTunes installation until the following are complete:

1. Record iTunes version, Apple Account authorisation state, device model/iOS version, sync mode, and whether Apple Music / Sync Library / iCloud Music Library is enabled.
2. In iTunes, record the exact **iTunes Media folder location** from Edit > Preferences > Advanced.
3. Record the active library file location. Preserve the complete iTunes library folder, including `iTunes Library.itl`, `iTunes Library.xml` if present, `Album Artwork`, `Previous iTunes Libraries`, and the complete media tree.
4. If media is stored outside the iTunes folder, map every referenced location. Do not assume that copying only `Music\iTunes` captures all tracks.
5. If practical, use File > Library > Organize Library > Consolidate Files, then verify that the media is actually present in the consolidated copy. Consolidation copies files into the iTunes media folder; it does not erase the originals.
6. Export playlists individually or in batches as additional readable backups (XML where supported; M3U where useful). Capture screenshots or a playlist/count inventory for critical playlists. Exported playlists are a secondary recovery aid; they do not replace the original library database.
7. Quit iTunes fully, then make at least two independent copies of the complete library/media data. Keep one copy physically disconnected during OS installation.
8. Generate SHA-256 manifests for the backup copies and verify that the copies match. Open/test the backup on a separate copy, never the only preserved original.
9. Create a fresh encrypted local iPhone backup using Apple Devices or iTunes and preserve its backup folder separately. Store its encryption password safely. This protects device data/settings but does **not** back up PC-synced music.
10. Preserve the existing iPhone sync relationship by keeping the original iTunes library database intact. Apple documents restoring the full library and choosing the original `iTunes Library.itl` by holding Shift while launching iTunes. This is the strongest supported migration route; it is not a guarantee that every iPhone pairing/sync state survives an app/OS migration.
11. Keep the iPhone disconnected during the Windows installation, driver setup, iTunes installation, library restoration, and first library validation.

### 7.4 Safe first launch on the new Windows installation

1. Install the same iTunes app family if possible (Microsoft Store version vs classic desktop installer must be decided deliberately; do not mix them casually).
2. Before launching, restore the library backup to its intended path, or launch iTunes with Shift and explicitly choose the restored `iTunes Library.itl`.
3. Verify library identity/content: song count, playlist count, playlist membership, ratings, play counts, artwork, file paths, and missing-file status.
4. Confirm that the library is not an empty/new library and that all expected media is available.
5. Confirm Apple Account authorisation as required, without starting a device sync.
6. Only after the desktop library is proven should the iPhone be connected. Disable automatic sync where possible before connection. Do not click Sync, Apply, Restore, Erase and Sync, or any prompt that proposes replacing/removing device content.
7. Photograph/capture any device prompt and stop if iTunes indicates that the device is associated with another library or that media will be replaced. Investigate the exact message before proceeding.

**The “trick” we are investigating:** restore the original library database and media so the new installation is a continuation of the old iTunes library rather than a newly created library. The original library database carries library metadata and identity used by iTunes. However, Apple does not publicly guarantee that restoring the database alone will preserve every device pairing or prevent all erase-and-sync prompts. We must validate this on a safe copy and treat the first iPhone connection as a controlled test, not a routine step.

### 7.5 Facts still needed from the user

- iPhone model and iOS version.
- Whether the iPhone's music is manually managed or automatically synced.
- Whether Apple Music / Sync Library / iCloud Music Library is enabled.
- Whether the iPhone contains tracks that no longer exist on the PC.
- Whether all source music files are stored locally on the PC, on D:, or elsewhere.
- Whether the iTunes library is currently on C: or D:.
- Whether any playlists are Smart Playlists, and whether ratings/play counts matter.
- Whether the user uses the Apple Music app or only iTunes for the Windows library.

## 8. Licence and activation gate

The target is Windows 11 Home, not Pro. The physical Windows 10 Home retail key is reported unused and bought from Microsoft Store. Community reports show Windows 10 Home keys have activated clean Windows 11 Home installations, but this is not a Microsoft guarantee for every key or licence history.

Before wiping:

- Photograph/record the package and product edition (do not publish the product key in GitHub or chat).
- Verify the key is genuinely Home and retail, not OEM, volume, or already consumed.
- If possible, test activation on a spare SSD in this same M4800 before wiping the current system.
- Do not expose the product key in scripts, logs, screenshots, or repository documents.
- During setup, explicitly ensure Windows 11 Home is selected. Do not let an embedded firmware key silently select a different edition.
- After installation, check Settings > System > Activation and `slmgr /dlv`; record only edition/channel/status, never the full key.

No clean-install action is authorised until the licence risk is acceptable to the user.

## 9. Manual update policy after installation

The aim is controlled updates, not permanent isolation from security fixes.

1. Establish and document a clean baseline before applying additional updates.
2. Keep cumulative/preview/driver updates under manual review; do not install optional preview updates without a specific reason.
3. Before each monthly update, review Microsoft's release-health page, KB notes, known issues, prerequisites, supersedence, and checkpoint requirements.
4. Download MSUs only from Microsoft Update Catalog.
5. For 24H2/25H2/26H2 packages, inspect whether checkpoint cumulative updates are required and install in the documented order.
6. Apply one update cycle at a time; reboot and validate activation, Device Manager, NVIDIA, audio, network, external display, sleep/resume, search, and iTunes library.
7. Keep a rollback/restore image before major update cycles.
8. Understand that manually installing MSUs does not make the update itself safer and does not prevent every update channel (Defender intelligence, Store apps, driver delivery, etc.) from changing independently.
9. Unsupported hardware may not be guaranteed future Windows updates by Microsoft. Maintain a recovery path and do not assume the current bypass remains valid forever.

## 10. Speccy and read-only inventory — next action

The user plans to install Speccy to extract system information. Before selecting final binaries, capture:

- CPU exact model, stepping, instruction-set support (especially POPCNT and SSE4.2).
- Motherboard/system model, BIOS version/date, UEFI/Legacy mode, Secure Boot state.
- TPM specification version and status.
- RAM modules, capacity, speed.
- Every physical disk: model, firmware, capacity, partition style, partition layout, BitLocker state, and which disk contains Windows.
- GPU names and hardware IDs (Intel iGPU and NVIDIA).
- Audio codec and device IDs.
- Ethernet, Wi-Fi, Bluetooth model and hardware IDs.
- Touchpad, card reader, webcam, fingerprint/smart-card, free-fall sensor, dock devices.
- Monitor model/resolution and external display connection path.
- Current driver versions for all listed devices.

Speccy is useful for an overview, but hardware IDs and exact driver versions should also be captured from Device Manager / PowerShell. Do not post serial numbers, Windows product keys, Wi-Fi passwords, BitLocker recovery keys, or other secrets to GitHub.

## 11. Installation readiness checklist

### Before media creation
- [ ] Speccy report captured and reviewed.
- [ ] Exact CPU model and POPCNT/SSE4.2 verified.
- [ ] BIOS mode, Secure Boot state, TPM 1.2 state recorded.
- [ ] Disk/partition map captured; target disk unambiguously identified.
- [ ] BitLocker recovery key secured offline; D: data disk backed up.
- [ ] iTunes library/media paths identified.
- [ ] Full iTunes library and media backed up twice and hash-verified.
- [ ] Playlists exported and inventoried.
- [ ] Encrypted iPhone backup completed and password safely retained.
- [ ] iPhone remains disconnected from any new iTunes installation.
- [ ] Home retail key/edition checked without disclosing the key.
- [ ] NVIDIA 426.78 installer preserved and hash recorded.
- [ ] Dell/Intel/Realtek/O2 Micro driver candidates matched to actual hardware IDs.

### Media
- [ ] Windows 11 25H2 x64 selected, or a later feature version explicitly approved.
- [ ] Target cumulative build/date recorded.
- [ ] Home edition index confirmed in generated image.
- [ ] UUP package list and conversion logs saved.
- [ ] ISO SHA-256 recorded.
- [ ] Rufus version and unsupported-hardware options recorded.
- [ ] USB verified.

### Installation and validation
- [ ] Data disk physically disconnected if practical, or otherwise positively protected from selection.
- [ ] Only the intended OS disk is targeted.
- [ ] Windows 11 Home installed.
- [ ] Activation checked before extensive configuration.
- [ ] Drivers installed from the approved offline set.
- [ ] NVIDIA/external display/audio/network/sleep tests passed.
- [ ] Windows baseline image created.
- [ ] iTunes restored from original library database and verified while iPhone disconnected.
- [ ] iPhone first connection performed only after sync settings are checked and a no-sync test is planned.
- [ ] First manual update cycle separately reviewed and validated.

## 12. Current decision register

| Topic | Current decision | Confidence |
|---|---|---|
| Windows edition | Windows 11 Home x64 | High |
| Feature release | 25H2 provisional; avoid an untested feature-version jump | Medium |
| Build | 26200.9974 / KB5132061 candidate as of 2026-11-14 | High for published release; media availability still to verify |
| NVIDIA | Preserve 426.78 / 25.21.14.2678 | High as known compatible historical driver; Windows 11 certification not claimed |
| Other drivers | Inventory first, then exact match | Pending |
| Rufus | Current official Rufus with TPM bypass options | Pending version check at media build |
| iTunes | Restore complete original library/database before any iPhone connection | Critical |
| iPhone sync | No sync or erase action until first-connection behaviour is understood | Critical |
| Licence | Verify physical Windows 10 Home retail key before wipe | Critical |
| Installation | Not yet authorised | Not ready |

## 13. Sources

- Dell Precision M4800 specification sheet: https://i.dell.com/sites/doccontent/shared-content/data-sheets/en/Documents/CSG-EN-XX-ALL-Dell-Precision-M4800-Spec-Sheet.pdf
- Dell M4800 driver/support page: https://www.dell.com/support/home/en-us/product-support/product/precision-m4800-workstation/drivers
- Microsoft Windows 11 release health: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
- Microsoft KB5132061 (November 10, 2026): https://support.microsoft.com/en-gb/servicing/os/windows-11/2026/11/kb5132061-windows-11-24h2-25h2-26h2-security-update
- Rufus FAQ: https://github.com/pbatard/rufus/wiki/FAQ
- NVIDIA Quadro 426.78: https://www.nvidia.com/fr-fr/drivers/details/160529/
- NVIDIA Quadro Kepler notebook support end: https://nvidia.custhelp.com/app/answers/detail/a_id/4788
- Apple — Move your iTunes library: https://support.apple.com/guide/itunes/move-your-itunes-library-to-another-computer-itns3230/windows
- Apple — iPhone backup exclusions: https://support.apple.com/en-gb/108771
- Apple — Apple Devices backup/restore: https://support.apple.com/guide/devices-windows/back-up-and-restore-your-device-mchla3c8ed03/windows
- Apple — iTunes sync: https://support.apple.com/en-gb/108347
- M4800 Windows 11 community report (single-user anecdote): https://www.reddit.com/r/WindowsHelp/comments/1o5hc30/win_10_to_win_11_upgrade_of_dell_pression_m4800/

---

**Next checkpoint:** Review the Speccy report and extract hardware IDs / disk layout. Then replace provisional entries with exact approved binary filenames, versions, URLs, and SHA-256 hashes. Do not proceed to formatting before the iTunes migration plan is validated.

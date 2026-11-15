# Roadbook - Windows VM / ISO caveats

**Current position:** The generated Windows 11 Home ISO installed **Windows 11 Home 24H2, build 26100.1**, although the selected UUP source was **25H2, build 26200.10066**. A separate Windows 11 Pro 25H2 ISO (build 26200.9974, filename recorded below) has already been generated and is available for a later controlled VM comparison. The current audit has identified the converter configuration and verified the downloaded eKB CAB, but has **not yet proved that the eKB was successfully integrated into the Home install image**. No UUP conversion is currently running. **Do not replace the existing Windows 11 Pro installation.**

| Date | Time | Entry | Decisions / Actions / Results / Remarks |
|:---:|:---:|:---:|:---|
| 15/11/26 | — | **Decision** | Use the already-installed Windows 11 Home 24H2 VM as the next controlled test target. Test the 25H2 enablement package (KB5054156) before changing the ISO-generation or Dockur deployment protocol. |
| | | **Action** | Proposed: obtain the x64 KB5054156 .msu package and install it on the Home 24H2 VM with WUSA: `wusa.exe C:\\Path\\To\\windows11.0-kb5054156-x64.msu /quiet /norestart`. First verify the currently installed OS build and that prerequisite KB5064081 (build 26100.5074) or a later cumulative update is installed. |
| | | **Result** | **PENDING.** No package installation or post-install verification has been performed yet. |
| | | **Remark** | Microsoft documents KB5054156 as the 24H2 → 25H2 enablement package for Home and Pro, and requires KB5064081 (26100.5074) or a later cumulative update. The previously recorded Home build was 26100.1, which is below that prerequisite; therefore do not run WUSA until the current build/prerequisite is checked and, if necessary, the servicing baseline is updated. Microsoft’s current KB page marks the Update Catalog channel as unavailable for this package, so a Catalog search may not return it. See [Microsoft KB5054156](https://support.microsoft.com/en-us/servicing/os/windows/docs/2025/02/kb5054156-feature-update-to-windows-11-version-25h2-by-using-an-enablement-package). |
| | | **Action** | After installation and the required restart, record the Windows edition, Version, OS build, installed update/package state, and WUSA outcome. Capture the relevant setup/update logs and verify whether the system reports Windows 11 Home 25H2 (build 26200.x). |
| | | **Result** | Pending. |
| | | **Remark** | This is a diagnostic enablement test on the existing Home 24H2 installation. A successful transition would demonstrate that this installed OS can be moved to 25H2 by the eKB; it would not, by itself, prove that the generated ISO was correctly assembled. A failure must be interpreted against the prerequisite and WUSA result/logs. |
| | | | |
| 15/11/26 | — | **Audit** | Reviewed the Home UUP converter configuration and relevant converter script paths. |
| | | **Result** | `ConvertConfig.ini` had `AddUpdates=1`, `Cleanup=0`, `wim2esd=0`, and `SkipISO=0`. The `aria2_download.log` records successful verification and completion of `UUPs/Windows11.0-KB5054156-x64.cab`. The CAB contains the 26200 enablement-package and payload-package manifests. |
| | | **Remark** | `AddUpdates=1` selects the converter’s offline update-integration route. The separate `:uups_external` routine, which stages updates through an external `$OEM$\\$1\\UUP` folder and `Updates.bat`, is called only for `AddUpdates=2`; it was **not** the configured route for this Home conversion. The verified CAB download proves presence and checksum verification, not successful integration into `install.wim`. |
| | | **Audit** | Identified the converter’s generic enablement-package classification logic, the `:EKB1` / `:EKB2` calls in the offline update-processing path, and the DISM `/Add-Package` servicing call. |
| | | **Result** | The script contains a route capable of adding an enablement package during offline servicing, but the audit has not yet established that this specific package was selected for the Home image and that DISM completed successfully. |
| | | **Remark** | The actual WIM package state and conversion/DISM logs remain necessary to prove integration. Do not infer success from the config value or CAB presence. |
| | | **Decision** | Keep the generated Pro 25H2 ISO as a separate control for a later deployment-protocol comparison. |
| | | **Result** | Pro ISO already generated: `26200.9974.261109-0904.25H2_GE_RELEASE_SVC_PROD1_CLIENTPRO_OEMRET_X64FRE_EN-US.ISO`. |
| | | **Remark** | This is not a proposed future ISO-generation task. If used for a fresh `windows-pro-box` comparison, verify the media’s actual image metadata and use a genuinely fresh VM disk/container so an old virtual disk or previously installed OS cannot contaminate the result. |
| | | | |
| 15/11/26 | — | **Decision** | Investigate why the Windows 11 25H2 UUP source (26200.10066) produced an ISO and installed OS reporting Windows 11 Home 24H2 (26100.1). This is the current debugging focus. |
| | | **Action** | Audit the generated ISO, its `install.wim`, the UUP package contents and the conversion/download logs. Establish which stage introduced the version/build discrepancy before changing the media-generation process. |
| | | **Result** | Investigation pending; no cause has been established. |
| | | **Remark** | The 24H2 installation is the observed failure to explain, not a separate preliminary ISO test. Do not generate or install another ISO until the existing evidence has been inspected and the discrepancy understood. |
| | | | |
| 14/11/26 | 18:00 UTC | **Decision** | Generate the intended Windows 11 Home media from the latest available Windows 11 25H2 UUP package set, version **26200.10066**, AMD64. Home/Core and en-US were the intended edition and language. |
| | | **Action** | Download the UUP package set in the Windows VM. Configure conversion with `AddUpdates=1`, `wim2esd=0` (retain WIM; do not convert to ESD), and `SkipISO=0`. The conversion configuration also had `Cleanup=0`. |
| | | **Result** | Home/Core conversion completed and produced an ISO named `26100.1.240331-1435.GE_RELEASE_CLIENTCORE_OEMRET_X64FRE_EN-US.ISO`. The source package folder was `26200.10066_amd64_en-us_core_82cd61b5_convert`. The selected package inventory included KB5127936, KB5130881 and KB5054156. |
| | | **Remark** | **Critical mismatch:** the selected UUP source was 25H2 build 26200.10066, but the generated ISO name reports base build 26100.1. `AddUpdates=1` and the presence of update payloads do not prove that the updates, including any enablement package, were correctly integrated into the install image. The ISO filename is evidence of the mismatch, not proof of its cause. |
| | | **Action** | Install the generated Home ISO in the Home VM to establish what it actually deploys. |
| | | **Result** | Installation produced **Windows 11 Home 24H2, build 26100.1**—not the intended Windows 11 25H2 build 26200.10066. |
| | | **Remark** | This confirms the discrepancy at the installed-OS level; it is not merely a misleading filename. The cause remains undetermined. The earlier suggestion that a shared servicing baseline or enablement package might explain the build number was a hypothesis only and does not explain away the observed 24H2 installation. |
| | | | |
| 14/11/26 | — | **Decision** | Do not interrupt the active UUP download/conversion run solely because the log reports errors. |
| | | **Action** | Allow the run to continue and preserve `aria2_download.log`; the log was also copied to the Windows host as `R:\aria2_download.log` for inspection. |
| | | **Result** | CUID download-aborted/error entries were observed during the run for the selected 25H2 package set. |
| | | **Remark** | The log entries alone do not establish whether required payloads were ultimately missing or whether the resulting ISO is valid. Completion and image contents still require verification. |
| | | | |
| 13/11/26 | — | **Decision** | Use a Windows environment for UUP conversion after the Linux conversion route failed to integrate the intended updates. |
| | | **Action** | Create and use a temporary Steam Deck Windows VM. |
| | | **Result** | VM used as the Windows environment for UUP/media work. |
| | | **Remark** | This VM is a work environment, not the final deployment target. |
| | | | |
| 13/11/26 | — | **Decision** | Try the Linux UUP conversion route for the Pro installation media. |
| | | **Action** | Generate the Pro ISO with the Linux conversion workflow. |
| | | **Result** | Image recorded as `26100.1.1_PROFESSIONAL_X64_EN-US.ISO`; intended update integration was not achieved. |
| | | **Remark** | This failure motivated moving the conversion work to a Windows environment. It is a separate earlier Pro-media attempt, not the source of the later Home ISO discrepancy. |

## Next actions

1. Preserve and inspect the complete UUP download and conversion logs, including `R:\aria2_download.log`.
2. Inspect the generated ISO's actual `install.wim` metadata and servicing/package state; verify edition, version/build and whether the 25H2 enablement/update packages were integrated.
3. Establish why the 25H2 build 26200.10066 source resulted in an ISO and installed OS reporting 24H2 build 26100.1. Do not assume a cause before the evidence supports it.
4. Only after the media discrepancy is understood, resume the separate Home activation and M4800 compatibility checks.

## Project constraints and safeguards

- **Destination:** Windows 11 Home on the Dell Precision M4800.
- **Existing installation:** Windows 11 Pro remains in place. Do not format or replace it before the Home activation route and recovery plan are verified.
- **Data protection:** Preserve the separate D: BitLocker drive and document the current setup before any reinstall. Do not assume a Windows reinstall will preserve current system settings or data.
- **Hardware/licensing gate:** A Home key licenses Home, not Pro. Activation on this M4800 is not yet verified. The M4800 is outside Microsoft's normal Windows 11 hardware support; Rufus TPM/Secure Boot bypass does not prove CPU compatibility. POPCNT/SSE4.2 still needs verification.
- **Current Pro setup:** Record the existing NVIDIA driver, **25.21.14.2678** (reported as 426.78), before any change.
- **Testing constraint:** Do not run PowerShell tests inside the Home VM web console; copy/paste is unavailable or cumbersome there. Prefer host-side inspection.
- **Priority:** Keep iTunes preservation as a short checkpoint; the main effort is resolving the installation-media discrepancy.

## Legend

- **Decision** — agreed choice or constraint.
- **Action** — what was actually done.
- **Result** — observed outcome or explicit pending status.
- **Remark** — context, limitation or evidence boundary.

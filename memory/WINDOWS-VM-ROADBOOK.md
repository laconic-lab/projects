# Roadbook - Windows VM / ISO caveats

**Current position:** The Windows VM was used to generate Windows 11 Home installation media from the selected **Windows 11 25H2, build 26200.10066, AMD64** UUP source. The generated ISO and installed OS reported **24H2, build 26100.1** instead. This is a major unresolved discrepancy. **Do not replace the existing Windows 11 Pro installation.**

| Date | Time | Entry | Decisions / Actions / Results / Remarks |
|:---:|:---:|:---:|:---|
| 15/11/26 | — | **Decision** | Do not interrupt the active UUP download/conversion run solely because the log reports errors. |
| | | **Action** | Allow the run to continue and preserve `aria2_download.log`; the log was also copied to the Windows host as `R:\\aria2_download.log` for inspection. |
| | | **Result** | CUID download-aborted/error entries were observed during the run for the selected 25H2 package set. |
| | | **Remark** | The log entries alone do not establish whether required payloads were ultimately missing or whether the resulting ISO is valid. Completion and image contents still require verification. |
| | | | |
| 14/11/26 | 18:00 UTC | **Decision** | Generate the intended Windows 11 Home media from the latest available Windows 11 25H2 UUP package set, version **26200.10066**, AMD64. Home/Core and en-US were the intended edition and language. |
| | | **Action** | Download the UUP package set in the Windows VM. Configure conversion with `AddUpdates=1`, `wim2esd=0` (retain WIM; do not convert to ESD), and `SkipISO=0`. The conversion configuration also had `Cleanup=0`. |
| | | **Result** | Home/Core conversion completed and produced an ISO named `26100.1.240331-1435.GE_RELEASE_CLIENTCORE_OEMRET_X64FRE_EN-US.ISO`. The source package folder was `26200.10066_amd64_en-us_core_82cd61b5_convert`. The selected package inventory included KB5127936, KB5130881 and KB5054156. |
| | | **Remark** | **Critical mismatch:** the selected UUP source was 25H2 build 26200.10066, but the generated ISO name reports base build 26100.1. `AddUpdates=1` and the presence of update payloads do not prove that the updates, including any enablement package, were correctly integrated into the install image. The ISO filename is evidence of the mismatch, not proof of its cause. |
| | | **Action** | Install the generated Home ISO in the Home VM to establish what it actually deploys. |
| | | **Result** | Installation produced **Windows 11 Home 24H2, build 26100.1**—not the intended Windows 11 25H2 build 26200.10066. |
| | | **Remark** | This confirms the discrepancy at the installed-OS level; it is not merely a misleading filename. The cause remains undetermined. The earlier suggestion that a shared servicing baseline or enablement package might explain the build number was a hypothesis only and does not explain away the observed 24H2 installation. |
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

1. Preserve and inspect the complete UUP download and conversion logs, including `R:\\aria2_download.log`.
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

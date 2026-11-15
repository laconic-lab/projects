# Roadbook — Windows Home / License Transfer

**Current position:** Preparing and validating Windows 11 Home installation media for the Dell Precision M4800. The intended media target is **Windows 11 25H2 with the selected update payloads**. **Do not replace the existing Windows 11 Pro installation yet.**

| Date | Time | Entry | Decisions / Actions / Results / Remarks |
|:---:|:---:|:---:|:---|
| 15/11/26 | — | **Decision** | Continue the UUP download/conversion run for the selected Windows 11 25H2 media; do not interrupt it solely because the log reports errors. |
| | | **Action** | Allow the download/conversion process to continue and retain `aria2_download.log`. |
| | | **Result** | CUID download-aborted/error entries were observed during the run for the selected 25H2 package set. |
| | | **Remark** | It remains unverified whether required payloads were missing, whether conversion completed, or whether the resulting ISO is valid. |
| | | | |
| 14/11/26 | 18:00 UTC | **Decision** | For the intended updated Home installation media, select the latest available Windows 11 25H2 UUP package set. |
| | | **Action** | Download the base ESD and update payloads; configure `AddUpdates=1`. |
| | | **Result** | 25H2 package set selected; KB5127936, KB5130881 and KB5054156 identified. |
| | | **Remark** | This is the intended 25H2 media-generation effort. Package selection and download do not prove successful integration into the install image. |
| | | | |
| — | — | **Decision** | Run a preliminary test of the earlier generated Windows 11 Home ISO. This was not the target media for the later 25H2 effort. |
| | | **Action** | Install that earlier Home ISO in the Home VM. |
| | | **Result** | The earlier ISO installed Windows 11 Home 24H2, build 26100.1. [Download log for this earlier ISO](https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/tmp/aria2_download.log). |
| | | **Remark** | This records the outcome of an earlier ISO test only. It was not a decision to target 24H2, and it says nothing about the contents or validity of the later 25H2 ISO. |
| | | | |
| — | — | **Decision** | Use a Windows environment for UUP conversion. |
| | | **Action** | Create and use a temporary Steam Deck Windows VM. |
| | | **Result** | VM used for UUP/media work. |
| | | **Remark** | This is a work environment, not the final deployment target. |
| | | | |
| 13/11/26 | — | **Decision** | Try the Linux UUP conversion route for the Pro installation media. |
| | | **Action** | Generate the Pro ISO. |
| | | **Result** | Image recorded as `26100.1.1_PROFESSIONAL_X64_EN-US.ISO`. |
| | | **Remark** | `AddUpdates=1` did not produce the intended update integration. This failure motivated using a Windows environment for later conversion. |

## Next actions

1. Establish whether the latest 25H2 UUP download/conversion run completed successfully.
2. Review the logs and inspect the resulting ISO's actual install-image edition, version/build and servicing state.
3. Verify the Home-key activation path and hardware constraints before considering replacement of Windows Pro.
4. Only then decide whether to install Windows Home.

## Key safeguards

- A Home key licenses Home, not Pro. Activation on this M4800 is **not yet verified**; do not treat it as guaranteed.
- Do not format or replace the current Pro installation before activation and recovery checks are complete.
- Preserve the separate D: BitLocker drive and record the current Pro setup, including NVIDIA driver **25.21.14.2678** (reported as 426.78).
- The M4800 is outside Microsoft's normal Windows 11 hardware support. Verify CPU instruction compatibility; bypassing TPM/Secure Boot checks is not a CPU compatibility test.
- Keep iTunes preservation as a short checkpoint; the main effort is installation media.
- Do not infer ISO contents from its filename, UUP selection or download log alone.
- Do not run PowerShell tests inside the Home VM web console; copy/paste is unavailable or cumbersome there. Prefer host-side inspection.

## Project constraints

- **Destination:** Windows 11 Home on the Dell Precision M4800.
- **Existing installation:** Windows 11 Pro remains in place until the Home activation route is verified.
- **Data protection:** Preserve the separate D: BitLocker drive and document the current setup before any reinstall. Do not assume a Windows reinstall will preserve current system settings or data.
- **Hardware/licensing gate:** Verify the Home-key activation path and M4800 compatibility before destructive action. Rufus TPM/Secure Boot bypass does not prove CPU compatibility; POPCNT/SSE4.2 still needs verification.

## Legend

- **Decision** — agreed choice or constraint.
- **Action** — what was actually done.
- **Result** — observed outcome or explicit pending status.
- **Remark** — context, limitation or evidence boundary.

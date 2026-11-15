# Roadbook — Windows Home / License Transfer

**Current position:** Preparing and validating Windows 11 Home installation media for the Dell Precision M4800. **Do not replace the existing Windows 11 Pro installation yet.**

| Date | Time | Entry | Decisions / Actions / Results / Remarks |
|:---:|:---:|:---:|:---|
| — | — | **Decision** | Try the Linux UUP conversion route for the Pro installation media. |
| | | **Action** | Generate the Pro ISO. |
| | | **Result** | Image recorded as `26100.1.1_PROFESSIONAL_X64_EN-US.ISO`. |
| | | **Remark** | `AddUpdates=1` did not produce the intended update integration. This failure motivated using a Windows environment for later conversion. |
| | | | |
| — | — | **Decision** | Use a Windows environment for UUP conversion. |
| | | **Action** | Create and use a temporary Steam Deck Windows VM. |
| | | **Result** | VM used for UUP/media work. |
| | | **Remark** | This is a work environment, not the final deployment target. |
| | | | |
| — | — | **Decision** | Test the generated Home media. |
| | | **Action** | Install the Home ISO in the Home VM. |
| | | **Result** | Windows 11 Home 24H2, build 26100.1. |
| | | **Remark** | Unexpected result. It does not establish what a later ISO contains. |
| | | | |
| 13/11/2026 | 18:00:11 UTC | **Decision** | Select the latest available Windows 11 25H2 UUP package set. |
| | | **Action** | Download the base ESD and update payloads; configure `AddUpdates=1`. |
| | | **Result** | Package set selected; KB5127936, KB5130881 and KB5054156 identified. |
| | | **Remark** | Package selection and download do not prove successful integration into the install image. |
| | | | |
| 15/11/2026 | — | **Decision** | Do not interrupt the active run solely because the log reports errors. |
| | | **Action** | Allow the UUP download/conversion process to continue; retain `aria2_download.log`. |
| | | **Result** | CUID download-aborted/error entries observed. |
| | | **Remark** | It remains unverified whether required payloads were missing or whether the final ISO is valid. |
| | | | |
| — | — | **Decision** | Make Windows 11 Home on the Dell Precision M4800 the intended destination. |
| | | **Action** | — |
| | | **Result** | Project target established. |
| | | **Remark** | The existing Pro installation stays in place until the Home activation route is verified. |
| | | | |
| — | — | **Decision** | Protect existing data and recoverability before any reinstall. |
| | | **Action** | Preserve the separate D: BitLocker drive; document the current setup. |
| | | **Result** | Safeguard agreed. |
| | | **Remark** | Do not assume a Windows reinstall will preserve current system settings or data. |
| | | | |
| — | — | **Decision** | Avoid impractical guest-side testing. |
| | | **Action** | Do not run PowerShell tests inside the Home VM web console. |
| | | **Result** | Constraint established. |
| | | **Remark** | Copy/paste is unavailable or cumbersome there; prefer host-side inspection. |
| | | | |
| — | — | **Decision** | Verify hardware and licensing before destructive action. |
| | | **Action** | Check the Home-key activation path and Windows 11 compatibility on the M4800. |
| | | **Result** | Pending. |
| | | **Remark** | Rufus TPM/Secure Boot bypass does not prove CPU compatibility; POPCNT/SSE4.2 still needs verification. |

## Next actions

1. Establish whether the latest UUP download/conversion run completed successfully.
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

## Reference

- [Earlier Home ISO download log](https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/tmp/aria2_download.log)

## Legend

- **Decision** — agreed choice or constraint.
- **Action** — what was actually done (or `—` if none is recorded).
- **Result** — observed outcome or explicit pending status.
- **Remark** — context, limitation or evidence boundary.

# Roadbook — Windows Home / License Transfer

**Current position:** Preparing and validating Windows 11 Home installation media for the Dell Precision M4800. **The existing Windows 11 Pro installation must not be replaced yet.**

| Date | Time | Decision | Action | Result | Remark |
|------|------|----------|--------|--------|--------|
| — | — | Try Linux UUP conversion for Pro media | Generate Pro ISO | Image recorded as 26100.1.1_PROFESSIONAL_X64_EN-US.ISO | AddUpdates=1 did not produce the intended update integration. |
| — | — | Use a Windows environment for UUP conversion | Create and use a temporary Steam Deck Windows VM | VM used for UUP/media work | It is a work environment, not the final deployment target. |
| — | — | Test the generated Home media | Install Home ISO in the Home VM | Windows 11 Home 24H2, build 26100.1 | Unexpected result; does not establish what a later ISO contains. |
| 13/11/2026 | 18:00:11 UTC | Select the latest available 25H2 UUP package set | Download base ESD and update payloads; set AddUpdates=1 | Package set selected; KB5127936, KB5130881 and KB5054156 identified | Selection/download do not prove successful integration into the install image. |
| 15/11/2026 | — | Do not interrupt the active run solely because the log reports errors | Keep the UUP download/conversion process running; retain aria2_download.log | CUID download-aborted/error entries observed | Whether required payloads were missing, and whether the final ISO is valid, remains unverified. |
| — | — | Make Windows 11 Home on the Dell M4800 the intended destination | — | Project target established | Existing Pro installation stays in place until the Home activation route is verified. |
| — | — | Protect existing data and recoverability | Preserve the separate D: BitLocker drive; document the current setup before any reinstall | Safeguard agreed | Do not assume a Windows reinstall will preserve current system settings or data. |
| — | — | Avoid impractical guest-side testing | Do not run PowerShell tests inside the Home VM web console | Constraint established | Copy/paste is unavailable or cumbersome there; prefer host-side inspection. |
| — | — | Check hardware and licensing before destructive action | Verify Home-key activation path and M4800 Windows 11 compatibility | Pending | Rufus TPM/Secure Boot bypass does not prove CPU compatibility; POPCNT/SSE4.2 still needs verification. |

## Next actions

1. Establish whether the latest UUP download/conversion run completed successfully.
2. Review the download and conversion logs; inspect the resulting ISO's actual install-image edition, version/build and servicing state.
3. Verify the Home-key activation path and hardware constraints before considering replacement of Windows Pro.
4. Only then decide whether to install Windows Home.

## Key safeguards

- A Home key licenses Home, not Pro. Activation on this M4800 is **not yet verified**; do not treat it as guaranteed.
- Do not format or replace the current Pro installation before the activation and recovery checks are complete.
- Preserve the separate D: BitLocker drive and record the current Pro setup, including NVIDIA driver **25.21.14.2678** (reported as 426.78).
- The M4800 is outside Microsoft's normal Windows 11 hardware support. Verify CPU instruction compatibility; bypassing TPM/Secure Boot checks is not a CPU compatibility test.
- Keep iTunes preservation as a short checkpoint; the main effort is installation media.
- Do not infer ISO contents from its filename, UUP selection or download log alone.

## Reference

- [Earlier Home ISO download log](https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/tmp/aria2_download.log)

## Legend

- **Decision** — agreed choice or constraint.
- **Action** — what was actually done (or — if none is recorded).
- **Result** — observed outcome or explicit pending status.
- **Remark** — context, limitation or evidence boundary.

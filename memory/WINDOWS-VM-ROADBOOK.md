# Windows Home / License Transfer — Roadbook

**Repository:** laconic-lab/projects  
**Purpose:** Keep the important project decisions, verified results and next step available across chats. This is a short handover, not a technical audit.

## Goal and current direction

The intended destination is **Windows 11 Home on the Dell Precision M4800**, using the user's existing Windows Home key. The temporary Steam Deck Windows VM was useful for UUP/media work, but it is not the intended final solution and is no longer required as a deployment target.

The immediate priority is to establish trustworthy Windows 11 Home installation media and verify the Home-key activation path **before changing the existing Windows 11 Pro installation**.

## Settled decisions and constraints

- A Windows Home key licenses **Home, not Pro**.
- Direct activation of Windows 11 Home using the existing Windows 10/11 Home retail key is expected, but has not yet been conclusively verified on this machine. Do not describe activation as guaranteed.
- **Do not format or replace the current Pro installation** until Home-key activation is strongly verified.
- Windows settings and data on the current Windows installation may be lost; the separate physical **D: BitLocker drive must be protected**.
- Preserve the current Pro-specific setup where possible, especially NVIDIA driver **25.21.14.2678** (reported as 426.78), and record what would need reinstalling after a clean installation.
- The M4800 is unsupported for Windows 11 by Microsoft's normal hardware requirements. Rufus still offers TPM/Secure Boot bypass; this does not itself establish CPU compatibility. POPCNT/SSE4.2 compatibility remains to be verified.
- Windows Home does not provide built-in incoming Remote Desktop hosting. Other Pro-only features relevant to the decision include Hyper-V, full BitLocker management, Group Policy, domain/Entra join and Windows Sandbox.
- Do not run PowerShell tests inside the Home VM through its web console; the lack of convenient copy/paste makes that workflow impractical.
- Keep the iTunes preservation task as a short checkpoint; the main effort is the installation media.

## Media and VM history

1. The first Pro ISO was produced through the Linux UUP conversion route. Despite \u0060AddUpdates=1\u0060, the resulting image was recorded as \u006026100.1.1_PROFESSIONAL_X64_EN-US.ISO\u0060 without the intended integrated updates. This is why a Windows environment was used for the later UUP conversion workflow.
2. A temporary Steam Deck Windows VM was created and used in the media investigation. It is not the final Windows installation target.
3. A Home ISO named \u006026100.1.240331-1435.GE_win11home_RELEASE_CLIENTCORE_OEMRET_X64FRE_EN-US.ISO\u0060 was installed in a Home VM. The observed guest reported Windows 11 Home **24H2, build 26100.1**. This result was unexpected and did not establish whether the ISO contained the later updates.
4. The user subsequently selected the latest available UUP package set (catalogue timestamp recorded as **2026-11-13 18:00:11 UTC**) for the media work. The package selection included the base ESD and update payloads; references identified in the work include **KB5127936, KB5130881 and KB5054156**. \u0060AddUpdates=1\u0060 was configured.
5. During a later download/build run, \u0060aria2_download.log\u0060 contained CUID download-aborted/error entries. The script was still running when this was discussed, and the user did not want it interrupted prematurely. The presence of log errors alone does not establish whether required payloads were missing or whether the final ISO is incomplete.

**Keep these stages distinct:** UUP selection, payload download, update integration into the install image, ISO creation, and the image actually installed. Evidence for one stage does not prove the next.

## Current status

- The earlier Home VM result is confirmed: Home 24H2 / build 26100.1.
- A later UUP media run was based on the newer package set described above. Its download log needs to be interpreted; do not assume every logged abort is fatal or harmless.
- The Home-key activation route on the M4800 has not yet been verified strongly enough to authorize replacing the current Pro installation.
- No decision to format the M4800 has been made.

## Next steps

1. Establish the completion state of the latest UUP download/conversion run without interrupting an active process.
2. Review the download and conversion logs, then inspect the resulting ISO's actual install-image edition, version/build and servicing state. Do not infer these from its filename or from the UUP catalogue selection.
3. Verify the Home-key activation route before any destructive installation decision.
4. Audit the M4800's hardware/Windows installation constraints and protect the separate D: BitLocker drive.
5. Only after those checks, decide whether and how to replace the existing Pro installation.

## Important reference

- Earlier Home ISO download log: [aria2_download.log](https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/tmp/aria2_download.log)

## Update

- **2026-11-15:** Reworked this roadbook to reflect the project's current destination (Windows 11 Home on the Dell M4800), retain the relevant UUP/VM history, and distinguish confirmed results from unresolved media and activation questions. The general \u0060memory/1-README.md\u0060 was intentionally left unchanged.

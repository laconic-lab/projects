# Windows VM Project — Roadbook

**Repository:** laconic-lab/projects  
**Project:** Steam Deck Windows VMs using Dockur Windows / Podman  
**Purpose:** Preserve actual decisions and troubleshooting history across ChatGPT conversations.

> Chronological handover, not a replacement for canonical Windows VM documentation. Distinguish recorded facts from hypotheses. Do not infer that a planned step was completed.

## Current focus

Investigate why the newly generated **Windows 11 Home ISO**, intended to contain the November 2026 25H2 updates, installed Windows 11 Home **24H2, build 26100.1**. This is an unresolved discrepancy, not an expected result.

The user proposed a controlled test: create another Pro VM using the corresponding updated Pro ISO and compare the installed version/build.

## History and decisions

### 1. Original Windows Pro VM and the UUP conversion problem

- The first Pro ISO was generated using the Linux conversion route.
- The UUP package had update integration configured with AddUpdates=1, but the Linux conversion route did not integrate the updates as intended.
- The resulting ISO was recorded as 26100.1.1_PROFESSIONAL_X64_EN-US.ISO.
- This failure was the reason for creating a Windows VM: UUP's Windows conversion script was required to perform update integration.
- Do not repeat the incorrect assumption that the Home ISO was an unrelated old stock ISO. It was generated through the later Windows-VM workflow.

### 2. UUP package selection

- The Pro UUP selection was recorded as 26200.9974_pro (Windows 11 25H2).
- The downloaded package included the base ESD and update payloads. Previously identified package references include:
  - KB5127936
  - KB5130881
  - KB5054156
- ConvertConfig.ini was recorded with AddUpdates=1.
- The Home and Pro packages were both selected from the latest package set shown for Windows 11 25H2, with the user recording the catalogue timestamp as **2026-11-13 18:00:11 UTC**.
- The user states that the Home ISO was also generated inside the Windows VM using this updated UUP workflow, with updates intended to be included.
- The raw download log is available in the repository:
  [tmp/aria2_download.log](https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/tmp/aria2_download.log)
- The user reports that the log contains recent KB downloads. The log must be examined as evidence of downloaded payloads, not automatically treated as proof that those updates were integrated into the final install image.

**Important distinction:** package selection, successful payload download, successful update integration into the WIM/ESD, and the image actually installed by Windows Setup are separate stages. Verify each stage independently.

### 3. Home ISO and unexpected installation result

- A Home ISO was generated through the Windows VM workflow, with the intention of integrating the selected 25H2 updates.
- The ISO used for the Home VM is named:
  26100.1.240331-1435.GE_win11home_RELEASE_CLIENTCORE_OEMRET_X64FRE_EN-US.ISO
- The Home VM installation completed.
- Observed guest details:
  - Edition: Windows 11 Home
  - Version: 24H2
  - OS build: 26100.1
- This is unexpected given the intended 25H2 updated media.
- The ISO filename alone does not settle what image content is inside it. Its actual install image metadata and servicing state must be inspected.
- No PowerShell tests are required inside the Home guest. The user finds entering commands through the web console cumbersome because copy/paste is unavailable.

### 4. Home VM deployment facts

- Project root: /home/deck/Windows11HomeVM
- Container: windows-home-box
- ISO path: /home/deck/Downloads/26100.1.240331-1435.GE_win11home_RELEASE_CLIENTCORE_OEMRET_X64FRE_EN-US.ISO
- Host console endpoint: 192.168.1.161:8006
- The VM was successfully started and the web console worked.
- The container uses the KVM device. The final configuration was aligned with the original known-working VM and did not include /dev/net/tun or NET_ADMIN.
- The Home guest installation completed; the discrepancy concerns the Windows version/build installed from the ISO, not a failure to launch the container.

## Current investigation — not yet completed

1. **Inspect the Home ISO from the Steam Deck host, read-only.**
   - Determine the actual WIM/ESD image indexes, edition, version, build, and servicing/update state.
   - Do not rely solely on the ISO filename.
   - Do not modify or rebuild the ISO during this inspection.
2. **Inspect Windows UUP conversion evidence.**
   - Review conversion logs and determine whether update integration was actually applied to the Home install image.
   - Separate download success from integration success.
   - Check whether the selected Home UUP files and conversion output correspond to the intended 25H2 package set.
3. **Run the proposed Pro control installation.**
   - Create a separate Pro VM using the updated Pro ISO.
   - Record the exact ISO filename and inspect its image metadata before installation.
   - After installation, record the guest edition, version, and build.
   - Compare Pro and Home outcomes to determine whether the issue is specific to the Home package/image or common to the conversion workflow.
4. Only after evidence is collected, decide whether the Home ISO must be regenerated or whether Windows Setup selected an unexpected image/index.

## Working rules for the next chat

- Do not repeat the historical Linux conversion experiment; its failure is already established.
- Do not claim that the Home ISO was an old stock ISO. It was generated through the updated Windows-VM conversion workflow according to the user.
- Do not assume that downloaded KB payloads prove successful integration.
- Do not assume the ISO filename proves the installed image build.
- Do not perform PowerShell tests inside the Home guest unless the user explicitly changes this constraint.
- Prefer host-side, read-only inspection first.
- The Pro VM test is a proposed diagnostic control, not yet a completed action.
- Do not modify VM configurations, regenerate media, delete VMs, or change project documentation outside this roadbook without discussing the specific change first.

## Open questions

- What are the actual version/build and servicing packages in the Home ISO's install image?
- Did the Windows UUP conversion process apply the selected Home updates, or did it leave the original 26100.1 image intact?
- Is the Pro ISO's install image actually 25H2 with the intended update level?
- Does installing from the updated Pro ISO produce 25H2 as expected?

## Update log

- **2026-11-15:** Created this roadbook to preserve the UUP/ISO/VM history and prevent loss of the key causal context across ChatGPT conversations. Current Home ISO discrepancy and next diagnostic steps recorded from the user's account and conversation history.

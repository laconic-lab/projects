# 08 — Kernel update procedure

Status: procedure draft for review. This document does not authorize a kernel or NVIDIA package transaction.

## Purpose and scope

Use this procedure when considering a newer Linux Mint kernel on the Dell Precision M4800 with NVIDIA Quadro K2100M. The established working baseline is Linux Mint 22, kernel `6.8.0-147-generic`, and the loaded NVIDIA runfile driver `470.256.02`.

The objective is to move to a newer kernel only when the existing NVIDIA 470 installation can be preserved and independently verified. SecureUpdate remains a notification/update-control tool; NVIDIA compatibility and recovery belong here.

Do not assume that a newer kernel is compatible merely because APT offers it, because the old kernel's module is installed, or because DKMS reports a successful build.

## Phase 0 — Preconditions and stop conditions

Before starting:

- Confirm the machine is currently booted into the known-good kernel.
- Confirm the loaded NVIDIA version is `470.256.02`.
- Confirm the external display works in the current session.
- Confirm the previous known-good kernel remains installed and selectable in GRUB.
- Confirm the recovery backup destination has sufficient free space.
- Do not proceed if the current baseline is already degraded, the backup cannot be verified, package state differs materially from the documented baseline, or APT proposes unexpected removals.

No NVIDIA purge, runfile uninstall, DKMS removal, package hold change, library-link recreation, or initramfs/GRUB modification is part of this procedure unless separately investigated and explicitly approved.

## Phase 1 — Capture the known-good baseline

Run the read-only diagnostic and create a fresh targeted backup using the current project scripts:

```bash
bash scripts/nvidia-diagnostic.sh
bash scripts/nvidia-backup.sh
```

Review both outputs. Record at minimum:

- `uname -r` and `/proc/cmdline`
- Loaded driver from `/proc/driver/nvidia/version`
- `nvidia-smi` result
- `modinfo -F version nvidia` and `modinfo -n nvidia`
- Complete `dkms status`
- Installed kernel image, modules, headers and metapackage versions
- APT holds and installed NVIDIA-related package versions
- NVIDIA library-link targets and dpkg ownership
- Current external-display operation

Verify the backup archive's gzip/tar integrity and required contents. Copy the verified archive and reports to independent storage before changing packages. The targeted archive is not a full system image and does not contain all kernel package payloads.

## Phase 2 — Identify the exact target kernel transaction

Refresh package metadata only when ready to evaluate a real update. Record the proposed target kernel release and inspect the exact package versions for:

- Kernel image
- Kernel modules and modules-extra, where applicable
- Kernel headers and generic headers metapackage
- Kernel image/generic metapackage
- Kernel tools, if proposed

Capture the complete APT simulation output, including summary, `Inst`, `Conf`, and `Remv` lines. Do not filter away removals or transaction summary. Review phased updates, held packages, packages kept back, and any dependency changes.

A simulation is a proposal, not a guarantee of the final transaction. Re-run it immediately before execution if metadata or installed state changes.

## Phase 3 — Evaluate NVIDIA 470 compatibility for the target kernel

The active driver is the runfile-managed `470.256.02` release. Its DKMS identity is `nvidia/470.256.02`. APT packages have previously been observed to share that DKMS identity and to invoke the NVIDIA uninstaller in maintainer scripts. Do not install or remove NVIDIA packages as a side effect of a kernel update without separately reviewing their maintainer scripts and transaction.

For the exact target kernel:

1. Confirm the matching target-kernel headers are available and their exact version matches the target release.
2. Inspect the existing runfile DKMS source and configuration without modifying it.
3. Establish whether this exact driver source is known to build against this exact kernel/API. Do not infer compatibility from a different kernel release.
4. If a build test is proposed, define its scope, expected artifacts, log location, cleanup boundary, and rollback before running it.
5. After any approved build, inspect the build log and DKMS status for the target kernel.
6. Verify the module file exists under the target kernel's module tree, and inspect its version, vermagic, signer and path with target-kernel-specific `modinfo` queries.

A successful build only establishes that a module was produced. It does not establish that the module will load, that Secure Boot will accept it, that userspace libraries are coherent, or that the desktop/display will work.

If compatibility cannot be established, stop and retain the current working kernel. Do not attempt an improvised patch or driver replacement during the kernel update.

## Phase 4 — Approve and install the kernel only

Before execution, review the exact final APT transaction and confirm:

- No unexpected package removals or NVIDIA driver transitions.
- No removal of the current known-good kernel.
- No unintended change to NVIDIA holds or the runfile installation.
- Required target kernel packages and headers are included.
- A verified backup and a bootable fallback kernel are available.

Only the exact reviewed transaction may be approved. Do not use a broad `full-upgrade` merely because it proposes the target kernel. Do not combine unrelated NVIDIA package cleanup with the kernel installation.

## Phase 5 — First boot and verification

After the kernel package transaction completes, do not immediately remove the previous kernel.

Boot the new kernel only when the target-kernel module build and package transaction have been reviewed. At the first boot, verify:

1. `uname -r` reports the intended target kernel.
2. `cat /proc/driver/nvidia/version` reports the expected loaded driver.
3. `nvidia-smi` works and identifies the Quadro K2100M.
4. `modinfo -F version nvidia` and `modinfo -n nvidia` resolve to the intended module for the running kernel.
5. `dkms status` reports the intended 470 module as installed for the running kernel.
6. Relevant kernel logs contain no NVIDIA module load, signature, API mismatch, or GPU initialization failure.
7. Cinnamon starts normally and the external display works at the expected resolution and refresh rate.

Treat module load, desktop operation and external-display operation as separate checks. Do not mark the kernel transition successful until all required checks pass.

## Phase 6 — Failure and fallback

If the new kernel fails to boot or NVIDIA/display verification fails:

- Use GRUB to boot the previous known-good kernel.
- Do not uninstall the NVIDIA driver or remove the old kernel as an immediate reaction.
- Capture the failed kernel's boot and DKMS logs while preserving the current state.
- Compare the new-kernel evidence with the known-good baseline.
- Create a specific recovery plan based on the observed failure before making changes.

Keep the previous kernel installed until the new kernel has passed verification and has remained stable through a normal reboot. Kernel removal is a separate, explicitly reviewed maintenance action.

## Completion record

For each transition, record:

- Date and machine identity
- Previous and target kernel versions
- Exact APT transaction and its simulation
- NVIDIA driver/source version and target-kernel DKMS build result
- Backup archive path, integrity result and required-content verification
- First-boot module, GPU, desktop and external-display results
- Whether fallback was needed
- Final decision: passed, failed, or deferred

## Explicit non-goals

This procedure does not authorize:

- Replacing the 470.256.02 runfile driver with an APT driver.
- Removing 535/580 packages or DKMS registrations.
- Changing package holds.
- Running `nvidia-uninstall`.
- Rebuilding generic library symlinks from memory.
- Automating kernel installation or recovery.
- Treating the S3 resume issue as part of kernel compatibility without separate evidence.

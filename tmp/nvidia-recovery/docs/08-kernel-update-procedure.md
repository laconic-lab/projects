# 08 — Kernel transition and NVIDIA 470 recovery protocol

Status: operational protocol. It guides a user-controlled kernel update and the subsequent NVIDIA 470 recovery. It does not authorize package or driver corrections by itself.

## Purpose and responsibility

This document covers the practical transition to a newer Linux Mint kernel on the Dell Precision M4800 / NVIDIA Quadro K2100M, including recovery of the existing NVIDIA 470.256.02 runfile installation when its DKMS module does not build or load for the new kernel.

The established working baseline in the investigation is Linux Mint 22, kernel `6.8.0-147-generic`, and NVIDIA 470.256.02. Reconfirm the live state before each transition; historical snapshots are not a substitute for current diagnostics.

The intended outcome is to keep using newer kernels while preserving a known-good fallback and recovering NVIDIA 470 for the target kernel. **A successful NVIDIA 470 build for the target kernel is not a prerequisite for installing the kernel.** A failed build or first boot is a recoverable condition, provided the previous working kernel remains installed and selectable.

Responsibilities remain separate:

- **SecureUpdate:** installs ordinary updates and clearly reports deferred/held updates, including kernel updates. It does not decide NVIDIA compatibility or perform kernel recovery.
- **User / Update Manager:** the user decides when to install the held/deferred kernel update, after backup and review of the proposed transaction.
- **NVIDIA-Recovery:** captures evidence, diagnoses DKMS/build/load problems, and guides the manual recovery of NVIDIA 470.
- **Document 06:** governs any corrective package or driver transaction. Its approval and safety requirements apply to corrections; they must not be misread as a rule to avoid installing newer kernels indefinitely.

## Protocol at a glance

```text
Known-good kernel + NVIDIA 470
          |
          v
Fresh diagnostic + verified targeted backup
          |
          v
Review exact kernel update transaction
          |
          v
User installs kernel through Update Manager
          |
          v
Keep previous kernel installed and bootable
          |
          v
Inspect target kernel, headers, DKMS result and logs
          |
          +---- 470 target module ready? ----+
          |                                  |
         YES                                 NO
          |                                  |
          v                                  v
Boot target kernel                    Keep / return to old kernel
          |                            Diagnose exact build failure
          |                            Recover 470 DKMS for target
          |                                  |
          +----------------+-----------------+
                           |
                           v
             Verify module, GPU, desktop,
                 external display
                           |
                           v
              Record result; retain fallback
```

## Phase 1 — Preserve the working baseline

Before installing a newer kernel:

1. Boot the currently working kernel.
2. Confirm the loaded NVIDIA driver, GPU operation, Cinnamon session and external display.
3. Run the project's diagnostic script and create a fresh targeted backup:
   ```bash
   bash scripts/nvidia-diagnostic.sh
   bash scripts/nvidia-backup.sh
   ```
4. Review the reports and verify the archive's integrity and required contents.
5. Copy the verified archive and reports to independent storage.
6. Confirm that the current known-good kernel remains installed and can be selected from GRUB.

The backup is targeted evidence preservation, not a full system image or automatic restore mechanism. See document 03 for its contents and limitations.

Do not start from an already degraded baseline without first recording and understanding that state.

## Phase 2 — Review and install the kernel update

1. Identify the exact target kernel release and the packages Update Manager proposes to install.
2. Review the complete transaction, including kernel image, modules, headers, metapackages, tools, removals and dependency changes.
3. Check specifically whether the transaction proposes NVIDIA package changes. The existing 470 holds and the observed 535/580 package state are important; do not unhold packages or approve an unrelated NVIDIA transition as part of the kernel update.
4. If the transaction contains unexpected removals, changes to the working kernel, or an unexplained NVIDIA package transition, pause and investigate that transaction before approving it.
5. Once the kernel transaction is understood and the backup/fallback are in place, the user may install the kernel manually through Update Manager.

**Do not require a successful target-kernel NVIDIA 470 build before installing the kernel.** The purpose of the retained old kernel is to provide a working environment from which the new kernel's driver can be diagnosed and recovered.

Do not combine kernel installation with NVIDIA cleanup, driver replacement, hold changes or library-link correction. Those are separate changes governed by document 06.

## Phase 3 — Inspect the installed target kernel before changing NVIDIA

After the kernel packages have been installed:

1. Keep the previous known-good kernel installed.
2. If still booted into the old kernel, remain there while inspecting the target kernel. This is the preferred recovery environment because the working desktop and NVIDIA 470 installation remain available.
3. Confirm the target kernel image, modules and matching headers are installed and that their release versions agree.
4. Inspect the complete DKMS status, specifically the `nvidia/470.256.02` entry for the target kernel.
5. Inspect the target-kernel DKMS build log and any package-triggered DKMS output. Record the exact first relevant error; do not infer the cause from a generic failure status.
6. Check whether the target kernel's module tree contains the expected NVIDIA module. Verify its version, vermagic, file path and signer using target-kernel-specific inspection.

Interpret the results carefully:

- `installed` means DKMS reports that module as installed for the named kernel.
- `built` means DKMS reports a build but not an installation for that kernel.
- Neither status proves which driver is currently loaded.
- A module built for kernel 147 is not a module for kernel 151.
- A successful build does not prove that the module will load, Secure Boot will accept it, userspace libraries are coherent, or the desktop/display will work.

If the target module is already correctly built and installed, proceed to Phase 5. If it is missing or the build failed, proceed to Phase 4.

## Phase 4 — Recover NVIDIA 470 for the target kernel

Perform recovery from the known-good kernel whenever possible.

1. Preserve the original DKMS build log and collect the target kernel's headers, DKMS configuration, runfile source and package state needed to reproduce the failure.
2. Compare the target-kernel failure with the known-good kernel's working `nvidia/470.256.02` source and build configuration.
3. Identify the actual cause before changing anything. Possible categories include missing/mismatched headers, DKMS configuration or source problems, kernel API incompatibility, compiler/build errors, signing or Secure Boot rejection, and package-maintainer-script interference. These are diagnostic categories, not assumed causes.
4. Define the smallest evidence-based recovery action. If a source patch or configuration change is needed, explain the exact change, affected files, backup and rollback before applying it.
5. Obtain explicit approval before modifying driver source/configuration, changing packages or holds, removing DKMS registrations, changing library links, or running any installer/uninstaller.
6. Build/install the existing NVIDIA 470.256.02 DKMS source for the exact target kernel only after the cause and action have been reviewed.
7. Preserve the full build log. Verify the result for the target kernel: DKMS status, module file path, module version, vermagic and signer.
8. If the build still fails, stop and retain the evidence. Do not substitute NVIDIA 535/580, run an improvised patch, or remove the working 470 installation as a guess.

The runfile and APT packages have previously been observed to share the `nvidia/470.256.02` DKMS identity. The APT dependency and maintainer-script risks documented in 04 and 06 remain relevant. Do not casually install/remove NVIDIA packages, invoke `nvidia-uninstall`, or run a global DKMS removal.

If the target kernel was already booted and the graphics driver failed, use GRUB to return to the previous known-good kernel, then perform the diagnosis and recovery from that working environment.

## Phase 5 — Boot and verify the target kernel

Boot the target kernel only when the target module is ready for a controlled verification attempt. If an initial attempt has already failed, return to the old kernel and complete Phase 4 before retrying.

After booting the target kernel, verify each layer separately:

1. `uname -r` reports the intended target kernel.
2. `/proc/driver/nvidia/version` reports the expected loaded NVIDIA 470.256.02 driver.
3. `nvidia-smi` works and identifies the Quadro K2100M.
4. `modinfo` resolves the module for the running kernel and reports the expected version and path.
5. DKMS reports `nvidia/470.256.02` installed for the running kernel.
6. Kernel logs show no relevant NVIDIA module load, signature, API mismatch or GPU initialization failure.
7. Cinnamon starts normally.
8. The external display works at the expected resolution and refresh rate.

If any check fails, do not declare the transition successful. Capture the logs, return to the known-good kernel if needed, and continue diagnosis from Phase 4. A working `nvidia-smi` alone is not proof that the external display and desktop are fully operational.

## Phase 6 — Completion and fallback retention

A kernel transition is complete only after the target kernel has passed the module, GPU, desktop and external-display checks and has remained stable through a normal reboot.

Record for each transition:

- Date, machine and previous/target kernel releases
- Exact kernel package transaction and any removals
- Backup archive path, integrity result and independent-copy location
- NVIDIA 470 source/version and target-kernel DKMS build result
- Relevant build and boot log paths
- Loaded module, GPU, Cinnamon and external-display verification
- Any recovery changes and their explicit approval
- Whether fallback was required and the final outcome

Keep the previous known-good kernel installed and selectable until the new kernel is verified and stable. Removing an old kernel is a separate maintenance decision, not part of driver recovery.

## Safety boundaries and references

The following are not authorized by this procedure alone:

- Purging or replacing NVIDIA 470 with another driver branch
- Removing 535/580 packages or DKMS registrations
- Changing APT holds
- Running `nvidia-uninstall`
- Recreating generic NVIDIA library links from memory
- Applying unreviewed kernel-compatibility patches
- Removing the known-good kernel or changing GRUB/initramfs without a specific reviewed reason
- Automating kernel installation or NVIDIA recovery

Any corrective package/driver operation must follow document 06: fresh audit, exact transaction or file-level change, backup, explicit approval, verification and documented rollback. Documents 01–05 provide the investigation, state, backup, package and DKMS evidence on which that work depends.

S3 resume black-screen remains a separate investigation and is not automatically attributed to a kernel transition or NVIDIA package state.

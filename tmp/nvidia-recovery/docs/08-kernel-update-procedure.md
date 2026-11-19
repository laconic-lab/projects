# 08 — Generic kernel transition and NVIDIA DKMS recovery procedure

Status: operational procedure. It governs a user-controlled transition from a known-good kernel to a newer kernel while preserving the existing NVIDIA driver branch. It does not authorize package or driver corrections by itself.

## Purpose and scope

This procedure is intended to be reusable across kernel releases and machines that use an NVIDIA driver managed through DKMS. Replace the example release numbers and driver version with the values verified on the machine being maintained.

The examples in this investigation use Linux Mint 22 on a Dell Precision M4800 with a Quadro K2100M and NVIDIA 470.256.02:

- Previous known-good kernel: `6.8.0-147-generic`
- Target kernel: `6.8.0-151-generic`
- Required driver branch/version: `470.256.02`

These are examples, not fixed requirements. The procedure must always use the actual running kernel, target kernel, GPU, driver version, package state and DKMS configuration discovered during the current transition. Historical reports are evidence, not a substitute for fresh diagnostics.

**Mandatory reboot gate:** Do not boot the target kernel until the intended NVIDIA driver version has been built, installed and verified for that exact target kernel. Installing the kernel packages is a separate step and may be completed while remaining booted into the previous known-good kernel. A successful build alone does not satisfy the gate. The target kernel's installed module files must resolve to the intended driver version, and the target initramfs must be checked and updated when required before reboot.

The intended outcome is to use newer kernels without sacrificing the working driver or losing a known-good fallback.

## Responsibilities and separation of concerns

- **Update mechanism / SecureUpdate:** installs ordinary updates and clearly reports deferred or held updates, including kernel updates. It does not decide NVIDIA compatibility or perform driver recovery.
- **User / Update Manager:** decides when to install a reviewed kernel transaction.
- **NVIDIA-Recovery:** captures evidence, diagnoses DKMS/build/install/load problems, and guides the manual recovery of the existing driver branch.
- **Correction policy:** any corrective package or driver transaction must follow the project's correction policy (document 06). This procedure is not blanket approval to purge packages, change holds, or replace drivers.

Do not combine a kernel update with unrelated NVIDIA package cleanup, driver-branch replacement, APT hold changes or library-link correction.

## Protocol at a glance

```text
Known-good kernel + working NVIDIA driver
                  |
                  v
Fresh diagnostics + verified targeted backup
                  |
                  v
Review exact kernel package transaction
                  |
                  v
Install target kernel packages
(remain booted into known-good kernel)
                  |
                  v
Inspect target kernel, headers, DKMS state,
module files, signing and initramfs
                  |
                  v
Build intended driver for exact target kernel
                  |
                  v
Install intended driver modules for target kernel
Preserve existing target module files for rollback
                  |
                  v
Verify installed module versions, paths, vermagic,
signatures, dependency map and initramfs
                  |
                  v
          PRE-REBOOT GATE
      Is intended driver installed and
      verified for the target kernel?
             /           \
           NO             YES
           |               |
           v               v
       Do not reboot    Boot target kernel
       Diagnose/repair       |
           |                 v
           +----------> Verify loaded driver, GPU,
                        desktop and displays
                              |
                              v
                    Retain previous kernel until
                    target is stable and verified
```

## Phase 1 — Establish and preserve the working baseline

Before installing a newer kernel:

1. Boot the currently working kernel.
2. Record the exact running kernel release:
   ```bash
   uname -r
   ```
3. Confirm the loaded NVIDIA driver version, GPU operation, desktop session and required displays.
4. Record the installed driver branch/version, DKMS status for all kernels, package state, module paths, signing state and relevant boot configuration.
5. Run the project's diagnostic and backup procedures, if available:
   ```bash
   bash scripts/nvidia-diagnostic.sh
   bash scripts/nvidia-backup.sh
   ```
6. Review the reports and verify the backup archive's integrity and required contents.
7. Copy the verified archive and reports to independent storage.
8. Confirm that the previous known-good kernel remains installed and selectable from the bootloader.

The backup is targeted evidence preservation, not necessarily a full system image or automatic restore mechanism. Follow the backup document for its exact contents and limitations.

Do not start from an already degraded baseline without first recording and understanding that state.

## Phase 2 — Review and install the target kernel

1. Identify the exact target kernel release and all packages proposed for installation.
2. Review the complete transaction, including kernel image, modules, headers, metapackages, tools, removals and dependency changes.
3. Check specifically for NVIDIA package changes and DKMS triggers. Record held packages and any installed alternative driver branches.
4. Pause if the transaction proposes unexpected removals, changes to the working kernel, or an unexplained NVIDIA driver transition.
5. Once the transaction is understood and the backup/fallback are in place, the user may install the kernel packages through the normal package manager.
6. **Remain booted into the previous known-good kernel. Do not reboot into the target kernel at this stage.**

Kernel installation does not require the target NVIDIA module to be ready, provided the system remains on the known-good kernel. However, target-kernel readiness is an absolute prerequisite for booting that kernel.

## Phase 3 — Inspect the installed target kernel

While still running the previous known-good kernel:

1. Confirm the target kernel image, modules and matching headers are installed and that their release versions agree.
2. Inspect complete DKMS status for all modules and versions, not only the desired NVIDIA entry.
3. Inspect the target-kernel build logs and package-triggered DKMS output. Record the first relevant error; do not infer the cause from a generic failure status.
4. Inspect the intended driver's source tree and DKMS configuration. Confirm its module name, version, module names, destination paths, build directives and signing configuration.
5. Inspect the target kernel's installed module tree. Identify the exact versions of the NVIDIA modules currently installed there.
6. Inspect the built module artifacts separately from the installed module files. Verify their version, vermagic and signer.
7. Check the target initramfs for NVIDIA modules and record whether it contains stale or conflicting modules.
8. Record other DKMS modules that must be preserved (for example, VirtualBox). Do not treat them as part of NVIDIA recovery.

Interpret DKMS status carefully:

- `installed` means DKMS reports that the module/version is installed for the named kernel.
- `built` means DKMS reports a build but not an installation for that kernel.
- Neither status alone proves which module file will be selected at boot or which driver is currently loaded.
- A module built for one kernel release is not a module for another release.
- A successful build does not prove installation, module selection, Secure Boot acceptance, successful loading, coherent userspace libraries, or working displays.

If the intended driver is already correctly installed for the target kernel, verify all pre-reboot requirements in Phase 5. Otherwise proceed to Phase 4.

## Phase 4 — Build and install the intended driver for the target kernel

Perform recovery from the previous known-good kernel whenever possible.

### 4.1 Diagnose before changing state

1. Preserve the original DKMS build log and collect the target kernel's headers, DKMS configuration, driver source and package state needed to reproduce the result.
2. Compare the target-kernel failure with the known-good kernel's working driver source and build configuration.
3. Identify the actual cause before changing anything. Possible categories include missing or mismatched headers, DKMS configuration/source problems, kernel API incompatibility, compiler errors, signing/Secure Boot rejection, module-version conflicts, and package-maintainer-script interference. These are diagnostic categories, not assumed causes.
4. Define the smallest evidence-based recovery action. If a source patch or configuration change is needed, document the exact change, affected files, backup and rollback.
5. Obtain explicit approval before modifying driver source/configuration, changing packages or holds, removing DKMS registrations, replacing installed module files, changing library links, or running any installer/uninstaller.

### 4.2 Build for the exact target kernel

1. Build the existing intended driver source for the exact target kernel release.
2. Preserve the complete build output and log.
3. Confirm the build exit status and inspect all expected module artifacts.
4. Verify each artifact's driver version, target-kernel `vermagic`, and signer/signature details where applicable.
5. Do not interpret warnings as fatal without checking the actual build result; equally, do not treat exit status alone as proof that all expected modules exist.

A build-only operation should not be confused with installation. For example, in this investigation, building NVIDIA 470.256.02 for `6.8.0-151-generic` produced five signed artifacts and changed DKMS status to `built`; the installed target-kernel modules nevertheless remained NVIDIA 580.178.04. That state was **not ready for reboot**.

### 4.3 Install for the target kernel without damaging fallback state

Before installing:

1. Identify exactly which target-kernel module files the installation will replace.
2. Preserve those existing files and relevant metadata in a dated, access-restricted backup outside the target module directory. Record checksums and paths so rollback is deterministic.
3. Confirm the install method's behavior for multiple registered versions sharing the same DKMS module name. Do not assume that a normal DKMS install will replace an existing version; inspect the installed DKMS implementation and current state.
4. Review any required force/override behavior and its consequences before using it. Never add `--force` merely to make an error disappear.
5. Ensure unrelated DKMS modules and the previous known-good kernel's modules are outside the change scope.
6. Obtain explicit approval for the exact installation action.

Then install the intended driver modules for the target kernel only. Do not globally remove DKMS registrations, use a global `--all` removal, or purge packages as a shortcut.

After installation, run the appropriate dependency-map update for the target kernel and verify the installed files. If the operation fails or partially completes, stop; preserve the resulting logs and use the recorded backup to plan a controlled rollback. Do not continue to reboot.

The runfile and APT packages may share a DKMS module identity. Package dependencies and maintainer-script risks documented in the project's package and correction-policy references remain relevant. Do not casually install/remove NVIDIA packages, invoke `nvidia-uninstall`, or remove a working DKMS registration.

## Phase 5 — Mandatory pre-reboot verification

**This phase is a hard gate. Do not boot the target kernel until every applicable check passes.**

While still booted into the previous known-good kernel:

1. Confirm DKMS reports the intended driver version installed for the exact target kernel. A `built` status is insufficient.
2. Inspect every expected proprietary NVIDIA module in the target kernel's module tree. Confirm each resolves to the intended driver version, not a different installed branch.
3. Verify module file paths, versions, `vermagic`, compression format and signer/signature details.
4. Confirm the target kernel's module dependency map has been regenerated and resolves the expected module paths.
5. Inspect the target initramfs. If it contains NVIDIA modules, verify that they match the intended version. If it contains stale/conflicting modules, or if the installation requires updated initramfs content, regenerate the target initramfs using the distribution's supported procedure and inspect it again.
6. Review the package state and DKMS registrations for evidence that a package trigger or later autoinstall could immediately restore a conflicting driver version. Do not assume that manually installing one version permanently resolves a conflict while another version remains registered or package-managed.
7. Confirm the previous known-good kernel and its working driver installation remain intact and selectable.
8. Save the complete pre-reboot report.

The gate is passed only when the intended NVIDIA driver version is installed for the target kernel, all relevant module files and initramfs content are consistent, and no unresolved module-version conflict remains.

If any check fails or is ambiguous: **do not reboot into the target kernel.** Continue diagnosis from the known-good kernel or roll back the target-kernel module change.

## Phase 6 — Boot and verify the target kernel

Only after Phase 5 passes may the user select and boot the target kernel.

After booting, verify each layer separately:

1. `uname -r` reports the intended target kernel.
2. `/proc/driver/nvidia/version` reports the expected loaded NVIDIA driver version.
3. `nvidia-smi` works and identifies the expected GPU.
4. `modinfo` resolves the module for the running kernel and reports the expected version and path.
5. DKMS reports the intended driver installed for the running kernel.
6. Kernel logs show no relevant NVIDIA module load, signature, API mismatch or GPU initialization failure.
7. The desktop session starts normally.
8. Required internal/external displays work at their expected resolutions and refresh rates.

A working `nvidia-smi` alone is not proof that the desktop and all displays are operational.

If any check fails, do not declare the transition successful. Capture logs and return to the previous known-good kernel through the bootloader. Diagnose and recover from that working environment; do not repeatedly attempt target boots without new evidence.

## Phase 7 — Completion and fallback retention

A transition is complete only after the target kernel has passed the module, GPU, desktop and display checks and has remained stable through a normal reboot.

Record for each transition:

- Date and machine
- Previous and target kernel releases
- GPU and intended NVIDIA driver branch/version
- Exact kernel package transaction and any removals
- Backup archive path, integrity result and independent-copy location
- DKMS build and installation results for the target kernel
- Module paths, versions, vermagic and signer/signature verification
- Module dependency-map and initramfs verification
- Relevant build, install and boot log paths
- Loaded driver, GPU, desktop and display verification
- Recovery changes, their approval and rollback details
- Whether fallback was required and the final outcome

Keep the previous known-good kernel installed and selectable until the target kernel is verified and stable. Removing an old kernel is a separate maintenance decision, not part of driver recovery.

## Safety boundaries and references

This procedure does not, by itself, authorize:

- Purging or replacing the intended NVIDIA driver branch
- Removing other NVIDIA packages or DKMS registrations
- Changing APT holds
- Running `nvidia-uninstall`
- Recreating generic NVIDIA library links from memory
- Applying unreviewed kernel-compatibility patches
- Overwriting target-kernel module files without a verified backup and rollback plan
- Removing the known-good kernel
- Changing bootloader or initramfs configuration without a specific reviewed reason
- Automating kernel installation or NVIDIA recovery

Any corrective package/driver operation must follow the project's correction policy: fresh audit, exact transaction or file-level change, backup, explicit approval, verification and documented rollback. The investigation, state, backup, package and DKMS reference documents provide supporting evidence and must be consulted where relevant.

Power-management resume or other independent display failures remain separate investigations and must not automatically be attributed to a kernel transition or NVIDIA package state.

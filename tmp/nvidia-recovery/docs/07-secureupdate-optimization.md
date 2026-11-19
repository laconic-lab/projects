# SecureUpdate — Production Behavior and Reporting

## Production status

**Status: production script finalized and in use.**

SecureUpdate's production implementation is maintained in:

- [`scripts/SecureUpdate_by_ChatGPT.sh`](../scripts/SecureUpdate_by_ChatGPT.sh)
- [`scripts/SecureUpdate_by_ChatGPT-candidate.sh`](../scripts/SecureUpdate_by_ChatGPT-candidate.sh)

The two production files are identical (same Git blob SHA: `a0df2f2158c701c7810915696f611bbc3bda1fc6`). The separate [`SecureUpdate_by_ChatGPT.sh.original`](../scripts/SecureUpdate_by_ChatGPT.sh.original) is the previous version and is retained as historical reference; it is not the production implementation.

This document describes the current production script. It is not an implementation plan or a record of pending work.

## 1. Purpose and operating model

SecureUpdate provides a controlled, operator-driven maintenance run and makes updates that remain pending visible and understandable.

Its operating principles are:

- Check the NVIDIA 470.256.02 installation before package maintenance.
- Use the normal APT `upgrade` path; do not silently escalate to `full-upgrade`.
- Check NVIDIA again after the APT upgrade before continuing to later maintenance stages.
- Update Flatpak applications through Flatpak's normal update command.
- Preview package removals and require explicit interactive approval before running `autoremove`.
- Finish with an inventory of pending APT and Flatpak updates, including available versions and APT's reported reasons for deferral.
- Keep the operator in control. A pending update is not automatically an unsafe update, and diagnostic simulations are not installation instructions.

SecureUpdate is a maintenance and visibility tool. It is not the NVIDIA driver recovery system, a DKMS compatibility tester for future kernels, or an automatic kernel-installation mechanism. NVIDIA recovery and kernel-specific diagnosis remain in the separate NVIDIA-Recovery project.

## 2. NVIDIA and kernel safety checks

The script runs the same NVIDIA check before and after the APT upgrade.

Each check verifies:

1. The NVIDIA driver is loaded, using `/proc/driver/nvidia/version`.
2. The loaded driver version is exactly `470.256.02`.
3. The newest kernel module directory already installed under `/lib/modules` can be identified.
4. The NVIDIA module reported by `modinfo` for that newest installed kernel is version `470.256.02`.
5. DKMS reports `nvidia/470.256.02` as installed for that kernel.

If the newest installed kernel differs from the currently running kernel, the script warns that a reboot may be needed.

The checks are gates, not repair operations. If the pre-update check fails, the APT maintenance chain does not start. If the post-upgrade check fails, subsequent Flatpak and autoremove stages are not run.

**Important boundary:** the check concerns kernels already installed on the system. It does not build or test NVIDIA 470 against a kernel that is only available as an APT candidate. SecureUpdate does not install a new kernel, run `full-upgrade`, change NVIDIA package holds, switch driver branches, or perform NVIDIA recovery.

## 3. Normal maintenance mode

Run without arguments:

```bash
./SecureUpdate_by_ChatGPT.sh
```

The normal execution sequence is:

1. Create the protected report and initialize terminal/report output.
2. Run the NVIDIA pre-update check.
3. Refresh APT metadata with `sudo apt-get update`.
4. Run the normal `sudo apt-get upgrade` transaction.
5. Run the NVIDIA post-upgrade check.
6. Run `flatpak update`.
7. Preview `sudo apt-get autoremove --dry-run`.
8. If packages are proposed for removal, show the preview and ask for explicit confirmation. Only an affirmative answer runs `sudo apt-get autoremove` followed by `sudo apt-get autoclean`.
9. If no packages are proposed for removal, skip the confirmation and run `sudo apt-get autoclean`.
10. Generate the final pending-update report when the script exits.

If the operator declines a proposed autoremove, neither autoremove nor autoclean is run in that branch.

The maintenance commands are chained so that a failed required stage prevents later stages from running. The final report records the script's exit status before report generation.

## 4. Report-only mode

Run:

```bash
./SecureUpdate_by_ChatGPT.sh --report-only
```

Report-only mode:

- Creates the same timestamped report.
- Runs the NVIDIA check.
- Does not refresh APT metadata; it uses the currently cached package lists.
- Does not run APT upgrade, Flatpak update, autoremove, or autoclean.
- Still generates the pending APT/Flatpak inventory and diagnostic APT simulations.

This mode is intended for a non-transactional status and reporting pass. It does not change installed packages or drivers.

## 5. Reporting and output improvements

### 5.1 Protected, timestamped Desktop reports

Each run creates a report at:

```text
$HOME/Desktop/YYYYMMDD_HHMMSS_results_for_secureupdate.txt
```

The implementation:

- Uses local system time in the `YYYYMMDD_HHMMSS` format.
- Sets a restrictive umask and report file permissions of `0600`.
- Refuses to overwrite an existing report with the same timestamped name.
- Mirrors script output to the terminal and report.
- Removes ANSI color escape sequences from the saved report while retaining colored status output in the terminal.
- Uses an EXIT trap to generate the final pending-update inventory and record the script's pre-report exit status.

Report creation or permission errors are reported and stop execution rather than being silently ignored.

### 5.2 Complete APT candidate inventory

The final report uses `apt list --upgradable` to enumerate pending APT candidates. Where APT provides the information, each entry includes:

- Package name.
- Architecture.
- Installed version.
- Candidate version.

The terminal highlights pending entries in red. The report retains the same information without terminal color codes.

### 5.3 Separate package-hold reporting

The script queries `apt-mark showhold` and lists held packages in a separate section.

A hold is reported as package-management state; it is not silently removed or overridden. A package can carry more than one classification when the APT evidence supports it.

### 5.4 Evidence-based classifications

The script compares the candidate inventory with the normal-upgrade simulation and identifies these conditions where the available APT output supports them:

- **HELD by apt-mark** — the package appears in the APT hold list.
- **DEFERRED due to APT phasing** — APT explicitly lists it in the phased-update section.
- **KEPT BACK by normal apt-get upgrade** — APT explicitly lists it as kept back.
- **Included in normal-upgrade simulation** — the simulated normal upgrade proposes the package; the report notes that the actual transaction should be checked.
- **Proposed by full-upgrade simulation only** — the package appears in the full-upgrade simulation but not the normal-upgrade simulation.
- **Reason undetermined** — the captured output does not justify a more specific explanation.

The script does not infer that a package is dangerous or NVIDIA-related merely because it remains pending.

### 5.5 Normal and full-upgrade simulations

The final report includes:

- The complete normal `apt-get -s upgrade` output, which provides evidence for phased and kept-back classifications.
- The complete `apt-get -s full-upgrade` output, including proposed new packages and transaction totals.

The full-upgrade operation is simulation-only. It is diagnostic evidence, not an execution path. SecureUpdate never runs the simulated full-upgrade transaction.

This makes kernel metapackage changes and their proposed image, module, header, and tools packages visible without turning the report into an automatic kernel installer.

### 5.6 Flatpak pending-update inventory

The final report queries:

```bash
flatpak remote-ls --updates
```

Pending Flatpak updates are listed separately from APT packages. If Flatpak is unavailable or the query fails, the report says that the inventory could not be determined rather than claiming that no updates exist.

## 6. Verified production execution — 19 November 2026

The repository execution record is:

[terminal_logs_20261119_183927.txt](../tmp/terminal_logs_20261119_183927.txt)

The recorded normal-mode run completed successfully:

- NVIDIA 470.256.02 loaded-driver, module, and DKMS checks passed before the APT upgrade.
- APT refreshed its package metadata successfully.
- The normal APT upgrade completed with **12 upgraded, 0 newly installed, 0 removed, and 16 not upgraded**.
- The NVIDIA 470.256.02 checks passed again after the APT upgrade.
- Flatpak reported no pending updates.
- The autoremove preview proposed no removals; the script skipped the confirmation and ran autoclean.
- The final report listed pending APT candidates, separated APT holds, classified phased and kept-back packages, and retained both APT simulations.
- The script exited with status **0**.

At the time of that particular run, the running and newest installed kernel was 6.8.0-147-generic. Kernel 6.8.0-151 appeared in the full-upgrade simulation as a proposed kernel transaction; SecureUpdate did not install it.

The subsequent kernel 151 installation and NVIDIA 470 recovery were completed as separate NVIDIA-Recovery operations. They are later system/recovery results, not actions performed by SecureUpdate. This distinction is intentional: SecureUpdate reports and performs its defined maintenance sequence; kernel installation and NVIDIA recovery remain separately controlled work.

## 7. Operational boundaries

SecureUpdate does not:

- Execute `apt-get full-upgrade`.
- Install or select a kernel.
- Test whether the NVIDIA driver will compile against a future kernel candidate.
- Change APT package holds.
- Install, remove, purge, or switch NVIDIA driver branches.
- Run NVIDIA recovery or repair operations.
- Remove packages without an explicit confirmation after the autoremove preview.
- Treat every pending update as an NVIDIA risk.

These boundaries keep routine maintenance separate from kernel and graphics-driver recovery decisions.

## 8. Related project documentation

- [04 — APT dependency analysis](04-package-dependency-analysis.md)
- [05 — DKMS and driver reference](05-DKMS-and-driver-reference.md)
- [06 — Future correction policy](06-future-correction-policy.md)
- [NVIDIA-Recovery scripts](../scripts/)

## 9. Document history

- **2026-11-19:** Replaced the implementation-in-progress narrative with the finalized production behavior. Documented the identical production/candidate scripts, reporting and classification features, normal and report-only modes, safety boundaries, and successful normal-mode execution. Removed obsolete pending-work, synchronization, and validation-plan sections.

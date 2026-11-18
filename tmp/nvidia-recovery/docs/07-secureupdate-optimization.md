# 07 — SecureUpdate optimization and pending-update reporting

## Status

- **Phase:** Reporting redesign implemented; awaiting live report-only validation
- **Started:** 2026-11-18
- **Target system:** Linux Mint 22.x / Ubuntu 24.04 Noble
- **Current running kernel:** `6.8.0-147-generic`
- **Pending kernel candidate:** `6.8.0-149.149`
- **Active NVIDIA driver:** `470.256.02`
- **SecureUpdate baseline:** `scripts/SecureUpdate_by_ChatGPT.sh`
- **No package or driver changes authorized by this document.**

This document tracks the redesign of SecureUpdate's reporting and update-control logic. It is not an NVIDIA correction or package-cleanup plan.

## 1. Objective

SecureUpdate must make every update that it does not install visible at the end of every run. The operator must not need to inspect Update Manager's checkboxes and infer which updates the script left pending.

The final report must list package names, installed versions, candidate versions when available, and the best-supported reason each package was not installed. The terminal summary must highlight pending updates in red, and the same information must be retained in a timestamped Desktop report.

The script must distinguish a package being pending from a package being unsafe. A harmless user-space update must not be described as an NVIDIA risk merely because it was not installed.

## 2. Existing script behaviour

The current script:

1. Checks that NVIDIA 470.256.02 is loaded.
2. Finds the newest installed kernel module directory.
3. Verifies that the NVIDIA module and DKMS registration for that installed kernel are version 470.256.02.
4. Runs `apt-get update`.
5. Runs conservative `apt-get upgrade`.
6. Repeats the NVIDIA check.
7. Runs `flatpak update`.
8. Previews `apt-get autoremove`, asks before removal, and runs `autoclean` according to the existing branch.

The script does not currently inventory and summarize every package left pending by APT. It also does not explain the distinction between normal-upgrade deferrals, phased updates, package holds, and packages that require a full-upgrade transaction.

The existing NVIDIA check validates the newest kernel already installed. It does not validate a kernel that is merely a candidate in the repositories.

## 3. Confirmed system evidence on 2026-11-18

### 3.1 Kernel and NVIDIA state

- Running kernel: `6.8.0-147-generic`.
- Active NVIDIA driver reported by `nvidia-smi`: `470.256.02`.
- NVIDIA 470 module for kernel 147 is loaded from `/lib/modules/6.8.0-147-generic/updates/dkms/nvidia.ko.zst`.
- DKMS source exists at `/usr/src/nvidia-470.256.02`.
- Its `dkms.conf` declares `AUTOINSTALL="yes"`.
- NVIDIA 470 DKMS is reported installed for kernel 147.
- NVIDIA 580 DKMS is also present: installed for kernel 139 and built for kernel 147. A built entry is not proof that 580 is loaded.
- NVIDIA 470 DKMS source/configuration presence does not prove that it will compile successfully against kernel 149.

### 3.2 APT package holds

The following packages were returned by `apt-mark showhold`:

- `nvidia-dkms-470-server`
- `nvidia-driver-470-server`
- `nvidia-kernel-common-470-server`

The installed 470-server DKMS and driver package versions were `470.256.02-0ubuntu0.24.04.5`; repository candidates were `470.256.02-0ubuntu0.24.04.6`.

These holds must be reported, not silently removed or overridden.

### 3.3 Pending kernel

APT policy showed kernel metapackage candidate `6.8.0-149.149`, while `6.8.0-147.147` was installed.

The normal `apt-get upgrade --dry-run` reported the kernel metapackages as kept back, alongside the held NVIDIA 470 packages. It also reported a separate set of Mesa/audio packages deferred due to phasing.

The `apt-get -s full-upgrade` simulation proposed:

- 3 packages upgraded: `linux-generic`, `linux-image-generic`, `linux-headers-generic`.
- 7 new kernel 149 image/modules/headers/tools packages.
- 0 packages removed.
- NVIDIA 470-server packages still kept back.

This simulation is evidence about APT's proposed transaction only. It is not authorization to execute it and does not prove that NVIDIA 470 will build for kernel 149.

## 4. NVIDIA project constraints

The SecureUpdate redesign must respect the findings in:

- [04 — APT dependency analysis](04-package-dependency-analysis.md)
- [05 — DKMS and driver reference](05-DKMS-and-driver-reference.md)
- [06 — Future correction policy](06-future-correction-policy.md)

In particular:

- The active 470 installation is runfile-managed and uses DKMS identity `nvidia/470.256.02`.
- APT 535/580 packages and transitional dependencies remain installed.
- APT and runfile management overlap around the NVIDIA DKMS identity.
- Generic NVIDIA library symlinks have package-ownership complications.
- Installing/removing the packaged 470 DKMS package can invoke `nvidia-uninstall` and manipulate the same DKMS identity.
- No purge, package unhold, DKMS removal, runfile uninstaller, library-link repair, or driver-branch transition is in scope for this SecureUpdate reporting redesign.

The script must not use `full-upgrade` as an automatic replacement for `upgrade`. It must not automatically unhold packages or force kernel installation.

## 5. Required reporting behaviour

### 5.1 Timestamped Desktop report

Every run must create a report with this naming convention:

```text
$HOME/Desktop/YYYYMMDD_HHMMSS_results_for_secureupdate.txt
```

Use local system time and the exact formats:

- Date: `YYYYMMDD`
- Time: `HHMMSS`

The report must capture command output and diagnostic summaries. The terminal should remain informative while the report is written. Report creation failure must be visible and must not be silently ignored.

### 5.2 Final pending-update inventory

At the end of the run, display a clearly visible red section:

```text
UPDATES NOT INSTALLED — REVIEW REQUIRED
```

For every package still upgradable or otherwise identified as pending, show where available:

- Package name and architecture.
- Installed version.
- Candidate version.
- Classification/reason.
- Whether the package was part of the normal-upgrade simulation.
- Whether it appears only in the full-upgrade simulation.

The inventory must include evidence from more than one source, rather than relying on a single grep of APT's human-readable output.

### 5.3 Required classifications

Keep categories distinct and allow a package to have more than one evidence tag where appropriate:

1. **Held by apt-mark:** package appears in `apt-mark showhold`.
2. **Phased/deferred:** APT explicitly reports the package as deferred due to phasing.
3. **Kept back by normal upgrade:** package is not upgraded by the normal `apt-get upgrade` simulation but is proposed by the full-upgrade simulation, or APT explicitly labels it kept back.
4. **Candidate available / not upgraded:** package has an installed and candidate version difference but is not included in the actual normal-upgrade transaction.
5. **Blocked by SecureUpdate safety gate:** SecureUpdate deliberately did not proceed because a required precondition failed.
6. **Reason undetermined:** a candidate is pending but available evidence does not justify a more specific reason.

Do not infer that an update is harmless or dangerous solely from its package name. Do not label every held-back package as an NVIDIA-related risk.

### 5.4 Preserve raw evidence

The report should retain relevant raw output or clearly delimited excerpts from:

- `apt list --upgradable` (or an equivalent machine-readable APT query).
- `apt-mark showhold`.
- `apt-get upgrade --dry-run`.
- `apt-get -s full-upgrade`.
- The actual update command result.
- NVIDIA pre/post checks.
- Flatpak update result.
- Autoremove preview and operator decision.

APT output wording can vary by version and locale. Parsing must be conservative: if a reason cannot be determined reliably, report it as undetermined rather than guessing.

## 6. Update policy and safety boundaries

The first optimization phase is reporting-only. Preserve the current conservative APT update policy while improving visibility.

- Do not run `full-upgrade` automatically.
- Do not install a new kernel merely because the full-upgrade simulation proposes it.
- Do not change the existing NVIDIA package holds.
- Do not remove the current or previous kernels.
- Do not run autoremove without the existing preview and explicit interactive approval.
- Do not change the NVIDIA driver branch or attempt to reconcile APT 580 with runfile 470.
- Do not claim a pending kernel is NVIDIA-compatible until a separately reviewed build and installation procedure establishes that.
- If NVIDIA pre-update validation fails, stop before package upgrades as the current script intends.
- If post-update NVIDIA validation fails, report a critical failure and stop subsequent maintenance stages.

A future kernel-installation phase may be designed separately after the reporting redesign is tested. It must have its own explicit simulation, exact package transaction review, NVIDIA 470 build verification, rollback plan, and operator approval.

## 7. Proposed execution flow

1. Initialize strict error handling, terminal reporting, and the Desktop report.
2. Record host, OS, running kernel, active NVIDIA driver, installed kernels, DKMS state, and package holds.
3. Run the existing NVIDIA pre-update gate.
4. Refresh APT metadata.
5. Capture the normal-upgrade simulation and full-upgrade simulation; simulations must not modify packages.
6. Run the existing conservative `apt-get upgrade` transaction only if the pre-update gate succeeds.
7. Run the NVIDIA post-update gate.
8. Run Flatpak update only if the preceding required stages succeed.
9. Preserve the autoremove dry-run and explicit confirmation.
10. Rebuild the pending-update inventory after maintenance, so the report reflects what remains pending now.
11. Print every pending package in red in the final terminal summary, with category/reason and version information.
12. Close the report with exit status, completion time, and report path.

The script must preserve meaningful failure exit codes. A failed update or failed NVIDIA gate must not be disguised as a successful run merely because the final reporting stage completed.

## 8. Validation plan

The first validation must be non-destructive and use the current pending kernel 149 as a known test case.

Expected observations before kernel installation:

- Kernel 149 remains visible in the final pending inventory.
- Its installed and candidate versions are shown.
- It is classified as requiring a transaction beyond the normal upgrade path / kept back by normal upgrade, based on captured APT simulation evidence.
- The report explicitly says that no kernel installation was attempted.
- NVIDIA 470 package holds are listed separately.
- Phased Mesa/audio packages are listed separately when APT reports them.
- No package is installed, removed, unheld, or otherwise modified by the reporting-only validation.

The report must be compared against Update Manager's visible pending list. Any discrepancy must be investigated before the script is considered reliable.

Subsequent validation should include:
- No pending APT updates.
- One or more held packages.
- Phased updates.
- Packages kept back by normal upgrade but proposed by full-upgrade.
- NVIDIA pre-check failure.
- APT update/upgrade failure.
- Report-directory or report-write failure.

## 9. Scope exclusions

This work does not:

- Correct or remove NVIDIA 580/535 packages.
- Change the runfile-managed NVIDIA 470 installation.
- Unhold NVIDIA packages.
- Install kernel 149.
- Change Mint Update Manager settings.
- Reproduce the Update Manager GUI.
- Replace the NVIDIA recovery/backup scripts.

The immediate deliverable is a trustworthy SecureUpdate script and a final report that makes every pending update visible without changing the existing safety posture.

## 10. Change log

- **2026-11-18:** Initial design record created from the current SecureUpdate script, live APT simulations, NVIDIA/DKMS diagnostics, and the NVIDIA recovery project's documented correction constraints.


## 11. Reporting implementation committed

The reporting redesign has been implemented in:

- [`scripts/SecureUpdate_by_ChatGPT.sh`](../scripts/SecureUpdate_by_ChatGPT.sh)

The script retains the existing conservative maintenance sequence and NVIDIA 470.256.02 pre/post checks. It does **not** execute `full-upgrade`, remove packages, unhold NVIDIA packages, install kernel 149, or alter the NVIDIA driver branch.

### 11.1 New report behaviour

- Creates a Desktop report named `YYYYMMDD_HHMMSS_results_for_secureupdate.txt`.
- Uses `tee` so terminal output is also recorded in the report.
- Uses restrictive report permissions (`0600`).
- Runs a final report through an EXIT trap, including when an earlier maintenance command fails.
- Lists every APT candidate from `apt list --upgradable` in red, retaining installed and candidate versions.
- Lists APT package holds separately in red.
- Correlates candidate packages with the normal-upgrade simulation's phased and kept-back sections where possible; uncertain reasons are not guessed.
- Shows the full normal-upgrade simulation as supporting evidence.
- Shows proposed `Inst` package transactions from the full-upgrade simulation in red, but never executes that transaction. This is important for new kernel image/module/header packages that do not appear as ordinary installed-package upgrades.
- Lists pending Flatpak updates separately using `flatpak remote-ls --updates`.
- Explicitly states that pending updates are not automatically NVIDIA risks.

### 11.2 Report-only validation mode

Run the script with:

```bash
bash SecureUpdate_by_ChatGPT.sh --report-only
```

This mode:
- Runs the existing NVIDIA pre-check.
- Does not refresh APT metadata.
- Uses the currently cached APT package lists for simulations and inventory.
- Does not run APT upgrades, Flatpak updates, autoremove, or any package/driver transaction.
- Still creates the timestamped Desktop report and final pending-update inventory.

The normal mode continues to run `apt-get update`, conservative `apt-get upgrade`, the NVIDIA post-check, Flatpak update, and the existing autoremove preview/confirmation flow.

### 11.3 Validation status

- Local `bash -n` syntax validation: **passed**.
- ShellCheck: unavailable in the validation environment.
- Live execution on the M4800: **not yet performed**.
- Package/driver changes made during implementation: **none**.
- Kernel 6.8.0-149: remains pending; no installation was attempted.

The first live test must use `--report-only`. Review the resulting report against Update Manager before running the normal maintenance mode. The expected kernel evidence is the 6.8.0-149 metapackage candidate in the APT candidate list and the corresponding new kernel packages in the full-upgrade simulation section.

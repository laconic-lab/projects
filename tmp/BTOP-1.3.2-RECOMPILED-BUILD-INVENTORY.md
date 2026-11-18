# Recompiled btop 1.3.2 — Build, Test & Installation Inventory

**Recorded:** 2026-11-18  
**Host:** Dell Precision M4800 · Linux Mint 22 Cinnamon  
**Purpose:** Track the recompiled build, runtime evidence, installation decision, and a complete rollback route so retained artifacts can be assessed during a later disk-space and backup inventory.

## Current disposition

**btop 1.3.2 is installed under `/usr/local` and has passed post-install verification.** The Ubuntu Noble package **btop 1.3.0-1 remains installed** at `/usr/bin/btop`; it was not replaced or removed. Normal PATH resolution selects `/usr/local/bin/btop` (1.3.2). No rollback or cleanup has been performed.

The user reported that btop 1.3.2 looked and behaved normally compared with 1.3.0 during interactive use, including YouTube and Speedtest workloads. The 1 GB download test also completed successfully and was subsequently deleted by the user.

## Verified source and build

| Property | Verified value |
|---|---|
| Source checkout | `/home/laco/src/btop-v1.3.2` |
| Source tag | `v1.3.2` |
| Source commit | `fd2a2acdad6fbaad76846cb5e802cf2ae022d670` |
| Commit date | 2024-02-12 16:30:09 +0100 |
| Commit subject | `v1.3.2 Hotfix GPU support AMD ROCm v6` |
| Compiled binary | `/home/laco/src/btop-v1.3.2/bin/btop` |
| Reported version | `btop version: 1.3.2` |
| Architecture | x86-64 ELF, dynamically linked |
| Binary size | 1,849,736 bytes |
| Binary SHA256 | `aea40643f6232b39ff891cfb94b38b3d24d322cc4d3eecc06d9767cb85e437b2` |
| Source workspace size at audit | 28 MB |

The binary's reported dynamic dependencies resolved successfully during the audit. The binary is not stripped.

## Installed Noble package baseline

| Property | Verified value |
|---|---|
| Package | `btop` |
| Installed version | `1.3.0-1` |
| Candidate version | `1.3.0-1` |
| Repository | Ubuntu Noble `universe` |
| Executable | `/usr/bin/btop` |
| Package status | `install ok installed` |

The installed package owns files under `/usr/bin`, `/usr/share/btop`, `/usr/share/applications`, `/usr/share/doc/btop`, `/usr/share/icons`, and `/usr/share/man/man1`. Its full package file list was recorded in the installation preflight report.

## Runtime and I/O test evidence

### Isolated interactive runtime

- Test executable: `/home/laco/src/btop-v1.3.2/bin/btop`
- Isolated test directory: `/home/laco/.cache/btop-132-test.oR03xG`
- Runtime report: `/home/laco/Desktop/20261118_153204_results_for_btop_132_runtime_test.txt`
- Post-runtime audit: `/home/laco/Desktop/20261118_154248_results_for_btop_132_post_runtime_audit.txt`
- The isolated test used a copied configuration; the copied old log was excluded.
- Original configuration SHA256 before test: `c50670f7c61d597d147c0bd85bbf826835b5381198a17d6e87a854541e5885ad`
- Post-test SHA256 matched exactly: `c50670f7c61d597d147c0bd85bbf826835b5381198a17d6e87a854541e5885ad`
- The fresh 414-byte runtime log identified btop 1.3.2 and reported four NVML fields as `Not Supported`: maximum GPU power draw (fallback 225 W), PCIe TX, PCIe RX, and GPU power usage. These messages are recorded as unsupported telemetry fields, not as proof of a fatal NVML initialization failure.
- User's assessment: interface and behaviour appeared normal, with no observed abnormality.

### Sustained download / disk-write test

- Test report: `/home/laco/Desktop/20261118_162723_results_for_btop_132_download_disk_io.txt`
- URL: `https://fsn1-speed.hetzner.com/1GB.bin`
- Destination during test: `/home/laco/btop-io-test-20261118_162723.bin`
- HTTP status: `200`
- Bytes received: `1,073,741,824`
- Elapsed time: approximately 29 seconds
- Average transfer rate reported by curl: approximately 37.1 MB/s
- Destination filesystem: `/dev/sdc4`, ext4, mounted at `/home`
- The user subsequently deleted the 1 GB test file. No assistant-directed cleanup was performed.

The download confirmed successful network transfer and file creation on the home filesystem. The report does not contain a separate kernel block-device throughput trace, so it should not be treated as a quantitative disk benchmark.

## Installation preflight and proposed layout

The source Makefile defaults to `PREFIX=/usr/local`. Its reviewed `install` target copies these items:

| Component | Proposed local installation path |
|---|---|
| Executable | `/usr/local/bin/btop` |
| README | `/usr/local/share/btop/README.md` |
| Themes | `/usr/local/share/btop/themes/` |
| Desktop entry | `/usr/local/share/applications/btop.desktop` |
| PNG icon | `/usr/local/share/icons/hicolor/48x48/apps/btop.png` |
| SVG icon | `/usr/local/share/icons/hicolor/scalable/apps/btop.svg` |

The Makefile dry run was reviewed. All six source inputs existed. At preflight time, none of the proposed destination paths existed, and dpkg did not own `/usr/local/bin/btop`.

### PATH conflict check

The user's PATH order was:

`/home/laco/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:...`

The final conflict check established:

- `/home/laco/.local/bin/btop`: absent
- `/usr/local/bin/btop`: absent
- `/usr/bin/btop`: present, root-owned, executable
- Current `btop` resolution: `/usr/bin/btop`

If a future `/usr/local/bin/btop` installation is performed, it will take precedence over `/usr/bin/btop` in this PATH.

### Installation executed — 2026-11-18

The user approved and executed the reviewed parallel installation:

```bash
sudo make -C /home/laco/src/btop-v1.3.2 install PREFIX=/usr/local
```

Installation report: `/home/laco/Desktop/20261118_201817_results_for_btop_132_install.txt`.

The installer reported successful placement of all six reviewed artifacts under `/usr/local`. No error was reported. The Ubuntu package was not removed or modified by this install command.

### Post-install verification — PASS

Verification report: `/home/laco/Desktop/20261118_202353_results_for_btop_132_install_verification.txt`.

| Check | Result |
|---|---|
| All six expected `/usr/local` paths | Present |
| Installed binary SHA256 | Matches audited build exactly: `aea40643f6232b39ff891cfb94b38b3d24d322cc4d3eecc06d9767cb85e437b2` |
| `/usr/local/bin/btop --version` | `btop version: 1.3.2` |
| `/usr/bin/btop --version` | `btop version: 1.3.0` |
| `command -v btop` | `/usr/local/bin/btop` |
| `type -a btop` | `/usr/local/bin/btop`, `/usr/bin/btop`, `/bin/btop` |
| dpkg package status | `btop 1.3.0-1`, `install ok installed` |
| dpkg ownership of `/usr/bin/btop` | Confirmed: `btop: /usr/bin/btop` |
| `dpkg -V btop` | No discrepancies reported |

The installation is therefore a verified parallel `/usr/local` install. Ubuntu's package-managed 1.3.0 remains installed and intact according to the recorded dpkg checks. The compiled executable installed under `/usr/local` is byte-for-byte identical to the audited build.

A final normal-command interactive launch through PATH is the remaining practical check; it has not yet been recorded as completed.

## Rollback and clean recovery — primary procedure

**Preferred recovery objective:** completely remove the locally compiled btop 1.3.2 installation from `/usr/local`, verify that its installed files are gone, and restore a clean, known-good Ubuntu Noble btop 1.3.0 installation.

This is the primary rollback route if the parallel `/usr/local` installation is ever performed and later rejected. It is more than switching PATH back to `/usr/bin`: remove the complete set of files installed by the reviewed Makefile transaction, then reinstall the Noble package.

### A. Preconditions and scope

1. Close all running btop instances before changing installed files.
2. Confirm the actual installation paths and compare them with the reviewed list below.
3. Only remove files that belong to this specific btop 1.3.2 `PREFIX=/usr/local` installation.
4. Do not use broad wildcards, recursive removal of general parent directories, or an unreviewed `make uninstall` command.
5. Do not remove the source/build workspace, isolated test directory, reports, or the user's `~/.config/btop` configuration as part of uninstalling the system installation.

### B. Complete removal of the local 1.3.2 installation

The reviewed Makefile's install target creates/copies the following exact paths:

```text
/usr/local/bin/btop
/usr/local/share/btop/README.md
/usr/local/share/btop/themes/
/usr/local/share/applications/btop.desktop
/usr/local/share/icons/hicolor/48x48/apps/btop.png
/usr/local/share/icons/hicolor/scalable/apps/btop.svg
```

Before removal, inspect these exact paths. If and only if they match the files installed by this btop transaction, remove the exact installed artifacts:

```bash
sudo rm -f /usr/local/bin/btop
sudo rm -rf /usr/local/share/btop
sudo rm -f /usr/local/share/applications/btop.desktop
sudo rm -f /usr/local/share/icons/hicolor/48x48/apps/btop.png
sudo rm -f /usr/local/share/icons/hicolor/scalable/apps/btop.svg
```

These commands target only the reviewed btop installation paths. They do not remove the parent `/usr/local` directories or unrelated icons/applications.

### C. Verify local-install removal

Check that all six paths above are absent. Also check command resolution and confirm that the selected executable is `/usr/bin/btop`, not a remaining copy under `/usr/local` or `~/.local`.

Do not proceed to package reinstall if any unexpected btop 1.3.2 installation artifact remains; inspect it first rather than broadening the deletion.

### D. Reinstall the Ubuntu Noble package

The recorded Noble candidate is exactly `1.3.0-1`. After confirming the local installation is gone and the package candidate is still the expected version, reinstall the distribution package:

```bash
sudo apt-get install --reinstall btop=1.3.0-1
```

This reinstalls the already-installed Noble package version and restores its package-managed executable, themes, desktop entry, icons, documentation, and man page as defined by dpkg.

If the Noble package has been removed or purged separately before this recovery, first verify that `1.3.0-1` is still available from the configured Noble repositories, then use the normal package installation path for that exact version. Do not substitute a different candidate without reviewing it.

### E. Final recovery verification

Verify all of the following:

- `dpkg-query -W btop` reports `1.3.0-1` and installed status.
- `/usr/bin/btop --version` reports btop 1.3.0.
- `command -v btop` resolves to `/usr/bin/btop` (with no higher-priority local executable).
- The expected package-owned files are present according to `dpkg-query -L btop`.
- A normal interactive launch works.
- The user's configuration remains present and is not reset or deleted.

**Important:** the rollback procedure above is documented for future use. It has not been executed because btop 1.3.2 has not yet been installed.

## Retained artifacts and storage handling

| Artifact | Path | Current disposition |
|---|---|---|
| Source/build workspace | `/home/laco/src/btop-v1.3.2` | Retain; reproducible source/build material |
| Compiled binary | `/home/laco/src/btop-v1.3.2/bin/btop` | Retain as uninstalled 1.3.2 build |
| Isolated test directory | `/home/laco/.cache/btop-132-test.oR03xG` | Retained test evidence/configuration |
| Runtime report | `/home/laco/Desktop/20261118_153204_results_for_btop_132_runtime_test.txt` | Retain |
| Post-runtime audit | `/home/laco/Desktop/20261118_154248_results_for_btop_132_post_runtime_audit.txt` | Retain |
| Download I/O report | `/home/laco/Desktop/20261118_162723_results_for_btop_132_download_disk_io.txt` | Retain |
| Final build audit | `/home/laco/Desktop/20261118_163512_results_for_btop_132_final_build_audit.txt` | Retain |
| Installation preflight | `/home/laco/Desktop/20261118_163606_results_for_btop_132_installation_preflight.txt` | Retain |
| Install transaction review | `/home/laco/Desktop/20261118_163657_results_for_btop_132_install_transaction_review.txt` | Retain |
| Final PATH conflict check | `/home/laco/Desktop/20261118_163747_results_for_btop_132_path_conflict_check.txt` | Retain |

No cleanup of these artifacts is authorized or implied by the system-installation rollback procedure. Assess their actual disk usage separately before any later retention decision.

## Current disposition summary

- Source tag and commit verified.
- Compiled 1.3.2 binary verified by version, ELF metadata, SHA256, and dependency resolution.
- Interactive runtime assessment positive.
- Original user configuration checksum matched after isolated test.
- 1 GB download test succeeded; downloaded file later deleted by user.
- Installation layout and Makefile transaction reviewed.
- PATH conflict check clean.
- Ubuntu Noble btop 1.3.0-1 remains installed.
- 1.3.2 installed under `/usr/local` after explicit user approval; all six paths and binary hash verified.
- Ubuntu Noble `btop 1.3.0-1` remains installed at `/usr/bin/btop`; dpkg reports no discrepancies.
- No rollback, package removal, or cleanup has been performed.
- Remaining practical check: launch `btop` through normal PATH, confirm 1.3.2 interactively, then exit normally.

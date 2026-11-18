# Recompiled btop 1.3.2 — Build & Test Inventory

**Recorded:** 2026-11-18  
**Host:** Dell Precision M4800 · Linux Mint 22 Cinnamon  
**Purpose:** Identify the retained source/build and test artifacts so they can be assessed during a later disk-space and backup inventory.

## Status

**Runtime assessment: encouraging; installation not yet approved.**

A locally recompiled **btop 1.3.2** launched and was used interactively. The user exercised YouTube and Speedtest workloads and reported that the displayed system information remained coherent.

The existing system installation was **not replaced**. The previously installed btop 1.3.0 remains the system version pending any separate installation decision.

## Artifact inventory

| Artifact | Path | Role / current handling |
|---|---|---|
| Source checkout and build workspace | `/home/laco/src/btop-v1.3.2` | Retained source tree; contains the locally compiled build |
| Compiled executable | `/home/laco/src/btop-v1.3.2/bin/btop` | Experimental btop 1.3.2 binary; launched directly, not installed |
| Isolated runtime test directory | `/home/laco/.cache/btop-132-test.oR03xG` | Temporary XDG configuration area used for the test; copied configuration/themes and runtime-generated test data may remain here |
| Runtime test report | `/home/laco/Desktop/20261118_153204_results_for_btop_132_runtime_test.txt` | Captured test setup and pre-launch checks |

## Verified test details

- Report timestamp: **2026-11-18 15:32:04 CET**
- Executable reported: **btop 1.3.2**
- NVIDIA NVML libraries were visible to the process environment:
  - `/lib/x86_64-linux-gnu/libnvidia-ml.so.1`
  - `/lib/x86_64-linux-gnu/libnvidia-ml.so`
  - 32-bit counterparts were also listed under `/lib/i386-linux-gnu/`
- Existing btop configuration and themes were copied into the isolated test configuration.
- The copied prior `btop.log` was excluded so the test could generate a fresh log.
- Original configuration checksum recorded before launch:
  `c50670f7c61d597d147c0bd85bbf826835b5381198a17d6e87a854541e5885ad`
- Interactive use: user reported coherent displayed information during YouTube and Speedtest activity.

## Evidence boundary / outstanding verification

The supplied report ends at the interactive launch instructions. Its final tail contains no post-run section showing:

- the btop exit status;
- inspection of the fresh runtime log;
- the post-test checksum comparison for the original configuration.

Therefore, those automated post-run checks are **not evidenced by this report**. The user's visual/functional assessment is positive, but the original configuration's unchanged status was not confirmed in the supplied output.

## Storage and cleanup notes

No artifact has been deleted or moved as part of this test.

For a later storage review, assess the source/build workspace, isolated test directory, and report separately. Do not assume the source tree is disposable: it is the reproducible local build workspace. Before removing anything, decide whether to retain the source, binary, and test evidence, and record their actual disk usage.

No installation, system package replacement, NVIDIA driver change, kernel change, or desktop configuration change was performed by this runtime test.

## Current disposition

**Keep as an uninstalled experimental build pending the remaining verification and an explicit installation decision.**

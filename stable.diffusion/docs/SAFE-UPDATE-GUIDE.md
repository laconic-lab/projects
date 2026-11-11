# Stable Diffusion — Safe Update & Rebuild Guide

> **Document type:** Controlled maintenance procedure  
> **Execution model:** Manual, staged, stop-on-error  
> **Recorded baseline:** 2026-10-25  
> **Target:** `stable-diffusion.cpp` source, `sd-server`, and `sd-cli`

## Contents

- [Purpose](#purpose)
- [Safety rules](#safety-rules)
- [Execution map](#execution-map)
- [Step 1 — Back up first (SteamOS host)](#step-1-back-up-first-steamos-host)
- [Step 2 — Inspect the current source (inside Stable-box)](#step-2-inspect-the-current-source-inside-stable-box)
- [Step 3 — Review upstream changes (inside Stable-box)](#step-3-review-upstream-changes-inside-stable-box)
- [Step 4 — Update source and submodules](#step-4-update-source-and-submodules)
- [Step 5 — Check local build tools](#step-5-check-local-build-tools)
- [Step 6 — Rebuild separately](#step-6-rebuild-separately)
- [Step 7 — Test the new build before replacement](#step-7-test-the-new-build-before-replacement)
- [Step 8 — Save old binaries and promote the new ones](#step-8-save-old-binaries-and-promote-the-new-ones)
- [Step 9 — Verify promoted binaries and service](#step-9-verify-promoted-binaries-and-service)
- [Step 10 — Roll back if the update fails](#step-10-roll-back-if-the-update-fails)
- [Recorded known-working settings](#recorded-known-working-settings)

---

## Purpose

Update the source and rebuild `sd-server` and `sd-cli` without immediately replacing the currently working binaries. A newer upstream commit is not, by itself, a reason to update.

## Safety rules

- Do not update SteamOS as part of this procedure.
- Do not modify Pi-hole, SSH, Waydroid, or firewall settings.
- Keep the WebUI bound to loopback; do not expose it directly to the LAN.
- Keep using the SSH tunnel for remote browser access.
- Do not delete the model, outputs, project directory, or known-good binaries.
- Do not replace existing binaries until the separate build passes its checks.
- **If a step fails, stop.** Do not continue to promotion.
- Do not use unofficial precompiled binaries.
- Do not force a Git merge or use `git reset --hard` as a shortcut.

## Execution map

```text
Host backup
    ↓
Inspect current source and upstream changes
    ↓
Approve update intentionally
    ↓
Fast-forward source + update submodules
    ↓
Build in separate build-update/ directory
    ↓
Test new binaries and Vulkan device
    ↓
Back up old binaries
    ↓
Promote new binaries
    ↓
Verify WebUI + real image generation
    ↓
Keep rollback copy until success is established
```

## Step 1 — Back up first (SteamOS host)

Stop the WebUI inside `Stable-box`:

```bash
cd /home/deck/StableDiffusionProject
./sd-stop.sh
```

If starting from the host prompt:

```bash
distrobox enter Stable-box -- bash -lc \
  'cd /home/deck/StableDiffusionProject && ./sd-stop.sh'
```

Then, on the SteamOS host:

```bash
~/Stable-backup.sh
```

Wait for `BACKUP COMPLETE`. Preserve the dated archive and checksum.

## Step 2 — Inspect the current source (inside Stable-box)

```bash
cd /home/deck/StableDiffusionProject
git status --short
git branch --show-current
git rev-parse HEAD
git submodule status
```

The original setup included intentional local, untracked items such as `logs/`, `outputs/`, `tools/`, `sd-start.sh`, and `sd-stop.sh`. Do not delete them.

If tracked source files have local modifications you need, stop and investigate before proceeding.

## Step 3 — Review upstream changes (inside Stable-box)

```bash
git fetch origin
git log --oneline --decorate -10
git log --oneline HEAD..origin/master
```

Read relevant upstream commit messages and release notes. If `origin/master` does not exist, stop and inspect the configured remote and branch rather than guessing.

If the changes do not justify the risk, stop here. Fetching alone does not replace the working binaries.

## Step 4 — Update source and submodules

Confirm there are no tracked local changes you need to preserve:

```bash
git diff --exit-code
git diff --cached --exit-code
```

Then fast-forward and synchronize submodules:

```bash
git merge --ff-only origin/master
git submodule update --init --recursive
git rev-parse HEAD
git submodule status
```

If the merge fails or reports conflicts, stop. Do not force the merge.

## Step 5 — Check local build tools

Inside `Stable-box`:

```bash
cd /home/deck/StableDiffusionProject
export NODE_HOME="$PWD/tools/node-dist/node-v22.23.4-linux-x64"
export PATH="$NODE_HOME/bin:$PWD/tools/npm-global/bin:$PATH"

node --version
pnpm --version
cmake --version
ninja --version
./build/bin/sd-cli --list-devices
```

Confirm the AMD Vulkan device is listed. Do not proceed if Vulkan or the local build tools are unavailable.

## Step 6 — Rebuild separately

Install frontend dependencies from the checked-out lockfile:

```bash
pnpm --ignore-workspace -C examples/server/frontend install --frozen-lockfile
```

Configure a separate build directory so the existing `build/` directory and binaries remain untouched:

```bash
cmake -S . -B build-update -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DSD_VULKAN=ON \
  -DSD_SERVER_BUILD_FRONTEND=ON \
  -DPNPM_EXECUTABLE="$PWD/tools/npm-global/bin/pnpm"

cmake --build build-update --parallel 4
```

If configuration or compilation fails, stop. Do not remove `build/` or the model to solve a build error.

## Step 7 — Test the new build before replacement

```bash
./build-update/bin/sd-server --help
./build-update/bin/sd-cli --list-devices
```

Confirm both commands work and the AMD Vulkan device appears. If a supported generation test is available, use a known-good input image, model, and settings. `--help` alone does not prove image generation works.

If any test fails, do not replace the current binaries.

## Step 8 — Save old binaries and promote the new ones

Proceed only after the separate build and tests succeed.

Create a dated copy of the current binaries:

```bash
STAMP="$(date +%Y%m%d_%H%M%S)"
SAVE="/home/deck/StableDiffusionrecovery/pre-update-binaries-$STAMP"
mkdir -p "$SAVE"
cp -a build/bin/sd-server build/bin/sd-cli "$SAVE/"
```

Copy the new binaries to temporary names, validate them, then promote:

```bash
cp build-update/bin/sd-server build/bin/sd-server.new
cp build-update/bin/sd-cli build/bin/sd-cli.new

test -x build/bin/sd-server.new
test -x build/bin/sd-cli.new

mv build/bin/sd-server build/bin/sd-server.pre-update
mv build/bin/sd-cli build/bin/sd-cli.pre-update

mv build/bin/sd-server.new build/bin/sd-server
mv build/bin/sd-cli.new build/bin/sd-cli
```

The dated `SAVE` directory is the explicit rollback copy. The `.pre-update` files are an additional safeguard. Preserve the exact `SAVE` path for rollback.

## Step 9 — Verify promoted binaries and service

```bash
./build/bin/sd-server --help
./build/bin/sd-cli --list-devices
bash -n ./sd-start.sh
bash -n ./sd-stop.sh
./sd-start.sh
```

From the SteamOS host, check the loopback WebUI:

```bash
curl -sS -o /dev/null -w 'HTTP status: %{http_code}\n' \
  http://127.0.0.1:1234/
```

Expected result: HTTP 200.

Then test a real image generation through the WebUI. Confirm Vulkan is used and image-to-image works. An HTTP response alone does not prove generation is functioning.

## Step 10 — Roll back if the update fails

Stop the WebUI first. Inside `Stable-box`, set `SAVE_PATH` to the exact dated directory created in Step 8:

```bash
SAVE_PATH="/home/deck/StableDiffusionrecovery/pre-update-binaries-REPLACE_ME"

cd /home/deck/StableDiffusionProject
test -s "$SAVE_PATH/sd-server"
test -s "$SAVE_PATH/sd-cli"

cp -a "$SAVE_PATH/sd-server" build/bin/sd-server
cp -a "$SAVE_PATH/sd-cli" build/bin/sd-cli

./build/bin/sd-server --help
./build/bin/sd-cli --list-devices
```

Do not delete the new build or change source history while investigating. Restoring old binaries does not roll back the Git source or submodules. The dated project-level backup remains the broader fallback.

## Recorded known-working settings

| Setting | Recorded value |
|---|---|
| CMake build type | `-DCMAKE_BUILD_TYPE=Release` |
| Vulkan | `-DSD_VULKAN=ON` |
| Frontend | `-DSD_SERVER_BUILD_FRONTEND=ON` |
| Backend | `diffusion=vulkan0,te=cpu,vae=vulkan0` |
| Model | `models/v1-5-pruned_Q4_K.gguf` |
| WebUI | `127.0.0.1:1234` |
| Source | [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) |
| Build instructions | [Upstream build guide](https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/build.md) |
| Frontend instructions | [Upstream server example](https://github.com/leejet/stable-diffusion.cpp/tree/master/examples/server) |

---

A new source revision is not automatically a better revision. Keep the known-good backup and old binaries until actual image-generation tests pass.

# Stable Diffusion — Recovery & Restore Guide

> **Document type:** Recovery procedure  
> **Scope:** Project tree and Distrobox recovery, not a full SteamOS image  
> **Status:** Clean-container restore procedure has not been documented as tested.

## Contents

- [Purpose and limits](#purpose-and-limits)
- [Recovery flow](#recovery-flow)
- [1. Locate and verify a backup (SteamOS host)](#1-locate-and-verify-a-backup-steamos-host)
- [2. Restore to a separate directory first](#2-restore-to-a-separate-directory-first)
- [3. If Stable-box still exists](#3-if-stable-box-still-exists)
- [4. If the container must be recreated](#4-if-the-container-must-be-recreated)
- [5. Verify the recovered project](#5-verify-the-recovered-project)
- [6. Safety boundaries](#6-safety-boundaries)
- [Related documents](#related-documents)

---

## Purpose and limits

The project-level backup preserves the project tree, including source, submodules, build outputs, model, local Node.js tools, scripts, outputs, and logs. It does **not** store Ubuntu packages as a separate Distrobox image and is not a complete SteamOS snapshot.

## Recovery flow

```text
Locate archive and verify checksum
              ↓
Extract into a separate restore directory
              ↓
Inspect restored project and model
              ↓
Reuse Stable-box if it still exists
              ↓
Verify binaries, Vulkan, scripts and WebUI
              ↓
Test real generation before considering recovery complete
```

## 1. Locate and verify a backup (SteamOS host)

```bash
ls -lh /home/deck/StableDiffusionBackups/
sha256sum /home/deck/StableDiffusionBackups/StableDiffusionProject_*.tar.gz
```

Compare the archive checksum against the `SHA256SUMS.txt` file generated alongside that specific archive. Confirm the exact archive filename before restoring.

## 2. Restore to a separate directory first

Replace `ARCHIVE` with the exact backup filename. Do not extract over the working project.

```bash
mkdir -p /home/deck/StableDiffusionProject-restored
tar -tzf /home/deck/StableDiffusionBackups/ARCHIVE.tar.gz | head
tar -xzf /home/deck/StableDiffusionBackups/ARCHIVE.tar.gz \
  -C /home/deck/StableDiffusionProject-restored \
  --strip-components=1
```

Inspect the restored files before using them. Preserve the current project before deciding whether to replace it.

## 3. If Stable-box still exists

Prefer reusing the existing container. Do not recreate it merely because the WebUI fails to start.

On the host:

```bash
distrobox list
distrobox enter Stable-box
```

Inside the container:

```bash
cd /home/deck/StableDiffusionProject
ls -lh build/bin/sd-server models/v1-5-pruned_Q4_K.gguf
tail -n 80 logs/server.log
```

If project files appear damaged, preserve them and restore a verified backup to a separate directory before deciding how to replace the live project.

## 4. If the container must be recreated

Only consider this if `Stable-box` is genuinely missing or unusable. Preserve the old container and project if possible before removing anything.

Create the container:

```bash
distrobox create --name Stable-box --image docker.io/library/ubuntu:24.04 --yes
```

Enter it, restore the project into `/home/deck/StableDiffusionProject`, and install the recorded required Ubuntu build/runtime packages:

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build git \
  libvulkan-dev glslc spirv-headers pkg-config \
  vulkan-tools mesa-vulkan-drivers curl ca-certificates
```

The project backup includes local Node.js and pnpm tools. From the project directory:

```bash
cd /home/deck/StableDiffusionProject
export NODE_HOME="$PWD/tools/node-dist/node-v22.23.4-linux-x64"
export PATH="$NODE_HOME/bin:$PWD/tools/npm-global/bin:$PATH"
```

Reinstall frontend dependencies from the committed lockfile and rebuild:

```bash
pnpm --ignore-workspace -C examples/server/frontend install --frozen-lockfile
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DSD_VULKAN=ON \
  -DSD_SERVER_BUILD_FRONTEND=ON \
  -DPNPM_EXECUTABLE="$PWD/tools/npm-global/bin/pnpm"
cmake --build build --parallel 4
```

**Important:** these are recorded recovery instructions, not a claim that a clean-container restore has been tested end to end.

## 5. Verify the recovered project

Inside `Stable-box`:

```bash
cd /home/deck/StableDiffusionProject
./build/bin/sd-cli --list-devices
./build/bin/sd-server --help
bash -n sd-start.sh
bash -n sd-stop.sh
sha256sum models/v1-5-pruned_Q4_K.gguf
```

Confirm that the expected AMD Vulkan device appears and compare the model checksum with the recorded value in [Project Details](./PROJECT-DETAILS.md).

Start the WebUI manually:

```bash
./sd-start.sh
```

From the SteamOS host, check loopback HTTP:

```bash
curl -sS -o /dev/null -w 'HTTP status: %{http_code}\n' \
  http://127.0.0.1:1234/
```

Expected HTTP status: 200. Stop the WebUI when finished:

```bash
./sd-stop.sh
```

An HTTP 200 response alone does not prove image generation works. Where practical, test an actual generation before declaring recovery complete.

## 6. Safety boundaries

- Do not enable automatic startup or automatic restart.
- Do not expose the WebUI on `0.0.0.0` or change firewall rules for recovery.
- Keep using the existing SSH tunnel for Windows browser access.
- Do not modify `pihole-box`, Waydroid, or SSH configuration as part of Stable Diffusion recovery.
- Do not delete the original project or backup until a restored copy has been verified.
- Treat any recovered environment as unverified until its binaries, model, GPU backend, listener, and generation behavior have been checked.

## Related documents

- [Project Details & Verified Baseline](./PROJECT-DETAILS.md)
- [Safe Update & Rebuild Guide](./SAFE-UPDATE-GUIDE.md)
- [Build & Backup Manifest](./BUILD-AND-BACKUP-MANIFEST.md)
- [Archived original documents](./archive/originals/)

# Stable Diffusion — Recovery Guide

## Scope

This is a project-level backup, not a full SteamOS image or a complete
container snapshot. It preserves the project tree, including source,
submodules, build outputs, model, local Node.js tools, scripts, outputs,
and logs. Ubuntu packages installed in the Distrobox are not stored as
a separate container image.

## 1. Locate and verify a backup

On the SteamOS host:

    ls -lh /home/deck/StableDiffusionBackups/
    sha256sum /home/deck/StableDiffusionBackups/StableDiffusionProject_*.tar.gz

Compare the archive checksum against the SHA256SUMS.txt file generated
alongside that specific archive.

## 2. Restore without overwriting the live project

Choose a new destination and extract there first. Replace ARCHIVE below
with the exact backup filename:

    mkdir -p /home/deck/StableDiffusionProject-restored
    tar -tzf /home/deck/StableDiffusionBackups/ARCHIVE.tar.gz | head
    tar -xzf /home/deck/StableDiffusionBackups/ARCHIVE.tar.gz \
      -C /home/deck/StableDiffusionProject-restored \
      --strip-components=1

Inspect the restored files before using them. Do not extract over a
working project directory without first preserving that directory.

## 3. If Stable-box still exists

Prefer reusing the existing container. Do not recreate it merely because
the WebUI fails to start.

    distrobox list
    distrobox enter Stable-box

Inside the container, inspect the project, model, scripts, and logs:

    cd /home/deck/StableDiffusionProject
    ls -lh build/bin/sd-server models/v1-5-pruned_Q4_K.gguf
    tail -n 80 logs/server.log

If the existing project files are damaged, preserve them and restore a
verified backup to a separate directory before deciding how to replace
the live project.

## 4. If the container must be recreated

Only do this if Stable-box is genuinely missing or unusable. Preserve
the old container and project if possible before removing anything.

Create the container:

    distrobox create --name Stable-box --image docker.io/library/ubuntu:24.04 --yes

Enter it, restore the project into /home/deck/StableDiffusionProject,
and install the required Ubuntu build/runtime packages:

    sudo apt-get update
    sudo apt-get install -y \
      build-essential cmake ninja-build git \
      libvulkan-dev glslc spirv-headers pkg-config \
      vulkan-tools mesa-vulkan-drivers curl ca-certificates

The project backup includes local Node.js and pnpm tools. From the
project directory, set the local tool paths:

    cd /home/deck/StableDiffusionProject
    export NODE_HOME="$PWD/tools/node-dist/node-v22.23.4-linux-x64"
    export PATH="$NODE_HOME/bin:$PWD/tools/npm-global/bin:$PATH"

Reinstall frontend dependencies from the committed lockfile and rebuild:

    pnpm --ignore-workspace -C examples/server/frontend install --frozen-lockfile
    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DSD_VULKAN=ON \
      -DSD_SERVER_BUILD_FRONTEND=ON \
      -DPNPM_EXECUTABLE="$PWD/tools/npm-global/bin/pnpm"
    cmake --build build --parallel 4

These are recovery instructions, not yet a tested clean-container restore.

## 5. Verify the recovered project

Inside Stable-box:

    ./build/bin/sd-cli --list-devices
    ./build/bin/sd-server --help
    bash -n sd-start.sh
    bash -n sd-stop.sh
    sha256sum models/v1-5-pruned_Q4_K.gguf

Confirm the expected AMD Vulkan device appears. Then start the WebUI manually:

    ./sd-start.sh

From the host, check:

    curl -sS -o /dev/null -w 'HTTP status: %{http_code}\n' \
      http://127.0.0.1:1234/

Expected HTTP status: 200.

Stop the WebUI when finished:

    ./sd-stop.sh

## 6. Safety boundaries

- Do not enable automatic startup or automatic restart.
- Do not expose the WebUI on 0.0.0.0 or change firewall rules for this recovery.
- Keep using the existing SSH tunnel for Windows browser access.
- Do not modify pihole-box, Waydroid, or SSH configuration as part of
  Stable Diffusion recovery.
- Do not delete the original project or backup until a restored copy
  has been verified.

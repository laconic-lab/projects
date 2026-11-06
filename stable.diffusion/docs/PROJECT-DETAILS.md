# Stable Diffusion — Project Details & Verified Baseline

> **Document type:** Project reference  
> **Evidence date:** 2026-10-25  
> **Scope:** Recorded configuration and historical test results; not a live audit.

## Purpose

This document records the known project configuration for local Stable Diffusion image generation on the Steam Deck OLED. Values below describe the state observed and documented on the evidence date. They must not be treated as confirmation of current state.

## At a glance

| Item | Recorded value |
|---|---|
| Host | Steam Deck OLED / SteamOS, x86_64 |
| Runtime | Distrobox: `Stable-box` |
| Container image | `docker.io/library/ubuntu:24.04` |
| Observed container OS | Ubuntu 24.04.5 LTS |
| Project directory | `/home/deck/StableDiffusionProject` |
| Engine | `leejet/stable-diffusion.cpp` |
| Source revision | `0886f11b6b8b4d1f6259e0f1337cae554284c37a` |
| Build system | CMake + Ninja |
| Build type | Release |
| Vulkan build | `SD_VULKAN=ON` |
| Web frontend | `SD_SERVER_BUILD_FRONTEND=ON` |
| Local Node.js | v22.23.4 |
| Local pnpm | 10.15.1 |
| Build directory | `build/` |
| Executables | `build/bin/sd-cli`, `build/bin/sd-server` |
| WebUI | `127.0.0.1:1234` |
| Lifecycle | Manual startup; no WebUI boot service documented |

## Architecture

```text
Steam Deck OLED / SteamOS host
  └─ Distrobox: Stable-box (Ubuntu 24.04)
      └─ /home/deck/StableDiffusionProject
          ├─ stable-diffusion.cpp source + submodules
          ├─ build/bin/sd-cli
          ├─ build/bin/sd-server
          ├─ models/v1-5-pruned_Q4_K.gguf
          └─ sd-start.sh / sd-stop.sh
                    │
                    ▼
            AMD GPU through Vulkan
                    │
                    ▼
          WebUI bound to 127.0.0.1:1234
                    │
                    ▼
       Authorized client via SSH tunnel
```

The diagram represents the documented design, not proof that each component is running now.

## Source and submodule revisions

| Component | Recorded revision |
|---|---|
| Main repository | `0886f11b6b8b4d1f6259e0f1337cae554284c37a` |
| `examples/server/frontend` | `34e5ad6edcaf827b7fe1e9ffa55ee86cd2fc43d2` |
| `ggml` | `a5915eb0e47adef21c3f25b889a008925ea838c2` |
| `thirdparty/libwebm` | `5bf12267eea773a32fcf4949de52b0add158a8d5` |
| `thirdparty/libwebp` | `0c9546f7efc61eac7f79ae115c3f99c91c21c443` |

## Model reference

| Property | Recorded value |
|---|---|
| File | `models/v1-5-pruned_Q4_K.gguf` |
| Size | 3,174,685,280 bytes |
| SHA-256 | `79c3026aecf43af544fbd7ef3419a8d695eff292effab45f92ac3d9259e24198` |

The checksum is a historical reference. Recalculate it against the actual model file before relying on it for integrity verification.

## GPU and backend

- Vulkan device recorded as **AMD Custom GPU 0932 (RADV VANGOGH)**.
- Known-working backend setting: `diffusion=vulkan0,te=cpu,vae=vulkan0`.
- Text-to-image and image-to-image generation were both recorded as successful.
- Vulkan VAE was recorded as substantially faster than CPU VAE.
- Nonfatal `conv2d` / `conv3d` direct-auto probe warnings were observed.

## WebUI and remote access

| Property | Documented value |
|---|---|
| Bind address | `127.0.0.1` |
| Port | `1234` |
| Local URL | `http://127.0.0.1:1234/` |
| Recorded HTTP result | HTTP 200 after a SteamOS reboot |
| Remote browser access | SSH tunnel from an authorized client |
| Direct LAN publication | Not intended |
| Automatic startup | Not configured in the documented baseline |

**Security boundary:** retain the loopback bind. Do not expose the WebUI on `0.0.0.0` or change firewall rules to bypass the SSH tunnel.

## Operations

Commands below are contextual references, not instructions to run as part of a documentation conversion.

| Action | Command | Environment |
|---|---|---|
| Enter container | `distrobox enter Stable-box` | SteamOS host |
| Stop container | `distrobox stop Stable-box` | SteamOS host |
| Start WebUI | `./sd-start.sh` | Inside Stable-box, project directory |
| Stop WebUI | `./sd-stop.sh` | Inside Stable-box, project directory |

## Known non-blocking issue

Container entry was recorded to print:

```text
bash: /home/linuxbrew/.linuxbrew/bin/brew: No such file or directory
```

This warning did not prevent the documented build, generation, or WebUI startup. Do not alter unrelated environment configuration solely to suppress it.

## SteamOS reboot evidence and limitations

- The project, model, scripts, and executable were recorded as persisting through a tested SteamOS reboot.
- Manual WebUI startup worked after reboot and returned HTTP 200.
- This does **not** establish recovery from a destructive SteamOS update, container loss, storage failure, or a clean-container rebuild.

## Evidence and related documents

- [Safe Update Guide](./SAFE-UPDATE-GUIDE.md)
- [Recovery & Restore Guide](./RECOVERY-AND-RESTORE.md)
- [Build & Backup Manifest](./BUILD-AND-BACKUP-MANIFEST.md)
- [Archived original documents](./archive/originals/)

---

*Historical project reference. Verify live state before troubleshooting or changing the system.*

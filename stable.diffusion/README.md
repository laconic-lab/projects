# Stable Diffusion — Local Image Generation

This project documents local image generation with **stable-diffusion.cpp** on the Steam Deck OLED, using the Deck's AMD GPU through Vulkan. The documented application and build dependencies live in a dedicated Distrobox environment rather than being installed as ordinary SteamOS host packages.

> **Documentation status:** This is a reformatted record of the existing project documentation. The content describes the previously recorded setup and tests; it is not a new Steam Deck audit or a claim about current live state.

## Documentation

| Document | Purpose |
|---|---|
| [Project Details & Verified Baseline](./docs/PROJECT-DETAILS.md) | Recorded host/container configuration, build, model, GPU, WebUI and access model |
| [Safe Update & Rebuild Guide](./docs/SAFE-UPDATE-GUIDE.md) | Manual update procedure that preserves the known-good binaries until tests pass |
| [Recovery & Restore Guide](./docs/RECOVERY-AND-RESTORE.md) | Backup verification, separate-directory restore, container recovery and verification |
| [Build & Backup Manifest](./docs/BUILD-AND-BACKUP-MANIFEST.md) | Historical source/submodule revisions, model checksum and selected file sizes |
| [Documentation index](./docs/README.md) | Scope, document map and archive policy |
| [Archived original documents](./docs/archive/originals/) | Original source files retained for reference |

## Architecture at a glance

```text
Steam Deck / SteamOS host
        |
Distrobox: Stable-box (Ubuntu 24.04)
        |
stable-diffusion.cpp
        |
AMD GPU / Vulkan
        |
sd-server — loopback WebUI :1234
        |
SSH tunnel from an authorized LAN client
```

The documented WebUI binds to `127.0.0.1:1234`. Remote access is intended to use an SSH tunnel; the WebUI is not intended to be published directly to the LAN.

## Operating model

- Start the Distrobox and WebUI manually.
- No WebUI boot service is configured in the documented baseline.
- The project uses a Vulkan-enabled build and the AMD RADV VANGOGH device.
- Text-to-image and image-to-image generation were documented as successful in the recorded environment.
- Keep model files, build outputs and project data distinct from disposable container layers.
- Do not change unrelated host or container environment settings merely to silence a non-blocking warning.
- Diagnose before modifying, and back up before approved updates.

## Status and evidence

The project details record a tested build revision, model checksum, GPU backend and WebUI configuration as of 2026-10-25. These are historical observations, not a live health check. Verify the current build, model files, GPU backend and listener before troubleshooting or updating.

---

*Project documentation index — Steam Deck Lab.*

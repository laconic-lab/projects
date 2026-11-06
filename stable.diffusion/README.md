# Stable Diffusion — Local Image Generation

This project runs **stable-diffusion.cpp** on the Steam Deck OLED, using the Deck's AMD GPU through Vulkan. The application and build dependencies live in a dedicated Distrobox environment rather than being installed as ordinary SteamOS host packages.

## Documentation

- [Project details and verified configuration](./docs/project-details.txt)
- [Recovery notes](./docs/RECOVERY.md)
- [Update instructions](./docs/Howto-update-Stable.txt)
- [Checksums and build manifest](./docs/)

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

## Status and evidence

The project details record a tested build revision, model checksum, GPU backend and WebUI configuration as of 2026-10-25. These are historical observations, not a live health check. Verify the current build, model files, GPU backend and listener before troubleshooting or updating.

## Safety rules

Diagnose before modifying. Preserve models and working build artifacts. Back up before approved updates. Do not expose the WebUI directly to the LAN or introduce automatic startup without an explicit architectural decision.

---
*Project documentation index — Steam Deck Lab.*

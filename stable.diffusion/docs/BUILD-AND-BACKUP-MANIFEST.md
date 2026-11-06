# Stable Diffusion — Build & Backup Manifest

> **Document type:** Historical integrity reference  
> **Manifest timestamp:** 2026-10-25 08:10:55 +01:00  
> **Project directory:** `/home/deck/StableDiffusionProject`

## Purpose

This manifest records the source revision, submodule revisions, model checksum, and selected file sizes observed when the project backup manifest was created. It is not a live inventory.

## Main source revision

| Component | Value |
|---|---|
| Repository | `leejet/stable-diffusion.cpp` |
| Revision | `0886f11b6b8b4d1f6259e0f1337cae554284c37a` |

## Submodule revisions

| Path | Revision | Recorded reference |
|---|---|---|
| `examples/server/frontend` | `34e5ad6edcaf827b7fe1e9ffa55ee86cd2fc43d2` | `heads/master` |
| `ggml` | `a5915eb0e47adef21c3f25b889a008925ea838c2` | `remotes/origin/sd.cpp` |
| `thirdparty/libwebm` | `5bf12267eea773a32fcf4949de52b0add158a8d5` | `libwebm-1.0.0.32-6-g5bf1226` |
| `thirdparty/libwebp` | `0c9546f7efc61eac7f79ae115c3f99c91c21c443` | `v1.6.0-158-g0c9546f7` |

## Model integrity reference

| Property | Recorded value |
|---|---|
| Path | `models/v1-5-pruned_Q4_K.gguf` |
| Size | 3,174,685,280 bytes |
| SHA-256 | `79c3026aecf43af544fbd7ef3419a8d695eff292effab45f92ac3d9259e24198` |

Verify the checksum against the actual file before relying on the model's integrity.

## Selected file sizes

| File | Recorded size (bytes) |
|---|---:|
| `build/bin/sd-server` | 78,333,176 |
| `build/bin/sd-cli` | 77,045,320 |
| `models/v1-5-pruned_Q4_K.gguf` | 3,174,685,280 |

## Related documents

- [Project Details & Verified Baseline](./PROJECT-DETAILS.md)
- [Safe Update & Rebuild Guide](./SAFE-UPDATE-GUIDE.md)
- [Recovery & Restore Guide](./RECOVERY-AND-RESTORE.md)
- [Archived original documents](./archive/originals/)

---

*Historical evidence only. Current files and revisions may differ.*

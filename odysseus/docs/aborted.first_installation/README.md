# Odysseus v1 — Archived First Installation

**Project:** Odysseus  
**Generation:** v1 — first installation  
**Status:** Retired; original Distrobox removed  
**Installation outcome:** Successful  
**Retirement reason:** Local Agent authority and host-isolation risk  
**Documentation:** Historical record, reorganized into Markdown  
**Last corrected:** 2026-11-06

> **Important — corrected project history:** The first installation succeeded. The original deployment was retired because the local autonomous Agent had access to powerful tools while its Distrobox execution environment did not provide an adequate security boundary from the Steam Deck host. This was a local Agent/runtime security decision. Cloud AI API integration and provider-credential handling were investigated separately and were not the primary reason for retiring v1.

This directory documents the first Odysseus deployment as historical engineering work. It is not an installation guide, recovery guide or authorization to recreate the former environment.

## Historical document set

| Document | Purpose |
|---|---|
| [Installation and Retirement](./ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md) | Successful installation, former runtime, local Agent security concerns and retirement decision |
| [Provider Investigation](./ODYSSEUS-V1-PROVIDER-INVESTIGATION.md) | Separate cloud-provider architecture and credential-handling investigation |
| [Groq Integration Attempt](./ODYSSEUS-V1-GROQ-INTEGRATION-ATTEMPT.md) | Groq preparation, credential setup, observed permission issues and unfinished work |

## Original source preservation

The original conversation exports are retained byte-for-byte under `archive/originals/`. The Markdown documents above are curated technical records derived from those exports and related project discussions.

The originals may contain outdated paths, commands, partial outputs, corrections and contradictory intermediate states. Treat them as historical evidence, not current instructions.

## Project lineage

```text
Odysseus v1 — first installation
        |
        | Installation completed and application operated
        v
Local Agent capabilities and execution authority reviewed
        |
        | Host isolation and Agent authority judged inadequate
        v
Decision to retire the original deployment
        |
        v
Original Distrobox removed
        |
        v
Odysseus v2 — separate security-first successor
        |
        v
Independent architecture and security audit
```

The provider/API-key investigation was a distinct workstream running during the v1 period. It identified credential-storage and request-path concerns, but it is not the causal explanation for the v1 retirement.

## Historical-use restrictions

- Do not recreate the former Distrobox or its container configuration from these documents.
- Do not restore old databases, virtual environments, caches, environment files or credentials.
- Do not reuse old startup scripts or service definitions without a new review.
- Do not treat historical provider plans as implemented features.
- Do not interpret historical test results as evidence about the current v2 environment.
- Keep v2 audit conclusions and decisions in the v2 documentation tree.

These documents distinguish user-confirmed history, findings recorded during the original review, proposed designs and unfinished work. Where the source does not establish a final result, the Markdown record says so rather than filling gaps with assumptions.

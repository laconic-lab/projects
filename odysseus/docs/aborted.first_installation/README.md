# Odysseus v1 — Archived First Installation

**Project:** Odysseus  
**Generation:** v1 — first installation  
**Status:** Retired; original Distrobox removed  
**Documentation:** Historical record, reorganized into Markdown  
**Last reorganized:** 2026-11-06

> **Important:** The first installation was successful. It was not abandoned because installation failed. Security issues became apparent during later Cloud AI API integration work. The original Distrobox deployment was subsequently removed, and a separate Odysseus v2 project was initiated. The v2 project is undergoing its own audit.

This directory documents the first Odysseus deployment as historical engineering work. It is not an installation guide, recovery guide or authorization to recreate the former environment.

## Historical document set

| Document | Purpose |
|---|---|
| [Installation and Retirement](./ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md) | Installation outcome, former architecture, lifecycle and retirement context |
| [Provider Investigation](./ODYSSEUS-V1-PROVIDER-INVESTIGATION.md) | Provider architecture, discovery findings, credential model and security constraints |
| [Groq Integration Attempt](./ODYSSEUS-V1-GROQ-INTEGRATION-ATTEMPT.md) | Groq preparation, credential setup, observed permission issues and unfinished work |

## Original source preservation

The original conversation exports are retained byte-for-byte under `archive/originals/`. The Markdown documents above are curated technical records derived from those exports and the related provider architecture reference.

The originals may contain outdated paths, commands, partial outputs, corrections and contradictory intermediate states. Treat them as historical evidence, not current instructions.

## Project lineage

```text
Odysseus v1 — first installation
        |
        | Installation completed successfully
        v
Cloud AI API integration work
        |
        | Security issues identified
        v
Original Distrobox deployment removed
        |
        v
Odysseus v1 deployment retired
        |
        v
Odysseus v2 — separate successor project
        |
        v
Current phase: independent security audit
```

## Historical-use restrictions

- Do not recreate the former Distrobox or its container configuration from these documents.
- Do not restore old databases, virtual environments, caches, environment files or credentials.
- Do not reuse old startup scripts or service definitions without a new review.
- Do not treat historical provider plans as implemented features.
- Do not interpret historical test results as evidence about the current v2 environment.
- Keep v2 audit conclusions and decisions in the v2 documentation tree.

These documents distinguish user-confirmed history, facts recorded in the exports, proposed designs and unfinished work. Where the source does not establish a final result, the Markdown record says so rather than filling gaps with assumptions.

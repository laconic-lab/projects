# Odysseus — AI Application and Provider Architecture

Odysseus has two distinct project generations.

> **Important:** Odysseus v1 was successfully installed, then retired after security issues emerged during Cloud AI API integration. Its original Distrobox was removed. Odysseus v2 is a separate successor project and is currently in its own audit phase. Do not reconstruct v1 from its historical records.

## Project status

| Generation | Status | Documentation |
|---|---|---|
| v1 — first installation | Retired; original Distrobox removed | [Archived v1 records](./docs/aborted.first_installation/README.md) |
| v2 — successor project | Security audit in progress | [Second installation and audit records](./docs/second.installation/) |

## Documentation

- [Provider integration architecture](./docs/ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md) — historical architecture reference; check status statements against the current v2 audit.
- [Python virtual environment reference](./docs/ODYSSEUS_PYTHON_VENV.readme)
- [Deck lifecycle tools](./decktools/)
- [v1 archive index](./docs/aborted.first_installation/README.md)
- [v1 installation and retirement](./docs/aborted.first_installation/ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md)
- [v1 provider investigation](./docs/aborted.first_installation/ODYSSEUS-V1-PROVIDER-INVESTIGATION.md)
- [v1 Groq integration attempt](./docs/aborted.first_installation/ODYSSEUS-V1-GROQ-INTEGRATION-ATTEMPT.md)

The original v1 conversation exports are preserved under `docs/aborted.first_installation/archive/originals/`.

## Architectural direction

The historical provider architecture explored a shared integration model for Groq, Cloudflare, OpenAI, Gemini, Mistral, Cerebras and OpenRouter. Its key concerns included manual provider selection, no automatic fallback or paid usage, centralized credential resolution, secret-safe session handling, preservation of existing local/OAuth behavior, and separation of model discovery from authentication.

These are recorded design goals, not a declaration that the integrations are implemented or approved for v2.

## Security and lifecycle

Odysseus v2 must establish its own verified security boundaries. Do not restore v1 environment files, databases, caches, virtual environments, credentials, container definitions or lifecycle scripts. Distinguish verified state from historical observations, proposals and untested assumptions. Diagnose before modifying and do not make host-level changes without explicit approval.

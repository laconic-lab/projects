# Odysseus — AI Application and Provider Architecture

Odysseus has two distinct project generations.

> **Project history:** Odysseus v1 installed and ran successfully. It was later retired because the local autonomous Agent's authority and execution environment presented unacceptable host-security risks. The original Distrobox was removed. Cloud AI provider integration and credential handling were a separate investigation, not the reason for retiring v1. Odysseus v2 is a separate successor project undergoing its own security audit.

## Project status

| Generation | Status | Documentation |
|---|---|---|
| v1 — first installation | Retired; original Distrobox removed | [Archived v1 records](./docs/aborted.first_installation/README.md) |
| v2 — successor project | Security audit in progress | [Second installation and audit records](./docs/second.installation/) |

## Documentation

- [Provider integration architecture](./docs/ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md) — historical provider design reference; verify all status statements against current v2 evidence.
- [Python virtual environment reference](./docs/ODYSSEUS_PYTHON_VENV.readme)
- [Deck lifecycle tools](./decktools/)
- [v1 archive index](./docs/aborted.first_installation/README.md)
- [v1 installation and retirement](./docs/aborted.first_installation/ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md)
- [v1 provider investigation](./docs/aborted.first_installation/ODYSSEUS-V1-PROVIDER-INVESTIGATION.md)
- [v1 Groq integration attempt](./docs/aborted.first_installation/ODYSSEUS-V1-GROQ-INTEGRATION-ATTEMPT.md)

The original v1 conversation exports are preserved under `docs/aborted.first_installation/archive/originals/`.

## Architectural direction

The historical provider work explored a shared integration model for Groq, Cloudflare, OpenAI, Gemini, Mistral, Cerebras and OpenRouter. Its concerns included manual provider selection, no automatic fallback or paid usage, centralized credential resolution, secret-safe session handling, preservation of existing local/OAuth behavior, and separation of model discovery from authentication.

These are historical design goals, not a declaration that the integrations were completed or approved for v2.

## Security and lifecycle

The v1 retirement was driven by the local Agent's effective authority and insufficient isolation from the Steam Deck host. The provider/API-key workstream raised additional credential-handling questions, but it must not be conflated with the primary retirement decision.

Odysseus v2 must establish its own verified security boundaries. Do not restore v1 environment files, databases, caches, virtual environments, credentials, container definitions or lifecycle scripts. Distinguish verified state from historical observations, proposals and untested assumptions. Diagnose before modifying and do not make host-level changes without explicit approval.

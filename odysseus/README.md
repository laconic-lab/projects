# Odysseus — AI Application and Provider Architecture

Odysseus is an AI application project on the Steam Deck, with work focused on a secure multi-provider architecture. The repository's provider architecture document records a substantial discovery phase and the intended design for integrating multiple cloud AI providers without replacing existing application pathways.

**Important:** the architecture document explicitly records implementation as **not started** at the time it was written. Do not interpret proposed integrations as implemented features or assume that a runtime/service is currently active.

## Documentation

- [Provider integration architecture](./docs/ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md)
- [Python virtual environment reference](./docs/ODYSSEUS_PYTHON_VENV.readme)
- [Deck lifecycle tools](./decktools/)

Historical discovery and rebuild records are retained under [the documentation tree](./docs/). Treat dated and aborted installation material as history, not as current operating instructions.

## Architectural direction

The documented design aims to extend the application's existing provider and endpoint-resolution architecture rather than build parallel integrations. Planned providers include Groq, Cloudflare, OpenAI, Gemini, Mistral, Cerebras and OpenRouter.

Key design constraints include:

- Manual provider selection; no automatic provider switching.
- No automatic consumption of paid API allowance.
- Centralized credential resolution and secrets kept outside the repository.
- No raw provider credentials in persisted session headers, logs or chat.
- Preserve existing local providers, OAuth and custom endpoint behavior.
- Keep model discovery, authentication and provider availability as distinct states.

## Security and lifecycle

Odysseus is a separate project environment; commands must use its own documented runtime and Python interpreter, not the SteamOS host Python by assumption. The lifecycle scripts in `decktools/` are project-specific helpers: inspect their current contents and status checks before execution.

The security-first direction is least privilege, no unnecessary host mounts or privileged runtime, and manual lifecycle management. Do not restore old environment files, databases, caches, virtual environments or credentials from historical installation snapshots without a current audit and explicit approval.

## Status and evidence

This README is an index, not a declaration that the proposed architecture is implemented. Read the architecture document and current project evidence before making changes. Clearly distinguish historical findings, accepted design decisions, implementation work and pending validation.

---
*Project documentation index — Steam Deck Lab.*

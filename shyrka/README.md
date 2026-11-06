# Shyrka — Local AI Agent

Shyrka is a locally hosted AI agent and browser dashboard on the Steam Deck. Its intended model-inference path is local, using the configured Ollama/Granite model endpoint. The project combines an agent workflow, a deliberately limited tool set, a conversation archive and a manually managed dashboard.

## Documentation

- [Current agent manifest](./docs/SHYRKA-AGENT-MANIFEST.txt)
- [Release notes](./docs/SHYRKA_RELEASE_NOTES.txt)
- [Python virtual environment reference](./docs/PYTHON_VENV.readme)
- [Project versions](./docs/PROJECT_VERSIONS.txt)
- [Startup references and Python reliability protocol](./docs/SHYRKA%20%E2%80%94%20STARTUP%20REFERENCES%20%26%20PYTHON%20RELIABILITY%20PROTOCOL.txt)

## Architecture at a glance

```text
Steam Deck / SteamOS host
        |
   Distrobox: localai-box
        |
   Shyrka project + Python virtual environment
        |
   LangGraph agent / approved tools
        |
   Local Ollama model endpoint
        |
   Browser dashboard and SQLite conversation archive
```

The manifest describes the project environment as Ubuntu 24.04 in Distrobox, with project dependencies isolated in its own virtual environment. The dashboard has been documented at `http://192.168.1.161:8765/`; confirm the current binding and access policy before connecting from a client.

## Operating model

- Manual startup; no boot auto-start is intended.
- Local model inference is the default.
- Agent tools are restricted to the documented allowlist; do not add shell execution or unapproved mutation tools.
- Do not expose the dashboard publicly.
- Backups include a checksum manifest and a consistent SQLite archive snapshot.
- Conversation transcripts are preserved, but hidden LangGraph state is not restored by the documented recovery procedure.
- Optional cloud text-to-speech is a separate, explicit user action; it does not change the local-first inference policy.

## Status and evidence

The manifest contains dated configuration and validation notes. Some test outcomes are recorded as reported rather than independently reverified during later documentation work. Treat the manifest as the project handoff, not proof that the dashboard or model is currently running.

## Safety rules

Diagnose before modifying. Preserve the project and recovery directories. Back up before significant changes. Do not enable autostart, broaden agent capabilities, expose the dashboard publicly, or place API keys in the repository without explicit authorization.

---
*Project documentation index — Steam Deck Lab.*

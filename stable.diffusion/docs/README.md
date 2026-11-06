# Stable Diffusion — Documentation Index

## Purpose

This directory contains the Markdown-formatted documentation for the Stable Diffusion project. The conversion standardizes headings, tables, code blocks, diagrams, navigation and document naming to match the documentation style used by the SSH, Deck, Pi-hole and Shyrka projects.

The conversion is editorial and structural. Existing configuration values, revision identifiers, model checksum, historical test results, operational boundaries and caveats are retained as historical records. No Steam Deck audit was performed for this task.

## Document map

| Document | Role |
|---|---|
| [Project Details & Verified Baseline](./PROJECT-DETAILS.md) | Historical configuration reference and architecture |
| [Safe Update & Rebuild Guide](./SAFE-UPDATE-GUIDE.md) | Controlled, manual source update and rebuild |
| [Recovery & Restore Guide](./RECOVERY-AND-RESTORE.md) | Backup validation and project/container recovery |
| [Build & Backup Manifest](./BUILD-AND-BACKUP-MANIFEST.md) | Source, submodule and model integrity references |
| [Original documents archive](./archive/originals/) | Preserved source versions before reformatting |

## Reading and operating rules

- Treat recorded versions, hashes, hardware detection and test results as historical evidence, not live state.
- Read the project details before troubleshooting or following an update/recovery procedure.
- Identify whether a command belongs on the SteamOS host or inside `Stable-box`.
- Preserve the model, outputs, working binaries and backups.
- Stop when a procedure reports an error; do not skip ahead to replacement or destructive recovery.
- Keep the WebUI bound to loopback and use the documented SSH tunnel for remote access.
- Do not add boot autostart, automatic restart, direct LAN publication or unrelated host changes without an explicit architectural decision.

## Archive policy

The files in `archive/originals/` are retained as source-of-record copies of the original documents. The formatted Markdown documents are the current documentation entry points. The archive is not a place for routine edits; update the active Markdown document and preserve source history.

## Historical baseline

The project details and manifest are dated 2026-10-25. This documentation pass did not verify the live Steam Deck, Distrobox, model, build, network listener or generation behavior.

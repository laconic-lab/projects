# Steam Deck Platform — Shared Standards & Tools

Shared documentation and maintenance resources for the Steam Deck OLED running SteamOS.

This directory is the **platform-level reference** for the Steam Deck host. It is not an application project and does not define the runtime or lifecycle of every workload in the repository. Project-specific architecture and operating procedures remain in each project's own directory.

## Scope

The `deck/` directory groups resources that apply across multiple Steam Deck projects:

| Area | Responsibility |
|---|---|
| Shared engineering guidance | Common host, security, lifecycle, persistence and change-management principles |
| Documentation standard | Consistent structure, status language, evidence and safe publication practices |
| Python runtime standard | Shared interpreter, virtual-environment, dependency and verification conventions |
| Maintenance tools | Host-oriented scripts and supporting operational material |

## Shared standards

- [Engineering & Security Baseline](./docs/ENGINEERING-AND-SECURITY-BASELINE.md) — cross-project engineering, security, execution boundaries, network exposure, credentials, lifecycle and change management.
- [Project Documentation Standard](./docs/PROJECT-DOCUMENTATION-STANDARD.md) — documentation roles, Markdown conventions, evidence, publication safety and AI-assisted documentation workflow.
- [Python Runtime & Virtual Environment Standard](./docs/PYTHON-VIRTUAL-ENVIRONMENT-STANDARD.md) — reusable Python interpreter, per-project `.venv`, dependency-management, verification and recovery guidance for current and future Deck projects.

Read these standards when starting work that affects the Steam Deck platform or more than one project. They establish shared defaults; they do not replace project-specific instructions. A project's own Python reference remains authoritative for its verified interpreter, runtime path and dependencies.

## Maintenance resources

- [Scripts](./scripts/) — Steam Deck host maintenance scripts.

Inspect a script and its assumptions before running it. Confirm whether it targets the SteamOS host or a project environment. Follow any script-specific usage and recovery instructions. Do not assume that a script is safe to run unattended or automatically at boot.

## Platform operating principles

1. **Diagnose first.** Begin with targeted, read-only inspection and establish the current state.
2. **Keep the host lean.** Prefer project-specific environments for application dependencies; make host-level changes only when justified.
3. **Respect execution boundaries.** Distinguish SteamOS host operations from Distrobox, Podman and remote-client operations.
4. **Use least privilege.** Avoid unnecessary privileges, capabilities, mounts, devices, sockets and network exposure.
5. **Protect persistent data.** Identify what must survive container or environment replacement and preserve it before approved changes.
6. **Keep lifecycle deliberate.** Manual operation is the default unless a project explicitly documents a service-managed lifecycle.
7. **Require approval for protected changes.** Do not perform destructive operations or modify host security, firewall, service, package or persistence settings without explicit authorization.
8. **Document evidence honestly.** Separate verified live state from historical observations, reports, proposals and pending work.
9. **Protect credentials.** Never commit passwords, API keys, tokens, private keys, secret-bearing environment files or unredacted diagnostic output.

Private LAN addresses are not secrets by default and may be retained when they help explain a real configuration. Use placeholders in reusable examples and avoid publishing unnecessary sensitive network details.

## Where to go next

- For the overall lab architecture and project index, start with the [repository README](../README.md).
- For a specific workload, use that project's own README and architecture documentation.
- For cross-project host or security decisions, consult the shared standards above.

---

*Platform documentation index — laconic-lab / projects.*

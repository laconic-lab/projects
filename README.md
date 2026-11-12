# Steam Deck Lab — Local Projects, Infrastructure & Engineering Notes

A living technical index for the **Steam Deck OLED running SteamOS** and the projects developed around it. This repository records project architecture, operational procedures, security decisions, audits, recovery guidance and supporting scripts.

The Steam Deck is the **host and infrastructure platform**. Linux and Windows machines on the same local network are primarily **client workstations** used to administer, develop, display and interact with workloads running on the Deck.

> **Core idea:** keep SteamOS as stable and minimally modified as practical; place application dependencies in dedicated Distrobox and/or Podman environments wherever the workload permits; expose only the network access a project actually needs.

This is an evolving lab, not a single product, a universal deployment recipe or a promise that every listed project is currently running.

---

## At a glance

| Layer | Role |
|---|---|
| Host | Steam Deck OLED, SteamOS, host user `deck` |
| Container tooling | Distrobox and rootless Podman, selected per project |
| Workloads | Infrastructure services, local AI, GPU applications, experiments and feasibility research |
| LAN clients | Linux Mint and Windows PCs |
| Remote access | SSH/SFTP, SSH tunnels, and project-specific browser interfaces |
| Operating model | Diagnosis first, deliberate changes, manual lifecycle by default, backups before significant changes |

The Deck provides the hardware, host operating system, network attachment, storage and container runtime. Client PCs do not normally host or duplicate the Deck's workloads: they connect to selected interfaces when a project supports remote access.

## Architecture and responsibilities

```text
                   LOCAL NETWORK (LAN)
          +-----------------------------------+
          |                                   |
   Linux Mint workstation              Windows workstation
   - terminal / SSH                    - PowerShell / SSH
   - SFTP / file access                 - SFTP / file access
   - browser / dashboard                - browser / dashboard
   - development tools                  - development tools
          |                                   |
          +-----------------+-----------------+
                            |
                Project-specific access
             SSH / SFTP / SSH tunnel / LAN UI
                            |
                 +----------------------+
                 |   STEAM DECK OLED    |
                 |       SteamOS        |
                 |                      |
                 | HOST / INFRASTRUCTURE|
                 | - hardware and GPU   |
                 | - network and SSH   |
                 | - storage and files |
                 | - firewall           |
                 | - Podman / Distrobox |
                 +----------+-----------+
                            |
             +--------------+----------------+
             |                               |
       Distrobox environments          Podman containers
       project userspaces              application runtimes
       and dependencies                 and services
             |                               |
       +-----+-----------+            +------+------+
       |                 |            |             |
   AI / development   GPU apps     LAN services   other workloads
   environments       and tools    when required  as designed
             |                               |
             +---------------+---------------+
                             |
              Project-specific data, models,
              configuration, logs and backups
```

The diagram is conceptual. It does **not** mean every component runs simultaneously, that every project uses both technologies, or that every project is a LAN service.

### Host, Distrobox and Podman are different layers

- **SteamOS host:** owns the physical hardware, kernel, host networking, user accounts, SSH, firewall, storage and container lifecycle.
- **Distrobox:** provides a convenient project-specific Linux userspace for tools, runtimes and dependencies. It integrates with the host by design; it is **not automatically a strong security boundary**.
- **Podman:** manages containers. A Podman workload may be launched and managed independently of a Distrobox, even when a Distrobox is used for project tooling or data organisation.
- **Project data:** persistent configuration, models, databases and backups must have explicit locations and recovery procedures. Container layers should not be mistaken for durable backups.

Isolation is a property of the actual runtime configuration—not simply the presence of a container. UID/GID mappings, user namespaces, mounts, capabilities, sockets, devices, network mode and privileges all matter. Each project must document its own boundary and exceptions.

## How LAN clients relate to the Deck

Linux Mint and Windows are remote workstations, not automatically part of the Deck's application runtime.

Typical client roles include:

- **Administration:** SSH for host and project maintenance, and SFTP for file inspection or transfer.
- **Remote application access:** browser dashboards or web interfaces where a project deliberately provides them.
- **Secure forwarding:** SSH tunnels for services that should remain bound to loopback on the Deck instead of being published directly to the LAN.
- **Development and review:** editing, terminal work, documentation and Git operations from a client PC.

Access is project-specific. A client should not assume that a service is listening on the Deck's LAN address just because the application exists. Prefer loopback plus an SSH tunnel when direct LAN publication is unnecessary. Do not broaden firewall rules or publish a port merely to make remote access convenient.

## Project index

The repository contains projects at different maturity levels. A project may be operational, manually launched, under development, an audit, or historical reference material. Consult its documentation before relying on it.

| Project | Purpose | Runtime / access model |
|---|---|---|
| [SSH](./SSH/) | Host OpenSSH administration and secure LAN access from client workstations | Existing SteamOS host service; key-based authentication; client access and forwarding are documented separately |
| [Pi-hole](./pi-hole/) | DNS filtering and LAN network service | Rootless Podman service with persistent host data; DNS and administration access are deliberately published and controlled |
| [Shyrka](./shyrka/) | Local AI agent and browser dashboard using a local model endpoint | Dedicated Distrobox-based environment; local-first and manually managed; dashboard access is project-specific |
| [Stable Diffusion](./stable.diffusion/) | Local image generation using stable-diffusion.cpp and the Deck AMD GPU through Vulkan | Dedicated Distrobox; WebUI binds to loopback; remote access uses an SSH tunnel, not direct LAN publication |
| [Odysseus](./odysseus/) | AI application and multi-provider integration work | Dedicated project environment; consult the architecture and implementation-status documents before assuming a feature is implemented or a service is running |
| [Waydroid](./waydroid/) | Feasibility research for Android workloads on the Deck with remote Linux/Windows clients | Investigation/audit; not a completed or approved native SteamOS installation |
| [Windows](./windows/) | Manually managed Windows VM feasibility and installation journey on the Steam Deck | Planning/preflight; no VM created |

### Direct documentation

**Shared Steam Deck standards**
- [Engineering & Security Baseline](./deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md)
- [Project Documentation Standard](./deck/docs/PROJECT-DOCUMENTATION-STANDARD.md)
- [Python Runtime & Virtual Environment Standard](./deck/docs/PYTHON-VIRTUAL-ENVIRONMENT-STANDARD.md)
- [Deck maintenance scripts](./deck/scripts/)

**SSH — Steam Deck LAN administration**
- [Project overview and audited baseline](./SSH/README.md)
- [Architecture and operations](./SSH/docs/SSH%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Installation and client setup](./SSH/docs/SSH%20on%20SteamOS%20%E2%80%94%20Installation%20%26%20Client%20Setup.md)
- [Security](./SSH/docs/SSH%20on%20SteamOS%20%E2%80%94%20Security.md)
- [Backup and recovery](./SSH/docs/SSH%20on%20SteamOS%20%E2%80%94%20Backup%20and%20Recovery.md)
- [Troubleshooting](./SSH/docs/SSH%20on%20SteamOS%20%E2%80%94%20Troubleshooting.md)

**Pi-hole**
- [Architecture and operations](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Installation guide](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Installation%20Guide.md)
- [Security](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Security.md)
- [Backup and recovery](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Backup%20and%20Recovery.md)
- [Troubleshooting](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Troubleshooting.md)

**Shyrka**
- [Documentation directory](./shyrka/docs/)
- [Agent manifest](./shyrka/docs/AGENT-MANIFEST.md)
- [Release notes](./shyrka/docs/RELEASE-NOTES.md)
- [Shyrka Python environment reference](./shyrka/docs/PYTHON-ENVIRONMENT.md)

**Stable Diffusion**
- [Documentation index](./stable.diffusion/docs/README.md)
- [Project details and verified configuration](./stable.diffusion/docs/PROJECT-DETAILS.md)
- [Recovery and restore guide](./stable.diffusion/docs/RECOVERY-AND-RESTORE.md)
- [Safe update and rebuild guide](./stable.diffusion/docs/SAFE-UPDATE-GUIDE.md)
- [Build and backup manifest](./stable.diffusion/docs/BUILD-AND-BACKUP-MANIFEST.md)
- [Archived original documents](./stable.diffusion/docs/archive/originals/)

**Odysseus**
- [Documentation directory](./odysseus/docs/)
- [Provider integration architecture](./odysseus/docs/ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md)
- [Deck lifecycle tools](./odysseus/decktools/)
- [Shared Deck Python Runtime & Virtual Environment Standard](./deck/docs/PYTHON-VIRTUAL-ENVIRONMENT-STANDARD.md)

**Waydroid**
- [Consolidated SSH feasibility audit](./waydroid/1.audit/1.0_Waydroid-SSH-Consolidated-Audit.md)
- [Audit source material](./waydroid/1.audit/)

## Engineering and security philosophy

These are the default working principles for existing and future projects:

1. **Understand before acting.** Start with read-only inspection. Establish the real host, container, process, filesystem and network state before proposing changes.
2. **Keep SteamOS lean.** Prefer project-specific environments for application dependencies. Host-level changes require a demonstrated need and a clear recovery path.
3. **Use least privilege.** Avoid privileged containers, unnecessary capabilities, broad host mounts, host networking and access to sensitive host sockets.
4. **Do not overstate isolation.** Inspect UID/GID mappings, namespaces, mounts, capabilities, devices, sockets and network exposure. Distrobox convenience is not equivalent to a security sandbox.
5. **Expose only what is required.** Use loopback and SSH tunnels where appropriate. Publish LAN ports only for a documented project requirement and control them at the host firewall.
6. **Keep lifecycle intentional.** Manual startup is the default. Do not introduce boot autostart, unattended restarts, scheduled jobs or background services without an explicit project-specific decision.
7. **Protect persistent data.** Separate application state from disposable container layers. Back up before significant changes and verify that recovery procedures are usable.
8. **Protect credentials.** Never commit passwords, API keys, tokens, private keys, secret environment files or unredacted diagnostic output. A file outside a project directory is not necessarily inaccessible to a process sharing the host UID.
9. **Preserve working systems.** Do not delete, recreate, reset, reinstall or replace a functioning container, virtual environment, database or configuration as a first troubleshooting step.
10. **Make changes incrementally.** Explain the purpose and scope of a change, preserve a backup where appropriate, modify only the necessary target and verify the result.
11. **Separate facts from plans.** Label information as verified, documented, proposed, pending or deprecated. Historical observations do not prove current runtime state.
12. **Document the actual architecture.** Do not force every project into one deployment pattern. Record the specific runtime, data paths, network exposure, lifecycle and recovery approach that the project really uses.

These principles describe the intended engineering approach. They are not a claim that every historical project configuration is already fully hardened or currently operational.

## Guidance for ChatGPT and other AI assistants

This repository is also intended to be a **technical handoff and context source** for future AI-assisted work. An assistant helping with this lab should:

1. Read this README first, then read the relevant project's architecture/overview and applicable shared standards before recommending commands or edits.
2. Identify whether each command runs on the **SteamOS host**, inside a named **Distrobox**, inside a **Podman container**, or on a **LAN client** (Linux Mint or Windows). Never blur these environments.
3. Treat the Steam Deck as the host/infrastructure platform and the client PCs as remote workstations unless a project document explicitly says otherwise.
4. Never assume all applications are continuously running, all Distroboxes must remain running, or all projects expose a LAN port. Confirm the project's documented lifecycle and access model.
5. Treat documentation as a starting point, not proof of live state. Check current versions, paths, process state, mounts, permissions and network bindings when relevant.
6. Prefer read-only audits and targeted diagnostics before proposing modifications. Do not repeat completed investigations without first checking the existing audit and evidence.
7. Do not perform destructive actions or make security-sensitive host changes without explicit approval. This includes deleting/recreating environments, changing firewall/network policy, changing persistent data, enabling autostart, or broadening privileges.
8. Never request, print, infer, or commit secrets. Avoid exposing credentials, private keys, tokens, session data or sensitive logs in chat or Git.
9. Preserve project-specific decisions and protected assets. A shared standard provides a baseline; it does not authorize an assistant to rewrite a project's architecture.
10. When evidence is incomplete, say what is known, what is only documented, what remains unverified and what read-only check would resolve the uncertainty.

**Recommended starting instruction for a new AI session:**

> Read this repository's README and the relevant project documentation in full before advising. Follow the Global Engineering & Security Standard and the project's own instructions. First establish the execution environment and current state using read-only checks. Do not repeat completed audits, modify files, restart services, install packages, change host configuration or perform destructive actions without explaining the need and obtaining approval. Clearly distinguish verified facts, documented history, proposals and pending work.

## Repository layout

```text
.
├── SSH/               # SteamOS host SSH administration and client-access documentation
├── deck/              # Shared host standards, documentation and maintenance scripts
├── odysseus/          # Odysseus documentation and Deck lifecycle tools
├── pi-hole/           # Pi-hole documentation and recovery material
├── shyrka/            # Shyrka agent documentation and supporting material
├── stable.diffusion/  # Stable Diffusion documentation and project material
├── waydroid/          # Android-in-container feasibility research and scripts
├── windows/           # Windows VM feasibility, installation and journey documentation
└── tmp/               # Temporary diagnostic and working material
```

The `tmp/` directory is working material, not an authoritative documentation area. Prefer project-specific documentation directories and current manifests for supported procedures.

## How to use this repository

- Start here for the overall lab model and project index.
- Read the relevant project's architecture document before running its scripts or changing its configuration.
- Read the shared standard when starting a new project or making host/container/security decisions.
- Follow the project's own lifecycle, backup, recovery and troubleshooting procedures.
- Inspect scripts before execution; paths and assumptions may be project-specific.
- Re-check live state when correctness depends on what is currently running.

This repository is a technical record of a real, evolving setup. It favours reproducible procedures, explicit trade-offs, careful maintenance and project-specific architecture over one-size-fits-all automation.

---

*Maintained by [laconic-lab](https://github.com/laconic-lab).*

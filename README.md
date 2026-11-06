# Steam Deck Lab — Containerised Projects for the Local Network

A collection of self-hosted, locally managed projects built around a **Steam Deck OLED running SteamOS**. The Deck acts as a small home-lab host; Linux and Windows PCs on the same LAN are used as client workstations.

The projects explore how far a compact, low-power device can go when it is used to host useful services and application workloads through **Distrobox and rootless Podman**, while keeping the SteamOS host as clean and stable as practical.

> **Design principle:** keep applications and their dependencies in dedicated project environments; keep host-level changes small, deliberate and documented; expose only the network services that a project actually needs.

---

## At a glance

- **Host:** Steam Deck OLED / SteamOS
- **Container tooling:** Distrobox and Podman
- **Primary use:** self-hosted services, local AI, GPU workloads, and remote access from LAN PCs
- **Clients:** Linux Mint and Windows
- **Networking:** service-specific LAN bindings or SSH tunnels; not every project is directly exposed to the LAN
- **Operating style:** manual lifecycle by default, read-only diagnosis before changes, backups before significant modifications

This repository is the documentation, scripts and project working area for the lab. It is not a single application or a one-command deployment.

## Architecture

```text
                 LOCAL NETWORK (LAN)
             +---------------------------+
             |                           |
       Linux Mint PC                Windows PC
       client tools                 client tools
             |                           |
             +-------------+-------------+
                           |
                    LAN / SSH access
                           |
                 +-------------------+
                 |  Steam Deck OLED  |
                 |     SteamOS       |
                 |   host platform   |
                 +-------------------+
                           |
              +------------+------------+
              |                         |
         Distrobox                    Podman
      project userspaces          containers/services
              |                         |
       +------+------+          +-------+-------+
       |      |      |          |               |
    Shyrka  Stable  Odysseus   Pi-hole       supporting
             Diffusion                         services
       |      |      |          |
       +------+------|----------+
                     |
          Project-specific data,
          models, configuration,
          backups and documentation
```

The diagram is conceptual, not a claim that every component runs simultaneously or that every project uses both Distrobox and Podman. Some workloads are launched manually; some services are published to the LAN; others are deliberately reachable only through an SSH tunnel.

### Important distinction: Distrobox and Podman

Distrobox provides a convenient, container-based Linux userspace that integrates with the host. It is excellent for separating distributions, runtimes and dependencies, but **a Distrobox is not automatically a strong security boundary**: host integration, user-namespace mappings and shared mounts matter.

Podman manages the containers and services. A Podman container may run independently of the Distrobox used to prepare or organise its project. Pi-hole is an example: its service lifecycle is managed by rootless Podman on the SteamOS host; the associated Distrobox is not required to stay running.

Each project therefore documents its actual runtime rather than assuming that all containers behave the same way.

---

## Projects

| Project | Purpose | Access / operating model |
|---|---|---|
| [Pi-hole](./pi-hole/) | Network-wide DNS filtering and administration | LAN DNS service; administration interface is published on dedicated ports and controlled by host firewall policy |
| [Shyrka](./shyrka/) | Local AI agent and browser dashboard, built around LangGraph and a local model endpoint | Manual startup; intended for controlled LAN use, not public exposure |
| [Stable Diffusion](./stable.diffusion/) | Local image generation using `stable-diffusion.cpp` and the Deck's AMD GPU through Vulkan | Web UI binds to loopback; remote PC access uses an SSH tunnel rather than direct LAN publication |
| [Odysseus](./odysseus/) | AI application and multi-provider integration work | Dedicated project environment; security and provider architecture are documented separately |
| [Waydroid](./waydroid/) | Investigation of Android-in-container feasibility with remote Linux/Windows clients | Feasibility audit only; not a completed or approved installation |

Project state changes over time. The descriptions above explain each project's purpose and intended access model; they are not a live service monitor. Consult the project documentation and current runtime checks before relying on a service.

### Project documentation

**Pi-hole**
- [Architecture and operations](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Installation guide](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Installation%20Guide.md)
- [Security](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Security.md)
- [Backup and recovery](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Backup%20and%20Recovery.md)
- [Troubleshooting](./pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Troubleshooting.md)

**Shyrka**
- [Project documentation](./shyrka/docs/)
- [Agent manifest](./shyrka/docs/SHYRKA-AGENT-MANIFEST.txt)
- [Release notes](./shyrka/docs/SHYRKA_RELEASE_NOTES.txt)
- [Python environment reference](./shyrka/docs/PYTHON_VENV.readme)

**Stable Diffusion**
- [Project details and verified configuration](./stable.diffusion/docs/project-details.txt)
- [Recovery notes](./stable.diffusion/docs/RECOVERY.md)
- [Update instructions](./stable.diffusion/docs/Howto-update-Stable.txt)

**Odysseus**
- [Project documentation](./odysseus/docs/)
- [Provider integration architecture](./odysseus/docs/ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md)
- [Deck lifecycle tools](./odysseus/decktools/)

**Waydroid**
- [Feasibility audit](./waydroid/1.audit/1.0_Waydroid-SSH-Consolidated-Audit.md)
- [Audit source material](./waydroid/1.audit/)

**Shared Steam Deck standards**
- [Global Engineering & Security Standard](./deck/docs/GLOBAL%20ENGINEERING%20%26%20SECURITY%20STANDARD.readme)
- [Project Documentation Protocol](./deck/docs/PROJECT_DOCUMENTATION_PROTOCOL.txt)
- [Deck maintenance scripts](./deck/scripts/)

---

## Engineering and security principles

The lab follows a cautious, evidence-led approach:

1. **Diagnose before modifying.** Start with read-only inspection and establish the actual state before proposing a fix.
2. **Keep the host lean.** Prefer project-specific Distroboxes and containers for application dependencies instead of installing everything into SteamOS.
3. **Use least privilege.** Avoid privileged containers, unnecessary capabilities, broad host mounts and host networking. Add permissions only where a demonstrated requirement exists.
4. **Treat integration as a security decision.** Distrobox convenience does not guarantee isolation. Review user mappings, mounts, capabilities, sockets and network exposure.
5. **Expose only what is needed.** Bind services to the appropriate interface, restrict access with firewall rules, and prefer SSH tunnels when direct LAN exposure is unnecessary.
6. **Keep lifecycle intentional.** Manual startup is the default. Do not add boot autostart, unattended restarts or background services without a project-specific reason and explicit decision.
7. **Protect persistent data.** Separate application data from disposable container layers. Back up before significant changes and verify recovery procedures.
8. **Keep credentials out of Git.** Never commit API keys, passwords, tokens, private keys, secret environment files or sensitive diagnostic output.
9. **Verify and document.** Distinguish verified facts from historical observations, proposals and unresolved work. Re-check versions and runtime state rather than assuming old notes are current.
10. **Avoid destructive shortcuts.** Do not delete, recreate, reset or reinstall a working container as a first troubleshooting step.

These are engineering intentions, not a claim that every historical project configuration is already fully hardened. Each project must be assessed against its own current implementation and documentation.

## Repository layout

```text
.
├── deck/              # Shared host standards, documentation and maintenance scripts
├── odysseus/          # Odysseus project documentation and Deck lifecycle tools
├── pi-hole/           # Pi-hole documentation and recovery scripts
├── shyrka/            # Shyrka agent documentation and supporting material
├── stable.diffusion/  # Stable Diffusion project documentation
├── waydroid/          # Android-in-container feasibility research and scripts
└── tmp/               # Temporary diagnostic and working material
```

The `tmp/` directory is working material, not an authoritative project documentation area. Prefer the project-specific documentation directories when looking for supported procedures or current design decisions.

## How to use this repository

- Start with this README to understand the lab and locate a project.
- Read that project's architecture or overview document before running scripts or changing its configuration.
- Check whether a document describes a verified current state, a historical observation, a proposal or an outstanding task.
- Follow the project's own backup, recovery and lifecycle instructions.
- Treat scripts as project-specific tools; inspect them before execution and do not assume they are interchangeable.

This repository is primarily a technical record of a real, evolving setup. It favours reproducible procedures, explicit trade-offs and careful maintenance over one-size-fits-all automation.

---

*Maintained by [laconic-lab](https://github.com/laconic-lab).*

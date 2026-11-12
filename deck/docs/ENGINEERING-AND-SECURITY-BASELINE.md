# Engineering & Security Baseline

Shared engineering principles for the `laconic-lab/projects` repository.

| Document control | Value |
|---|---|
| Scope | Cross-project engineering, security and AI-assisted work |
| Status | Current baseline |
| Maintainer | [laconic-lab](https://github.com/laconic-lab) |
| Last updated | 2026-11-06 |

> **Purpose:** provide shared safety requirements and practical engineering defaults for the lab. This is guidance for making sound decisions, not a universal architecture or a command to use a particular tool. Each project owns its architecture, implementation, operational procedures and evidence.

---

## Contents

- [1. How this repository works](#1-how-this-repository-works)
- [2. Shared safety requirements and engineering defaults](#2-shared-safety-requirements-and-engineering-defaults)
- [3. Execution environments and trust boundaries](#3-execution-environments-and-trust-boundaries)
- [4. Network and remote access](#4-network-and-remote-access)
- [5. Credentials and sensitive information](#5-credentials-and-sensitive-information)
- [6. AI agents, automation and external services](#6-ai-agents-automation-and-external-services)
- [7. Lifecycle and persistence](#7-lifecycle-and-persistence)
- [8. Change management](#8-change-management)
- [9. Evidence and status](#9-evidence-and-status)
- [10. Documentation structure](#10-documentation-structure)
- [11. Working with AI assistants](#11-working-with-ai-assistants)
- [12. Exceptions and review](#12-exceptions-and-review)

---

## 1. How this repository works

This repository is a collection of projects with different purposes and maturity levels: infrastructure services, local applications, development environments, security work and feasibility investigations.

There is no single deployment pattern that fits all projects. A project may use the SteamOS host directly, Distrobox, rootless Podman, a virtual machine, a remote system, a combination of these, or another justified arrangement. Select based on actual requirements—not on a preference being treated as a rule.

### Shared platform model

```text
Linux / Windows client workstations
             |
      SSH / SFTP / tunnel / approved UI
             |
       Steam Deck OLED — SteamOS
       host · hardware · network
             |
      +------+----------------+
      |                       |
   Distrobox               Podman
   project tools           application runtime
      |                       |
      +-----------+-----------+
                  |
          Project workloads
                  |
       persistent data / recovery
```

This is a conceptual overview, not a mandatory architecture. Project documentation is authoritative for the actual implementation.

### Core principles

- Keep the SteamOS host stable; make host changes only when their benefits justify the maintenance and recovery cost.
- Use project-specific environments when they provide a real benefit, not merely to satisfy a convention.
- Consider host-native, containerized, virtualized and hybrid designs on equal technical terms.
- Treat client workstations as clients unless a project explicitly assigns them another role.
- Use the narrowest practical access path.
- Keep project data, runtime, lifecycle and recovery requirements explicit.
- Prefer simple, understandable controls over unnecessary complexity.

## 2. Shared safety requirements and engineering defaults

The safeguards around secrets, authorization, destructive actions and sensitive system changes are firm requirements. The broader engineering principles below are defaults to guide decisions; adapt them when the project's technical requirements justify another approach.

| Principle | Expected approach |
|---|---|
| Diagnose first | Establish the actual state before recommending or applying a change. |
| Least privilege | Use the minimum identity, permissions and capabilities required. |
| Verify isolation | Inspect effective mounts, namespaces, identities, capabilities, devices and sockets. |
| Minimise exposure | Publish only required services, interfaces and ports. |
| Protect data | Identify persistent state and preserve it before significant approved changes. |
| Protect secrets | Keep credentials out of Git, chat, logs, screenshots and ordinary diagnostic output. |
| Preserve working systems | Do not reinstall, reset, recreate or delete as a first troubleshooting step. |
| Change deliberately | Make the smallest justified change and verify its result. |
| Be evidence-based | Separate verified facts from documentation, reports, assumptions and proposals. |
| Document reality | Describe what exists, not what an example or proposed design says should exist. |

These principles describe the normal approach, not a compliance checklist or proof that every historical project is fully compliant or currently operational. A justified alternative is acceptable when its trade-offs, boundaries and operational consequences are understood and documented.

## 3. Execution environments and trust boundaries

Always identify where an operation runs:

| Environment | Responsibility |
|---|---|
| SteamOS host | Hardware, kernel, host accounts, networking, firewall, storage and runtime management. |
| Distrobox | Project-specific userspace, tools and dependencies. |
| Podman container | Application runtime and its explicitly configured resources. |
| Linux / Windows client | Remote administration, development, file access and user interfaces. |

Do not confuse a Distrobox with a Podman application container. They may have different identities, lifecycles, mounts and responsibilities.

### Container isolation

Distrobox and rootless containers improve organisation and can reduce exposure, but they are not automatically strong security sandboxes.

Where isolation matters, inspect the effective configuration:

- UID/GID mappings, process identity and supplementary groups.
- Bind mounts, mount permissions and accessible host paths.
- Linux capabilities, privileged mode and security profiles.
- Network, PID, IPC and user namespaces.
- Host sockets, devices and runtime interfaces.
- Environment variables, credentials and inherited permissions.

A process sharing the host user's identity or broad host-home access may reach data outside its apparent project directory. File permissions or a container label alone do not prove isolation.

Do not add isolation mechanisms without a clear security purpose. Do not describe convenience separation as a security guarantee.

## 4. Network and remote access

**Default: private by design, narrow by necessity.**

1. Bind services to loopback when LAN access is unnecessary.
2. Prefer SSH tunnels when they avoid publishing an application interface.
3. Publish LAN services only for a documented project requirement.
4. Restrict administrative interfaces to intended clients or trusted networks.
5. Inspect listeners, routing and firewall policy before changing connectivity.
6. Assess IPv4 and IPv6 exposure separately.
7. Avoid broad firewall allowances to solve a narrow connectivity problem.
8. Do not expose administrative interfaces to the public internet by default.

A configured service is not necessarily running or reachable. Verify the live listener, firewall and intended client path when that distinction matters.

## 5. Credentials and sensitive information

- Never commit passwords, API keys, access tokens, private keys, cookies, session secrets or secret-bearing environment files.
- Never print credential values in routine diagnostics.
- Redact sensitive values before sharing logs, screenshots or command output.
- Keep credentials outside source control and separate by project or provider where practical.
- Document credential ownership, permitted use, access and rotation or revocation procedures.
- Treat backups containing secrets as sensitive assets.

### Applications, tools and AI agents

An application needing a credential does not imply that every user interface, Agent, plugin or tool should receive the raw secret.

Prefer narrow authenticated operations and credential brokers where justified. Evaluate the real process identity, mounts, environment, logs, error handling and available tools. A hidden file, environment variable or application-level allowlist is not an operating-system security boundary.

If a security boundary has not been verified, record it as unresolved.

## 6. AI agents, automation and external services

Start with the minimum capability required for the task.

| Capability | Default policy |
|---|---|
| Read relevant project documentation | Allowed within task scope. |
| Inspect system state | Prefer targeted, read-only checks. |
| Edit project files | Requires task-specific authorization. |
| Arbitrary shell or code execution | Not granted by default. |
| Access credential files | Not granted by default. |
| Install packages or change runtimes | Explicit approval required. |
| Modify host, firewall or service configuration | Explicit approval required. |
| Delete, reset or recreate environments or data | Explicit approval required. |
| Send messages or perform external actions | Explicit authorization required. |
| Paid API usage or provider switching | User choice; never silently consume paid usage. |
| Startup persistence, scheduled or background tasks | Project-specific approval required. |

Application tool restrictions are useful but do not replace operating-system permissions or process isolation.

For external providers and services, document the provider, authentication path, data transmitted, cost implications, failure behaviour and user control. Do not silently upload local data, switch providers or consume paid quotas.

## 7. Lifecycle and persistence

Lifecycle is a project decision, not a universal deployment setting.

- Manual startup and shutdown are the default for application and experimental workloads.
- Persistent infrastructure services may have an explicitly documented service-managed lifecycle.
- Do not introduce boot autostart, automatic restart, scheduled jobs or background activity without a project-specific decision.
- Do not assume a stopped Distrobox means its associated Podman workload is stopped, or vice versa.
- Document what starts, what stops, what survives a restart and what must be started manually.

### Persistent data

Every project with valuable state should identify:

- Configuration, databases, models, user data and logs.
- Persistent paths and runtime mounts.
- Disposable files and container layers.
- Backup scope, exclusions and credential handling.
- Recovery procedure and integrity checks.

A successful backup command is not proof of a usable backup. Verify expected files and integrity; test restoration where practical.

Never use deletion, pruning, reset or environment recreation as a troubleshooting shortcut.

## 8. Change management

Use this workflow for meaningful system or project changes:

1. **SCOPE** — identify the project, requested outcome and boundaries.
2. **INSPECT** — read relevant documentation and perform targeted, read-only checks.
3. **ASSESS** — identify dependencies, impact, risks and rollback requirements.
4. **PROPOSE** — explain the exact change and why it is needed.
5. **AUTHORIZE** — obtain approval for protected actions.
6. **BACK UP** — preserve relevant state and verify the backup.
7. **CHANGE** — apply the smallest justified change.
8. **VERIFY** — test the intended result and relevant adjacent functions.
9. **DOCUMENT** — record the change, evidence, limitations and recovery details.

### Actions requiring explicit approval

- Destructive operations or changes to persistent application data.
- Changes to host configuration, permissions, ownership or security policy.
- Firewall, routing, port exposure or remote-access changes.
- Package installation/removal or replacement of a working runtime.
- Changes to service lifecycle, autostart or background persistence.
- Credential exposure, migration, rotation or revocation.
- Paid usage or externally visible actions.

Read-only investigation and a proposed remediation plan may be completed before approval. Approval for one change does not authorize unrelated changes.

## 9. Evidence and status

Use consistent language throughout project documentation:

| Status | Meaning |
|---|---|
| **VERIFIED** | Directly inspected or tested; include evidence and date where relevant. |
| **DOCUMENTED** | Recorded in a source document but not necessarily checked against the live system. |
| **REPORTED** | Supplied by a user, log or external source; not independently verified. |
| **PROPOSED** | Suggested design or change, not implemented. |
| **PENDING** | A test, decision or task remains outstanding. |
| **DEPRECATED** | Superseded material retained for history or recovery. |

Do not present an old audit as proof of current runtime state. Do not describe planned features as implemented.

Security findings must distinguish confirmed exposure from potential risk, untested assumptions and incomplete assessment. A configuration review is not a penetration test or security certification.

## 10. Documentation structure

Use readable Markdown (`.md`) for new human-maintained project documentation unless a project has a specific technical reason to use another format.

Prefer the clear, task-oriented style established by the SSH and Pi-hole documentation:

- Descriptive headings and concise sections.
- Tables for configuration, component roles and status.
- Diagrams where they clarify architecture or trust boundaries.
- Checklists and numbered procedures for operational tasks.
- Code blocks for commands and configuration examples.
- Relative links to authoritative project documents.

### Documentation hierarchy

1. **Repository README** — lab overview, project index and shared philosophy.
2. **This baseline** — cross-project engineering and security principles.
3. **Project README** — project purpose, maturity, architecture summary and document index.
4. **Architecture and operations** — actual runtime, data paths, access and lifecycle.
5. **Security** — relevant controls, threat boundaries, findings and unresolved risks.
6. **Installation and maintenance** — scoped, reproducible procedures.
7. **Backup and recovery** — protected data and validated restoration.
8. **Audits and historical records** — dated evidence, decisions and change history.

Not every project needs every document. Keep documentation proportional to complexity and risk. Avoid duplicating long procedures; link to the authoritative source instead.

### Documentation quality

- Put purpose, current status and important warnings near the top.
- Separate current instructions from historical notes.
- Date audits and state exactly what was inspected.
- Use accurate paths, versions and command contexts.
- Keep secrets and unnecessary personal or network details out of public documentation.
- Preserve historical evidence; do not rewrite it to imply that an old state is current.

## 11. Working with AI assistants

An assistant working in this repository should:

1. Read the repository README and the relevant project's current documentation.
2. Stay within the scope of the requested project; do not scan unrelated projects or the entire host without a reason.
3. Identify the exact execution environment before proposing commands.
4. Check existing audits and evidence before repeating investigations.
5. Prefer targeted, read-only diagnosis when live state matters.
6. Preserve established architecture, protected assets and project-specific decisions.
7. Never request, print, infer or commit secrets.
8. Explain uncertainty and distinguish evidence from assumptions.
9. Obtain approval before protected actions.
10. Verify approved changes and update only affected documentation.

### Suggested instruction for a new session

> Read the repository README, this Engineering & Security Baseline and the relevant project documentation before acting. Stay within the requested project scope. Identify the execution environment and establish the current state with targeted read-only checks first. Preserve working systems, persistent data and project-specific decisions. Do not perform destructive, privileged, persistent, security-sensitive, externally visible or cost-incurring actions without explaining the need and obtaining approval. Never expose secrets. Clearly distinguish verified facts, documented history, reports, proposals and pending work.

## 12. Exceptions and review

Project-specific requirements and verified constraints take precedence over generic examples and defaults in this baseline. A project may choose a different architecture or procedure when the choice is technically justified, its security and operational trade-offs are understood, and the relevant documentation explains the decision. This does not waive the firm safeguards for secrets, authorization or destructive and sensitive changes.

- Record exceptions in the relevant project's documentation, including scope and reason.
- Do not silently weaken a security control.
- Review this baseline when the shared platform, repository structure or operating model materially changes.
- Prefer one authoritative document over competing copies.
- Retain superseded material only when it has historical or recovery value, and label it clearly.

---

*Engineering & Security Baseline — laconic-lab / projects.*

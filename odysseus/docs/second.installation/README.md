# Odysseus — Second Rebuild Audit Track

**Project:** Odysseus  
**Documentation scope:** Second rebuild attempt  
**Current status:** Audit and feasibility assessment — installation not authorized  
**Repository:** [laconic-lab/projects](https://github.com/laconic-lab/projects)

## 1. Purpose

This directory tracks the second Odysseus rebuild effort. The parent directory name, `second.installation`, is retained as a historical identifier for the second rebuild attempt; it does **not** mean that the project is currently in an installation phase.

The work is organized into two independent audits:

- **Audit 1 — Phase 1.3:** source-level security audit of the local Odysseus Agent, its authority, execution routes and trust boundaries. Closed as a source audit only.
- **Audit 2 — Phase 1.4:** deployment feasibility and runtime security validation. Active; installation is not authorized.

## 2. Directory structure

```text
second.installation/
├── README.md
├── 1.audit/
│   └── archive/
│       ├── ODYSSEUS — Phase 1.3 Reset & Security Audit.md
│       └── original-1.3.0/
│           └── original Phase 1.3 source exports
└── 2.audit/
    ├── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT.md
    └── archive/
        └── 2026-11-06/
            ├── source-exports/
            │   └── 1.4.0–1.4.14 original TXT exports (unchanged)
            └── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT-v1.0.md
```

The numbered Phase 1.4 TXT exports are retained unchanged under the dated archive. The canonical Markdown audit is the active technical record and continuation handoff.

## 3. Audit 1 — Phase 1.3

**Status:** Closed — source-level audit only

Primary document:

[ODYSSEUS — Phase 1.3 Reset & Security Audit](./1.audit/archive/ODYSSEUS%20%E2%80%94%20Phase%201.3%20Reset%20%26%20Security%20Audit.md)

Audit 1 examined authentication and roles, Agent tool schemas and dispatch, shell/Python, filesystem access, MCP, internal APIs, integrations, credentials, browser execution, background jobs and scheduling.

It did not prove runtime isolation or authorize a deployment. Its findings must remain separate from Audit 2 runtime evidence.

## 4. Audit 2 — Phase 1.4 deployment feasibility

<badge>ACTIVE — AUDIT ONLY</badge>

Canonical document:

[ODYSSEUS — Phase 1.4 Deployment Feasibility & Security Audit](./2.audit/ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT.md)

This is the **single source of truth** for Audit 2's current status, evidence, completed tests, decisions, next gate and ChatGPT continuation instructions.

The audit determines whether the target architecture can be enforced on SteamOS before any installation decision. It includes rootless Podman identity/mount/network/cgroup validation and an explicit comparison of Podman, Distrobox, LXC, LXD, Incus, Docker/Compose and virtual-machine approaches.

### Mandatory continuity protocol

The following rules are mandatory:

1. Every completed test is recorded immediately in the canonical document, including exact executed commands, relevant output, exit status, interpretation and cleanup.
2. Every five completed tests trigger a documentation consistency review and an unchanged versioned archive snapshot.
3. A snapshot is also required before a major architecture/security decision or material restructuring.
4. Every new ChatGPT conversation begins from the canonical audit and this README, never from assumed conversation memory.
5. Completed tests must not be repeated merely because a new chat has started.
6. A repeated test requires a documented changed condition or a previously untested behavior.
7. The parent README must be updated when the canonical handoff, archive structure or audit status changes.

The detailed rules and templates are in §0 and §13–§18 of the canonical audit.

## 5. Current recorded position

- The default rootless Podman UID mapping maps container root to host `deck` UID 1000; this is not the preferred isolation boundary.
- `--userns=auto` failed under the recorded subordinate-ID allocation.
- `--userns=nomap` produced a subordinate host mapping in the tested invocation.
- A private host directory bind-mount test passed for the exact tested configuration.
- `--network=none` blocked the tested destinations.
- The default Podman bridge allowed tested router/LAN and public Internet connectivity and is unsuitable as the Agent/Inspector boundary.
- A dedicated Podman internal network is the next proposed test; it has not been created.
- cgroup v2/systemd delegation exists at host level, but writable nested delegation in the disposable container was not demonstrated.
- Seccomp is enabled; AppArmor and SELinux are disabled.
- No Odysseus or LXC installation has been performed.

These are scoped findings, not a final security certification. Consult the canonical audit for test IDs, evidence limits and the next approved step.

## 6. Naming and phase policy

The sequence is intentionally named:

- `1.audit`
- `2.audit`

Do not use `2.audit2`. Do not place Audit 2 inside `1.audit/phase 2`; the two audits have distinct scopes and independent conclusions.

The parent name `second.installation` remains a historical grouping identifier only.

## 7. Documentation and safety boundary

This documentation update is a repository-only operation.

- No Steam Deck host or container state was changed.
- No packages or images were installed or downloaded.
- No Odysseus/LXC container or network was created.
- No protected project was stopped, started or modified.
- No provider credential contents were accessed.
- Original Phase 1.4 TXT exports were moved without content changes.
- The canonical Markdown document consolidates recorded evidence; it does not authorize installation.

**Installation requires a separate explicit decision after the audit gates are closed.**

# Odysseus — Second Rebuild Audit Track

**Project:** Odysseus  
**Documentation scope:** Second rebuild attempt  
**Current status:** Audit and feasibility assessment — installation not authorized  
**Repository:** [laconic-lab/projects](https://github.com/laconic-lab/projects)

## 1. Purpose

This directory tracks the second Odysseus rebuild effort. The parent directory name, `second.installation`, is retained as a historical identifier for the second rebuild attempt; it does **not** mean that the project is currently in an installation phase.

The work is organized by audit sequence:

- **Audit 1 — Phase 1.3:** source-level security audit of the local Odysseus Agent, its authority, execution routes and trust boundaries. Closed as a source audit only.
- **Audit 2 — formerly Phase 1.4:** deployment feasibility and architecture validation. This remains an audit. It must establish whether the intended security boundaries can be enforced on SteamOS before any installation decision.

## 2. Directory structure

```text
second.installation/
├── README.md
├── 1.audit/
│   └── archive/
│       ├── ODYSSEUS — Phase 1.3 Reset & Security Audit.md
│       └── original-1.3.0/
│           ├── 1.3.0 ... 1.3.24 source exports (.txt)
│           └── _1.3_ Odysseus - Reset - Audit Phase.txt
└── 2.audit/
    └── 1.4.0 ... 1.4.14 source exports (.txt)
```

The original TXT files are retained unchanged in the Audit 1 archive. The consolidated Markdown record is the readable technical entry point; it preserves the technical findings, source references, limitations and requirements while removing conversational filler and repeated chat artifacts.

Audit 2 files have only been relocated from `2.installation/` to `2.audit/`. Their contents have not been edited, reformatted or consolidated.

## 3. Audit 1 — Phase 1.3

**Status:** Closed — source-level audit only

Primary document:

[ODYSSEUS — Security-First Rebuild: Phase 1.3 Reset & Security Audit](./1.audit/archive/ODYSSEUS%20%E2%80%94%20Phase%201.3%20Reset%20%26%20Security%20Audit.md)

Original source exports:

[`1.audit/archive/original-1.3.0/`](./1.audit/archive/original-1.3.0/)

Audit 1 examined the local Agent's authority and execution surfaces, including authentication, token scope, native tools, Bash/Python, filesystem access, MCP, internal and external API bridges, credentials, browser execution, background jobs and scheduling.

The earlier Distrobox deployment was removed because of local runtime security problems: privileged/root execution, host networking, broad host mounts, AppArmor unconfined and SELinux labels disabled. This is distinct from Cloud AI API implementation security; the two subjects must not be conflated.

Audit 1 did not perform runtime validation, install Odysseus, modify upstream source or authorize a deployment.

## 4. Audit 2 — deployment feasibility

**Status:** Active audit / feasibility assessment

Current directory:

[`2.audit/`](./2.audit/)

The documents were previously stored under `2.installation/`. The folder was renamed because the work remains in audit and feasibility validation, not installation.

The current audit work must address, in its own records:

1. Reconcile the upstream repository and commit identity before selecting a deployment source.
2. Validate rootless Podman user-namespace and UID/GID isolation on the actual SteamOS environment.
3. Establish the feasibility of filesystem, mount, network and process boundaries.
4. Determine whether upstream execution routes and background mechanisms can be restricted effectively.
5. Decide whether the proposed architecture can proceed, requires revision, or must be stopped.

The latest source export in this folder describes Gate A.2 — UID/GID isolation feasibility. Its stated test limits and acceptance criteria belong exclusively to Audit 2.

**Important:** Audit 2 findings must not be retroactively inserted into Audit 1. Audit 1's conclusion remains a source-level assessment of the audited upstream code; Audit 2 has its own evidence and conclusion.

## 5. Naming and phase policy

The sequence is intentionally named:

- `1.audit`
- `2.audit`

Do not use `2.audit2`, which is redundant and ambiguous. Do not place Audit 2 inside `1.audit/phase 2`; the two audits have distinct scopes and independent conclusions.

The parent name `second.installation` is retained only to preserve the historical grouping of the second rebuild attempt. The README and child directory names define the actual current phase.

## 6. Change boundary for this documentation update

This reorganization is documentation-only.

- No Steam Deck audit was performed.
- No SteamOS, Podman, Distrobox, container, network or credential state was inspected or changed.
- Audit 1 original TXT exports were moved without modification.
- Audit 2 TXT exports were moved without modification.
- Audit 2 content was not consolidated, rewritten or otherwise edited.
- The new consolidated Markdown report is an archival technical record, not an installation guide or authorization.

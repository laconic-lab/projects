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

**ACTIVE — AUDIT ONLY**

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

The detailed rules and templates are in §0 and §13–§18 of the canonical audit. The canonical audit is now version 3.6 (2026-11-08). NET-03's named host/router/public/DNS egress probes were blocked as intended on the tested single-container internal bridge. NET-04 confirmed bidirectional peer communication on a dedicated internal bridge while both peers remained blocked from the named host/router/public/DNS probes; both listeners required SIGKILL after the 10-second SIGTERM timeout. NET-05 confirmed a host-to-container HTTP 200 path through a loopback-only published port (`127.0.0.1:18085` → container `18080/tcp`), while the same published port was refused through the host LAN address. Other host/container probes produced distinct timeout, refusal and unreachable results; see the canonical ledger for evidence limits. NET-05 cleanup independently verified the temporary container and network absent and port `18085` released; the listener required SIGKILL after the 10-second SIGTERM timeout. **NET-06 is now complete.** Its read-only Stage A preflight found active host IPv6 addressing/default routing and Netavark IPv6 option support, while the existing default Podman bridge remains IPv4-only. Host DNS stubs and a separate UDP/TCP listener on `192.168.1.161:53` were left untouched. Approved Stage B created a temporary IPv6-enabled internal Netavark bridge and restricted probe container using only the cached image. Podman assigned `10.89.0.2` and ULA IPv6 `fdba:b7cb:d144:4e86::2`; network inspection reported `internal: true`, IPv6 enabled and DNS enabled. Stage C1: both internal DNS gateways answered A/AAAA UDP/TCP queries for `example.com` with NXDOMAIN; direct public DNS endpoints were network-unreachable. Stage C2: no default IPv4 or IPv6 route in the container; public numeric TCP destinations returned `connect_ex=101`, while TCP to both internal DNS gateways succeeded. Stage D removed the exact temporary container and network; independent absence checks passed. Podman escalated to SIGKILL after the 10-second SIGTERM timeout. **Gate 5 / UID-04 is complete with a scoped FAIL.** In the disposable rootless Podman `--userns=nomap` probe, ownership repair on the host-owned mode-0700 scratch bind mount failed with EPERM; the application identity 1000:1000 then failed to write with EACCES. The exact temporary container and scratch directory were removed and independently verified absent; Podman escalated from SIGTERM to SIGKILL after 10 seconds. See canonical §11, §12 and §18 for exact results and limitations. **DR-01 design direction accepted; DR-02 first-pass source review recorded.** The named-volume/non-root design remains **PROPOSED**. The pinned source identifies `/app/data` as the primary sensitive state root, including `.app_key`, auth/vault/database/user state and uploads. Upstream Agent tools also use `DATA_DIR` as their working directory and file-tool root, so a volume is not an Agent/secret boundary. The active app logger writes to `DATA_DIR/logs/app.log`; the separate `/app/logs` mount is not used by the reviewed primary logger. `/app/.ssh` supports Cookbook remote SSH, `/app/.cache/huggingface` stores model downloads, and `/app/.local` stores executable Python CLIs/serve engines; omit these from the initial profile unless separately approved. The upstream entrypoint requires root for user/group creation and ownership repair; `setup.py` as non-root may fail creating `/app/.env` on a root-owned/read-only app tree, with the failure hidden by `|| true`. A build-time fixed identity and deployment-specific non-root entrypoint/setup path are therefore required. **SRC-01 is resolved for Phase 1.4.** The user selected `odysseus-dev/odysseus`; the exact source pin is `1c1509094963f9eb9445928d57f2856296057cf4`. SRC-02–SRC-10 have now been revalidated as source findings at that pin; continue the DR-02 design review before any build. No volume/container/runtime test or installation is authorized; any later experiment requires separate explicit approval.

## 4.1 Source-integrity gate — SRC-01 through SRC-10

The canonical audit is pinned to the user-confirmed maintained upstream: **`odysseus-dev/odysseus@1c1509094963f9eb9445928d57f2856296057cf4`** (observed `dev` head on 2026-11-08; GitHub reports the commit signature as verified). SRC-01 is resolved for Phase 1.4; the older Phase 1.3 pin remains a historical record. Read-only checks against this exact pin confirmed SRC-02–SRC-09: the active cache path differs from the Dockerfile's pre-created path; built-in MCP defaults on and can invoke `@playwright/mcp@latest`; setup failures may be swallowed; disabling built-in MCP does not remove custom MCP, shell or Cookbook routes; the entrypoint mutates identity/ownership; custom-font discovery creates a directory outside `DATA_DIR`; `DATA_DIR` and `DATABASE_URL` can diverge; and first-admin bootstrap is exposed to local-process race risk. `THREAT_MODEL.md` explicitly acknowledges no shell/filesystem sandbox. SRC-10 was revised: ChromaDB, SearXNG and ntfy are digest-pinned in the chosen Compose file, but the base image is not digest-pinned, the app image defaults to mutable `:latest`, and main Python dependencies are not hash-locked. The named-volume/non-root profile remains proposed; no build or runtime test is authorized. DR-02 continuation further requires a build-time fixed non-root UID/GID with a separately proven volume-ownership method (UID-04's tested `nomap` bind-mount sequence failed), one consistent `DATA_DIR`/`DATABASE_URL` path, and an operator-controlled first-admin bootstrap that cannot be raced by other local processes. Disabling built-in MCP is not sufficient: shell, Python, Cookbook, custom MCP and background execution must be removed or hard-disabled at both API route registration and Agent tool dispatch; application-level checks are not an OS sandbox. The deployment-specific entrypoint must fail closed without runtime user creation, ownership repair or `setup.py`; custom-font image-tree writes and implicit `npx` downloads remain disabled. These are source/design requirements only, not runtime proof. The canonical audit is v3.6; Source follow-up confirmed relative SQLite URLs normalize against the app root and identified `AuthManager.setup()` as a candidate one-shot offline bootstrap primitive; its lock is process-local, so the HTTP setup route alone is not a cross-process race boundary. The current canonical audit is v3.6. Completed runtime-test count remains 3/5, with no archive snapshot triggered by this source review. DR-02 is now consolidated into a design-only implementation checklist in §18.2: fixed non-root identity/volume ownership, one-root storage/database consistency, fail-closed startup and offline bootstrap, Agent/API execution-surface removal, network/service policy, immutable build inputs, release acceptance and rollback. Six blockers remain; next gate is targeted read-only closure review, starting with UID/volume strategy and bootstrap details. No implementation/build/runtime authorization is granted. The first bootstrap/persistence closure review found that `AuthManager.setup()` can be called without importing the database module, but auth/session JSON writes do not explicitly enforce mode 0600, corrupt existing auth state can be treated as unconfigured, and setup locking is process-local. The separate `.app_key` and `.key` files are critical backup material; database initialization/migrations run during module import, and a sensitive DB chmod failure is warning-only upstream. See audit §18.2 for the source hashes and required safeguards. The canonical audit is now v3.7: VOL-01's read-only host preflight confirmed Podman 6.0.2, the subordinate UID/GID mapping (container UID/GID 1000 maps to host 100999), and the rootless storage/volume paths. Six existing generated-name volumes were inventoried but not touched. Named-volume ownership remains unproven; the next gate is VOL-02, a read-only review of Podman volume and user-namespace capabilities. No volume/container test or installation is authorized. Completed runtime-test count remains 3/5.

## 5. Current recorded position

- The default rootless Podman UID mapping maps container root to host `deck` UID 1000; this is not the preferred isolation boundary.
- `--userns=auto` failed under the recorded subordinate-ID allocation.
- `--userns=nomap` produced a subordinate host mapping in the tested invocation.
- The pinned Phase 1.4 source candidate defaults to application PUID/PGID `1000:1000`; its root-started entrypoint attempts to chown five writable bind mounts before dropping to that identity. UID-04 tested one disposable mount under `--userns=nomap`: ownership repair failed with EPERM and the application UID/GID 1000:1000 write failed with EACCES. This is a scoped FAIL, not proof that every possible mount strategy fails.
- A private host directory bind-mount test passed for the exact tested configuration.
- `--network=none` blocked the tested destinations.
- The default Podman bridge allowed tested router/LAN and public Internet connectivity and is unsuitable as the Agent/Inspector boundary.
- NET-03 tested a single container on a temporary dedicated Podman internal bridge; the named host SSH, router DNS, public HTTPS and DNS lookup paths were blocked.
- NET-04 tested two disposable peers on a new temporary internal bridge. Peer DNS/TCP communication succeeded in both directions; both peers were blocked from the same named external probes. Inspection confirmed the internal bridge, two expected peers, no published ports and no mounts. Cleanup independently verified both containers and the network absent. Both listeners required SIGKILL after the 10-second SIGTERM timeout; see the canonical audit for the lifecycle caveat.
- NET-05 tested host-service and published-port behavior on a temporary internal network. The host received HTTP 200 through `127.0.0.1:18085` mapped to container `18080/tcp`; access through the host LAN address was refused. The host-to-container internal-IP probe timed out; container-to-gateway published-port and SSH probes were refused; container-to-host-LAN SSH was network-unreachable. Final inspection confirmed loopback-only rootlessport binding and the recorded resource limits. Cleanup independently verified the container/network absent and port `18085` released. The listener required SIGKILL after the 10-second SIGTERM timeout; see the canonical audit for evidence limits and lifecycle caveat.
- cgroup v2/systemd delegation exists at host level, but writable nested delegation in the disposable container was not demonstrated.
- Seccomp is enabled; AppArmor and SELinux are disabled.
- No Odysseus or LXC installation has been performed.

These are scoped findings, not a final security certification. NET-06 is complete: the exact temporary container and network were removed and independently verified absent; the 10-second SIGTERM timeout/SIGKILL escalation is recorded as a lifecycle caveat. UID-04 has completed Gate 5's focused runtime probe with a scoped FAIL. Consult canonical audit v3.6 for exact evidence, limitations and DR-01/DR-02: the proposed named-volume/non-root direction, sensitive `DATA_DIR` contract, Agent access limitations, and pinned-source findings. The active search cache writes under `DATA_DIR/cache/`; the Dockerfile's `services/cache/search` pre-created path appears unused. The primary app logger writes under `DATA_DIR/logs/`, so a separate `/app/logs` volume is not justified by the reviewed code. ChromaDB is an optional separate HTTP service for vector memory/RAG; if retained it needs its own volume and backup. The pinned upstream threat model explicitly acknowledges no shell/filesystem sandbox for admin Agent tools. The source also exposes a rate-limited first-run `/api/auth/setup` route while no users exist; a custom non-root profile can investigate using it instead of running upstream `setup.py`, but must remain loopback-only until the first admin is created and authentication verified. Further source tracing found that built-in MCP is enabled by default and browser MCP can install via `npx` at first startup; the initial profile must set `ODYSSEUS_DISABLE_MCP=1`. Custom-font additions write under `static/fonts/custom` outside the data volume and must be disabled or redesigned for a read-only root. A second source-integrity review added SRC-01–SRC-10: the Phase 1.3 historical installation-baseline candidate `odysseus-dev/odysseus@03d25943ee4a35f6f0535112976123a721cff5cb` remains unreconciled with the final Phase 1.3 Authority Matrix / Phase 1.4 source-review pin `odysseus-dev/odysseus-current@142b93ad86073efb24981df385423f58fe5376b1`; their Dockerfiles have different blob SHAs and materially different build instructions. **SRC-01 is now the first open dependency and blocks any build** until the user confirms the intended upstream source authority. Other findings cover stale MCP documentation and the limited scope of `ODYSSEUS_DISABLE_MCP=1` (custom MCP routes remain registered), root-dependent entrypoint ownership repair, setup.py's `.env` write failure masked by `|| true`, custom-font writes outside `DATA_DIR`, possible `DATA_DIR`/`DATABASE_URL` divergence, first-admin local-process race risk, and mutable build inputs including base/OS/runtime/service images. The named-volume/non-root architecture remains PROPOSED; no runtime experiment or installation is authorized.

## 6. Naming and phase policy

The sequence is intentionally named:

- `1.audit`
- `2.audit`

Do not use `2.audit2`. Do not place Audit 2 inside `1.audit/phase 2`; the two audits have distinct scopes and independent conclusions.

The parent name `second.installation` remains a historical grouping identifier only.

## 7. Documentation and safety boundary

This documentation update is a repository-only operation.

- No persistent Steam Deck host configuration or production container state was changed. The approved disposable UID-04 container and scratch directory were created, then removed and independently verified absent.
- No packages or images were installed or downloaded.
- No production Odysseus/LXC container or network was created.
- No protected project was stopped, started or modified.
- No provider credential contents were accessed.
- Original Phase 1.4 TXT exports were moved without content changes.
- The canonical Markdown document consolidates recorded evidence; it does not authorize installation.

**Installation requires a separate explicit decision after the audit gates are closed.**

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

The detailed rules and templates are in §0 and §13–§18 of the canonical audit. The canonical audit is now version 2.1 (2026-11-08). NET-03's named external-egress probes passed. NET-04 confirmed bidirectional peer communication on a dedicated internal bridge while both peers remained blocked from the named host/router/public/DNS probes; both listeners required SIGKILL after the 10-second SIGTERM timeout. NET-05 confirmed a host-to-container HTTP 200 path through a loopback-only published port (`127.0.0.1:18085` → container `18080/tcp`), while the same published port was refused through the host LAN address. Other host/container probes produced distinct timeout, refusal and unreachable results; see the canonical ledger for evidence limits. NET-05 cleanup independently verified the temporary container and network absent and port `18085` released; the listener required SIGKILL after the 10-second SIGTERM timeout. **NET-06 is now complete.** Its read-only Stage A preflight found active host IPv6 addressing/default routing and Netavark IPv6 option support, while the existing default Podman bridge remains IPv4-only. Host DNS stubs and a separate UDP/TCP listener on `192.168.1.161:53` were left untouched. Approved Stage B created a temporary IPv6-enabled internal Netavark bridge and restricted probe container using only the cached image. Podman assigned `10.89.0.2` and ULA IPv6 `fdba:b7cb:d144:4e86::2`; network inspection reported `internal: true`, IPv6 enabled and DNS enabled. Stage C1: both internal DNS gateways answered A/AAAA UDP/TCP queries for `example.com` with NXDOMAIN; direct public DNS endpoints were network-unreachable. Stage C2: no default IPv4 or IPv6 route in the container; public numeric TCP destinations returned `connect_ex=101`, while TCP to both internal DNS gateways succeeded. Stage D removed the exact temporary container and network; independent absence checks passed. Podman escalated to SIGKILL after the 10-second SIGTERM timeout. **Gate 5 / UID-04 is complete with a scoped FAIL.** In the disposable rootless Podman `--userns=nomap` probe, ownership repair on the host-owned mode-0700 scratch bind mount failed with EPERM; the application identity 1000:1000 then failed to write with EACCES. The exact temporary container and scratch directory were removed and independently verified absent; Podman escalated from SIGTERM to SIGKILL after 10 seconds. See canonical §11, §12 and §18 for exact results and limitations. **DR-01 design direction accepted:** investigate Podman-managed named volumes with a fixed non-root application identity first. This remains **PROPOSED**, pending read-only source review of the exact pinned application to establish required writable paths and whether startup can run without runtime ownership repair. `/app/.ssh` is excluded from the initial profile; cache/local-state mounts and persistent logs must be justified. Host-prepared bind mounts and explicit custom UID/GID mapping remain fallbacks. No volume/container/runtime test or installation is authorized; any later experiment requires separate explicit approval.

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

These are scoped findings, not a final security certification. NET-06 is complete: the exact temporary container and network were removed and independently verified absent; the 10-second SIGTERM timeout/SIGKILL escalation is recorded as a lifecycle caveat. UID-04 has completed Gate 5's focused runtime probe with a scoped FAIL. Consult canonical audit v2.1 for exact evidence, limitations and the accepted DR-01 direction: read-only source validation of the proposed named-volume/non-root storage contract.

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

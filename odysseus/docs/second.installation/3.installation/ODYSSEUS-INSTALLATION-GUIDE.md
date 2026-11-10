# Odysseus — Future Installation & Deployment Guide

> **Document type:** Future installation plan and controlled deployment record  
> **Status:** PLANNING — NOT AUTHORIZED / NOT EXECUTABLE  
> **Applies to:** Odysseus second rebuild  
> **Canonical path:** odysseus/docs/second.installation/3.installation/ODYSSEUS-INSTALLATION-GUIDE.md  
> **Last reviewed:** 2026-11-10

## 1. Purpose and phase separation

This document collects the requirements, decisions and future procedures needed for a later Odysseus installation. It is deliberately separate from the Phase 1.4 deployment-feasibility audit.

- **Audit 1 — Phase 1.3:** source-level security audit; closed as a source audit only.
- **Audit 2 — Phase 1.4:** deployment feasibility and runtime security audit; active.
- **Installation — 3.installation:** a future phase. This document is a planning record until the audit is complete and the user separately authorizes installation.

The audit remains the authoritative source for test evidence, technical findings, blockers, gate status and its conditional authorization rule. This guide must not rewrite audit results or turn proposals into verified facts.

**Current decision: INSTALLATION NOT AUTHORIZED.** No installation command in this document is currently approved for execution.

## 2. Governing documents and order of authority

Read these documents before planning or performing deployment work:

1. [Repository Engineering & Security Baseline](../../../../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) — shared engineering and security principles.
2. [Odysseus project README](../../../README.md) — project purpose and generation history.
3. [Second rebuild README](../README.md) — phase map and continuation instructions.
4. [Phase 1.4 Deployment Feasibility & Security Audit](../2.audit/ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT.md) — authoritative evidence, blockers and authorization status.
5. This guide — future installation requirements and, only after approval, the controlled deployment record.

If this guide conflicts with current audit evidence or the shared baseline, stop and reconcile the documents before proceeding. The audit does not become an installation manual; the installation guide does not become an audit ledger.

## 3. Current known decisions and constraints

| Area | Current recorded position |
|---|---|
| Target host | Steam Deck OLED / SteamOS |
| Container manager under audit | Rootless Podman |
| Candidate upstream | odysseus-dev/odysseus |
| Source pin | 1c1509094963f9eb9445928d57f2856296057cf4 (recorded Phase 1.4 pin; revalidate before any build) |
| Deployment name | odysseus-box (lowercase) |
| Durable project root | /home/deck/odysseus-box/ — project convention / proposed layout, not yet deployed |
| Installation status | NOT AUTHORIZED |
| Application container | Not created |
| Production network | Not created |
| Build | Not authorized or performed |
| Agent execution | Disabled by default in the proposed initial profile |
| Lifecycle | Manual start/stop by default; no boot autostart or automatic restart without separate approval |

These are planning constraints, not a claim that the deployment exists.

## 4. Durable host layout and SteamOS-update resilience

### 4.1 Required project root

The future deployment must keep its durable project definition and recovery material under /home/deck/odysseus-box/.

Proposed layout (not a final mount allowlist):

- home/ — dedicated container/Distrobox HOME, if required
- config/ — reviewed deployment settings; no secrets in Git
- scripts/ — reviewed start/stop/repair/backup helpers
- source/ — pinned source and build inputs, if retained on host
- binaries/ — rebuildable or restorable host-side artifacts, if needed
- data/ — persistent application state, subject to approved mount design
- logs/ — separate operational logs only if justified
- backups/ — local recovery snapshots; an independent backup is still preferred

This is a proposed layout, not a final mount allowlist. Gate 6 and the remaining audit must determine which paths are actually mounted into the application, with what identity and access mode. A directory existing under this root does not mean it should be writable or even visible inside the container.

### 4.2 SteamOS resilience requirements

SteamOS updates may replace or reset host-managed system files and packages. Therefore:

- Do not place essential Odysseus configuration, scripts, deployment definitions or recovery instructions solely in mutable SteamOS system paths.
- Treat the application container/image layer as reproducible and disposable, not the only copy of deployment knowledge or valuable data.
- Preserve exact source revision, image digests, runtime configuration, UID/GID mapping, mount allowlist, network policy and required package/tool versions.
- Keep durable configuration and recovery scripts beneath /home/deck/odysseus-box/.
- Keep valuable application state independently backed up; do not assume a container image or container export is a data backup.
- Keep a known-good build or restorable binary artifact where technically appropriate, alongside the pinned source and reproducible rebuild procedure.
- Before and after a SteamOS update, perform read-only compatibility checks first. Revalidate Podman, storage, namespaces, UID/GID maps, cgroups, mounts, networking and any host dependencies before repair or rebuild.
- If runtime binaries are damaged or incompatible, prefer a controlled rebuild/repair in a separate staging location, verify it, and only then replace the working artifact. Preserve a dated rollback copy.
- Never solve an update problem by disabling SteamOS read-only protections or making broad host modifications without a separately reviewed justification and explicit approval.

The exact repair commands, binary provenance and post-update acceptance tests remain PENDING until the audit closes and the deployment method is selected.

## 5. Distrobox deployment convention — mandatory reminder

**Project convention:** if Distrobox is used for Odysseus or another project in this repository, keep that project's deployment rooted under /home/deck/<project-name>/. For this project the name is odysseus-box.

For a Distrobox-based environment, the intended dedicated HOME candidate is:

/home/deck/odysseus-box/home

This convention is about predictable, durable project placement and recovery. It does not mean:

- mounting the entire host /home/deck into an application container;
- granting access to sibling projects, SSH keys, credentials, Podman sockets or host runtime sockets;
- assuming Distrobox --home alone creates a security sandbox;
- switching the current audited rootless-Podman architecture to Distrobox.

Distrobox deliberately integrates with the host. If it is selected for a maintenance/development environment, inspect the actual --home path, user identity, mounts, devices, sockets, namespaces and environment. If it is selected as an application runtime, that is a material architecture change and must return to audit/design review before use. The application trust boundary must remain independently enforced.

## 6. Security requirements inherited from Phase 1.4

The following are requirements for any proposed initial deployment profile. They are not yet proof of implementation.

### 6.1 Identity, mounts and host access

- Use a fixed, non-root application identity.
- Do not use the default rootless mapping that maps container root to host UID 1000 as the preferred application boundary.
- Do not assume --userns=auto works; the recorded attempts failed with the available subordinate-ID allocation.
- The tested --userns=nomap bind-mount ownership-repair sequence failed (UID-04 scoped FAIL). Do not repeat it as if it were a working solution.
- Resolve named-volume ownership and application-identity access through the remaining evidence gates.
- Do not mount the host home broadly.
- Do not mount SSH credentials, provider keys, Podman/Docker sockets, unrelated project paths or host runtime sockets.
- Keep the effective mount allowlist narrow, documented and tested.
- Do not use privileged mode, host networking, host PID/IPC namespaces or broad host mounts as shortcuts.
- Drop all unnecessary capabilities; require no-new-privileges and a read-only root filesystem where the selected application profile permits it.

### 6.2 Application state

The source review identifies /app/data as the primary sensitive application-state root. It may contain the app key, auth/vault/session data, database and user uploads. It is not an Agent sandbox.

- Keep DATA_DIR and DATABASE_URL consistent and explicitly verified.
- Back up the complete required application state consistently.
- Do not assume that a volume boundary restricts what an Agent can do within that volume.
- Do not add separate mounts for paths not justified by source tracing.
- ChromaDB, if retained, needs a separately designed state and recovery policy.

### 6.3 Agent and execution policy

The proposed initial profile is default-deny for powerful Agent capabilities:

- Shell/Bash and arbitrary Python: disabled.
- Arbitrary filesystem reads/writes/deletes: disabled.
- SSH, Podman/Docker API and host administration: disabled.
- MCP and browser automation: disabled initially.
- Email, integrations, scheduler/background jobs, arbitrary URL fetch and downloads: disabled initially.
- Provider API access: disabled until a separate broker and credential policy is reviewed and approved.
- Application/API route registration and Agent dispatch must both enforce the disabled policy; prompt instructions or UI role labels are not security boundaries.

### 6.4 Network and lifecycle

- Do not use the default rootless bridge as an Agent isolation boundary; recorded probes showed LAN/router and public HTTPS access.
- --network=none and a dedicated internal network have demonstrated specific blocked paths, but the final topology and permitted service-to-service flows remain to be designed and tested.
- No public exposure by default. Prefer loopback and an approved SSH tunnel where suitable.
- Manual lifecycle is the default. No boot autostart, scheduled job or automatic restart without separate approval.
- Document startup order, shutdown behavior, health checks and recovery.

## 6.5 Provisional mount scope from Gate 6 source review

The pinned-source review recorded in the Phase 1.4 audit (§18.8) identifies **one provisional application-container persistent mount**: a dedicated rootless Podman named volume at `/app/data`, read/write. This is a design candidate only; it has not yet passed the Gate 6 runtime probe and is not authorized for creation.

The following upstream convenience mounts are not adopted for the initial restricted profile:

- `/app/logs` — the reviewed primary application logger writes beneath `DATA_DIR/logs`.
- `/app/.ssh` — enables Cookbook remote SSH identity access.
- `/app/.cache/huggingface` — persists downloaded model cache.
- `/app/.local` — persists locally installed executable Python tools/packages.
- `/app/static/fonts/custom` — outside `DATA_DIR`; custom-font writes must be disabled or redesigned while the image root is read-only.

No host-home, project-root, source-tree, runtime-socket or Podman-socket mount is approved. The Agent workspace is a canonical child of `/app/data`; it is not a separate OS sandbox. A read-only Inspector mount is deferred because no concrete source path or Inspector service contract has been selected. ChromaDB remains a separate unresolved service/storage decision and is not included in this application-container allowlist.

The exact mount list, access modes and negative write tests remain subject to Gate 6 completion in the audit. This guide does not authorize resource creation.

## 7. Pre-installation gate — no deployment until all conditions are met

Before installation can be considered, all of the following must be true:

- [ ] Phase 1.4 audit is complete and reconciled.
- [ ] Every required runtime, source/build, security-boundary, lifecycle and recovery gate has evidence-backed GREEN/PASS status.
- [ ] No unresolved blocker, scoped failure or partial result invalidates the selected architecture.
- [ ] Gate 6 mount allowlist is complete, including exact source/destination paths, identity, access mode and test evidence.
- [ ] UID/GID mapping and persistent-volume ownership are proven for the actual application identity.
- [ ] Network topology and egress policy are explicit and tested.
- [ ] Application execution surfaces are removed or fail-closed at both registration and dispatch layers.
- [ ] Source, base image, dependencies and service images are pinned and reproducible; mutable tags are not accepted as immutable inputs.
- [ ] Backup scope, secret handling, restore procedure and rollback plan are documented.
- [ ] SteamOS update repair/rebuild procedure is documented and tested in a safe staging context.
- [ ] Project paths and dedicated HOME are finalized under /home/deck/odysseus-box/.
- [ ] The installation guide has been reviewed against the final audit and baseline.
- [ ] The user gives a separate, explicit approval for the exact installation plan.

The audit's conditional transition to INSTALLATION: AUTHORIZED is controlled only by the audit's own §18.6. This guide cannot independently change that status. Even after that status transition, actual installation requires separate explicit approval of the exact plan.

## 8. Future installation workflow — headings reserved, not yet executable

The following sequence is a planning framework. Exact commands must be added only after the audit closes and the selected architecture, image, paths, mappings and network are verified.

1. **Preflight:** inspect SteamOS/Podman versions, free space, existing resource names, current source pin and host dependencies. Read-only only.
2. **Backup:** verify the current project root and backup destination; preserve any pre-existing state.
3. **Source acquisition:** obtain the exact approved source commit and verify its identity/integrity.
4. **Build:** build from pinned inputs in a staging location; no mutable latest dependency.
5. **Deployment definition:** write reviewed configuration under /home/deck/odysseus-box/config/.
6. **Persistent storage:** create only the approved state paths/volumes and verify ownership/modes.
7. **Runtime creation:** create the restricted container with the approved identity, mounts, capabilities, namespaces, read-only root and network.
8. **First-admin bootstrap:** perform an operator-controlled, loopback-only bootstrap; close setup route and verify authentication.
9. **Acceptance:** verify effective identity, mounts, network, API policy, Agent tool policy, persistence, lifecycle and logs.
10. **Backup/restore test:** create and validate a backup; test restore to a separate location.
11. **Handover:** record exact versions/digests, commands, paths, service endpoints, start/stop procedure and recovery procedure.
12. **Authorization:** only proceed with the separate user approval for the reviewed plan.

**Do not execute this sequence from this planning document.** No command-level installation procedure has been validated or authorized.

## 9. SteamOS update and binary repair procedure — future requirement

Before any production deployment, write and test a project-specific repair runbook that answers:

- Which binaries are host-side versus image-contained?
- What exact files and versions must be preserved?
- Which source commit and dependency locks reproduce them?
- Where are the build cache and staging directory?
- How is a known-good binary verified before replacement?
- How is the prior working version restored?
- Which Podman/runtime changes require revalidation after SteamOS updates?
- How is the application state protected independently of the binary repair?
- How are SSH, Pi-hole and other protected projects excluded from repair actions?

Expected pattern: inspect → preserve → rebuild in staging → verify → approve replacement → replace narrowly → verify → retain rollback. Do not assume this pattern has been tested for Odysseus yet.

## 10. Backup and recovery requirements

Separate these asset classes:

| Asset | Treatment |
|---|---|
| Source and build manifest | Preserve exact commit, submodules, patches and dependency locks |
| Host-side binaries/tools | Preserve known-good artifacts where appropriate; retain rebuild path |
| Container image | Record immutable digest and build provenance; recreate from pinned inputs |
| Deployment configuration | Keep under project root; exclude secrets |
| Application data | Back up consistently; restore separately from runtime |
| Credentials | Keep outside Git and application/Agent mounts; define independent secure recovery |
| Logs | Retain only required operational logs; redact secrets |
| Backups | Keep outside live data directories; verify integrity and test restoration |

A container is not a backup. A build recipe is not a backup of user data. A successful archive command is not proof of a usable restore.

## 11. Installation record — to be completed only after authorization

When installation is eventually authorized and performed, record:

| Field | Record |
|---|---|
| Approval date and scope | PENDING |
| SteamOS version/kernel | PENDING |
| Podman / Netavark / OCI runtime | PENDING |
| Source repository and exact commit | PENDING |
| Build inputs and image digest | PENDING |
| Container name and ID | PENDING |
| UID/GID mapping | PENDING |
| Host path and container mount allowlist | PENDING |
| Network and published ports | PENDING |
| Capabilities / security options | PENDING |
| Persistent data location | PENDING |
| Backup verification | PENDING |
| Acceptance-test results | PENDING |
| Rollback location and procedure | PENDING |

Do not fill these fields from assumptions or historical observations. Use the actual approved installation evidence.

## 12. Change history

| Date | Change |
|---|---|
| 2026-11-09 | Created as a separate future installation planning document. Captures durable /home/deck/odysseus-box/ layout, SteamOS update resilience, Distrobox dedicated-HOME reminder, security requirements inherited from Phase 1.4, approval gates and future recovery requirements. No installation commands authorized. |


## 6.6 Gate 6 preflight checkpoint — MOUNT-02 Stage A

The read-only Stage A preflight passed on 2026-11-09. It verified rootless Podman 6.0.2, the exact cached Python image ID (linux/amd64), availability of the exact disposable container and volume names, and the current rootless UID/GID maps. No resources were created or modified. This does not validate the /app/data mount at runtime and does not authorize resource creation.

The next step is review and separate approval of the exact Stage B command to create one named volume and one stopped disposable container. Stage C execution requires a further separate approval after read-only inspection of Stage B. See the canonical audit §18.9 for the full command/output and evidence.

## 6.7 Gate 6 resource-creation checkpoint — MOUNT-02 Stage B

On 2026-11-09, the approved bounded Stage B setup created the disposable named volume `odysseus-mount02-data-20261109` and stopped restricted container `odysseus-mount02-probe-20261109` (ID `9e8747dd89a928520beef95079077ddc815003c065b43b0bee0733e020e5577c`). The container was not started and Python was not executed. The resources remain in place for read-only inspection.

MOUNT-02 Stage B2 subsequently passed read-only configuration inspection: exact container ID/image and stopped state, configured user 1000:1000, equivalent effective UID/GID mapping, read-only root, network none, no published ports, configured no-new-privileges and cap-drop-all, and the exact RW named-volume attachment at `/app/data` were confirmed. The volume reports UID/GID 1000:1000, `MountCount=0` and `NeedsCopyUp=true`. EffectiveCaps/BoundingCaps were null while stopped. Runtime mount activation, process-visible ownership, write/readback and persistence remain untested. The container and volume remain in place.

This checkpoint does not authorize installation or runtime execution. The next step is preparation and review of the exact MOUNT-02 Stage C runtime test, followed by separate explicit user approval before starting the container. Refer to canonical audit §18.9.

## 6.8 Gate 6 runtime checkpoint — MOUNT-02 Stage C (2026-11-09)

The bounded MOUNT-02 Stage C runtime probe passed its positive named-volume checks. In the exact disposable container, the /app/data volume was active; the Python process ran as UID/GID 1000:1000; marker write/readback succeeded; marker ownership was UID/GID 1000:1000; and marker content and ownership persisted across a container stop/restart.

Both five-second stop operations required Podman to escalate from SIGTERM to SIGKILL. The final state was exited / Running=false. This is a shutdown-behavior caveat for the lifecycle gate, not a failure of the positive volume checks.

The container, volume and marker file remain present. No cleanup was performed. This probe does not establish application-image compatibility, negative writes outside /app/data, an Inspector mount, backup/restore or graceful SIGTERM shutdown. Gate 6 remains open for its unresolved requirements. Runtime-test count is **2/5 since the unchanged v3.20 archive checkpoint**. Installation remains **NOT AUTHORIZED**.

See the canonical Phase 1.4 audit §18.9 for the recorded command, actual output, evidence limits and continuation handoff. This guide remains a planning document and does not authorize installation.


## 6.9 Gate 6 read-only mount inventory — MOUNT-02-RO-01 (2026-11-09)

MOUNT-02-RO-01 passed as a read-only inspection of the exact stopped probe. The recorded configuration has a read-only root, network mode `none`, configured user `1000:1000`, an empty `HostConfig.Tmpfs` object, `ShmSize=65536000`, one explicit RW named volume at `/app/data`, and no image-declared volumes. The rootfs diff listed only `A /app` and `A /app/data`.

This does not prove live `/dev/shm` mount behavior or permissions/writability of `/tmp`, `/var/tmp` or any other path. Runtime negative-write behavior remains untested. No Inspector mount is selected. The container, volume and Stage C marker remain retained. Runtime-test accounting remains **2/5 since the unchanged v3.20 archive checkpoint**. See canonical audit §18.9 for the exact command, output and limitations. Installation remains **NOT AUTHORIZED**.


## 6.10 Gate 6 live mount inspection — MOUNT-02-RO-02 (2026-11-10)

MOUNT-02-RO-02 passed as a bounded live metadata inspection. The process ran as UID/GID 1000:1000. /tmp, /var/tmp and /dev/shm are separate writable tmpfs mounts; /app is covered by the read-only fuse-overlayfs root mount; /app/data is a separate writable ext4 named volume. No writes were attempted. The exact probe was stopped and verified exited, with the previously observed five-second SIGTERM timeout and SIGKILL escalation.

For UID 1000, a negative create attempt directly in /app remains DAC-confounded because /app is mode 1755 and that identity lacks directory write permission. RO-03 subsequently established a candidate for a separate negative-write test as UID/GID 0:0 with all inspected capability sets zero; /app is owned by 0:0 and grants owner write/execute permission. The actual write-denial behavior and errno remain untested and require a separate reviewed command and explicit approval. No permission or mount changes are authorized. Acceptance-test count remains **2/5**; installation remains **NOT AUTHORIZED**. See canonical audit v3.38.


## 6.11 Gate 6 root identity and capability inspection — MOUNT-02-RO-03 (2026-11-10)

MOUNT-02-RO-03 passed as a bounded read-only runtime inspection. The exact probe's root-identity inspection process reported UID/GID/EUID/EGID 0:0, with `CapInh`, `CapPrm`, `CapEff`, `CapBnd` and `CapAmb` all zero. The `/app` directory was owned by 0:0, mode 1755, and its owner write/execute permission bits were present.

Together with RO-02's live read-only mount evidence, `/app` is a suitable candidate for a separately approved negative-write test using root identity without capabilities. The actual write-denial behavior and errno remain **NOT TESTED**. This does not make `/app` a clean target for UID 1000 because that identity lacks directory write permission.

The probe was stopped and verified exited; SIGTERM again timed out after five seconds and Podman escalated to SIGKILL. No files or resources were changed. Functional acceptance-test count remains **2/5**. See canonical audit v3.38 for the full evidence and limitations. Installation remains **NOT AUTHORIZED**.

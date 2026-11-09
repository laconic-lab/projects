# Odysseus — Second Rebuild Documentation

**Project:** Odysseus  
**Documentation scope:** Second rebuild attempt  
**Current status:** Audit and feasibility assessment — installation not authorized  
**Repository:** [laconic-lab/projects](https://github.com/laconic-lab/projects)

## 1. Purpose

This directory tracks the second Odysseus rebuild effort. The parent directory name, `second.installation`, is retained as a historical identifier for the second rebuild attempt; it does **not** mean that the project is currently in an installation phase.

The work is organized into two independent audits followed by a separate, future installation phase:

- **Audit 1 — Phase 1.3:** source-level security audit of the local Odysseus Agent, its authority, execution routes and trust boundaries. Closed as a source audit only.
- **Audit 2 — Phase 1.4:** deployment feasibility and runtime security validation. Active; installation is not authorized.
- **Installation — 3.installation:** a separate future deployment phase. Its guide records requirements and pending procedures only; it does not authorize installation.

## 2. Directory structure

```text
second.installation/
├── README.md
├── 1.audit/
│   └── archive/
│       ├── ODYSSEUS — Phase 1.3 Reset & Security Audit.md
│       └── original-1.3.0/
│           └── original Phase 1.3 source exports
├── 2.audit/
│   ├── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT.md
│   └── archive/
│       ├── 2026-11-06/
│       │   ├── source-exports/
│       │   │   └── 1.4.0–1.4.14 original TXT exports (unchanged)
│       │   └── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT-v1.0.md
│       ├── 2026-11-08/
│       │   └── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT-v3.20.md
│       └── 2026-11-09/
│           └── ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT-v3.29.md
└── 3.installation/
    └── ODYSSEUS-INSTALLATION-GUIDE.md
```

The numbered audit directories are deliberately separate from the future installation directory. Audit archives preserve historical evidence; the installation guide collects future deployment requirements and procedures. The shared governing standard is the [Deck Engineering & Security Baseline](../../../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md).

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

The detailed rules and templates are in §0 and §13–§18 of the canonical audit. The canonical audit is now version 3.30 (2026-11-09). Its v3.29 predecessor is preserved unchanged in 2.audit/archive/2026-11-09/. The audit has been reconciled against the shared Deck Engineering & Security Baseline; see audit §0.5. This documentary reconciliation does not close any technical gate. NET-03's named host/router/public/DNS egress probes were blocked as intended on the tested single-container internal bridge. NET-04 confirmed bidirectional peer communication on a dedicated internal bridge while both peers remained blocked from the named host/router/public/DNS probes; both listeners required SIGKILL after the 10-second SIGTERM timeout. NET-05 confirmed a host-to-container HTTP 200 path through a loopback-only published port (`127.0.0.1:18085` → container `18080/tcp`), while the same published port was refused through the host LAN address. Other host/container probes produced distinct timeout, refusal and unreachable results; see the canonical ledger for evidence limits. NET-05 cleanup independently verified the temporary container and network absent and port `18085` released; the listener required SIGKILL after the 10-second SIGTERM timeout. **NET-06 is now complete.** Its read-only Stage A preflight found active host IPv6 addressing/default routing and Netavark IPv6 option support, while the existing default Podman bridge remains IPv4-only. Host DNS stubs and a separate UDP/TCP listener on `192.168.1.161:53` were left untouched. Approved Stage B created a temporary IPv6-enabled internal Netavark bridge and restricted probe container using only the cached image. Podman assigned `10.89.0.2` and ULA IPv6 `fdba:b7cb:d144:4e86::2`; network inspection reported `internal: true`, IPv6 enabled and DNS enabled. Stage C1: both internal DNS gateways answered A/AAAA UDP/TCP queries for `example.com` with NXDOMAIN; direct public DNS endpoints were network-unreachable. Stage C2: no default IPv4 or IPv6 route in the container; public numeric TCP destinations returned `connect_ex=101`, while TCP to both internal DNS gateways succeeded. Stage D removed the exact temporary container and network; independent absence checks passed. Podman escalated to SIGKILL after the 10-second SIGTERM timeout. **Gate 5 / UID-04 is complete with a scoped FAIL.** In the disposable rootless Podman `--userns=nomap` probe, ownership repair on the host-owned mode-0700 scratch bind mount failed with EPERM; the application identity 1000:1000 then failed to write with EACCES. The exact temporary container and scratch directory were removed and independently verified absent; Podman escalated from SIGTERM to SIGKILL after 10 seconds. See canonical §11, §12 and §18 for exact results and limitations. **DR-01 design direction accepted; DR-02 first-pass source review recorded.** The named-volume/non-root design remains **PROPOSED**. The pinned source identifies `/app/data` as the primary sensitive state root, including `.app_key`, auth/vault/database/user state and uploads. Upstream Agent tools also use `DATA_DIR` as their working directory and file-tool root, so a volume is not an Agent/secret boundary. The active app logger writes to `DATA_DIR/logs/app.log`; the separate `/app/logs` mount is not used by the reviewed primary logger. `/app/.ssh` supports Cookbook remote SSH, `/app/.cache/huggingface` stores model downloads, and `/app/.local` stores executable Python CLIs/serve engines; omit these from the initial profile unless separately approved. The upstream entrypoint requires root for user/group creation and ownership repair; `setup.py` as non-root may fail creating `/app/.env` on a root-owned/read-only app tree, with the failure hidden by `|| true`. A build-time fixed identity and deployment-specific non-root entrypoint/setup path are therefore required. **SRC-01 is resolved for Phase 1.4.** The user selected `odysseus-dev/odysseus`; the exact source pin is `1c1509094963f9eb9445928d57f2856296057cf4`. SRC-02–SRC-10 have now been revalidated as source findings at that pin; continue the DR-02 design review before any build. No volume/container/runtime test or installation is authorized; any later experiment requires separate explicit approval.

## 4.1 Source-integrity gate — SRC-01 through SRC-10

The canonical audit is pinned to the user-confirmed maintained upstream: **`odysseus-dev/odysseus@1c1509094963f9eb9445928d57f2856296057cf4`** (observed `dev` head on 2026-11-08; GitHub reports the commit signature as verified). SRC-01 is resolved for Phase 1.4; the older Phase 1.3 pin remains a historical record. Read-only checks against this exact pin confirmed SRC-02–SRC-09: the active cache path differs from the Dockerfile's pre-created path; built-in MCP defaults on and can invoke `@playwright/mcp@latest`; setup failures may be swallowed; disabling built-in MCP does not remove custom MCP, shell or Cookbook routes; the entrypoint mutates identity/ownership; custom-font discovery creates a directory outside `DATA_DIR`; `DATA_DIR` and `DATABASE_URL` can diverge; and first-admin bootstrap is exposed to local-process race risk. `THREAT_MODEL.md` explicitly acknowledges no shell/filesystem sandbox. SRC-10 was revised: ChromaDB, SearXNG and ntfy are digest-pinned in the chosen Compose file, but the base image is not digest-pinned, the app image defaults to mutable `:latest`, and main Python dependencies are not hash-locked. The named-volume/non-root profile remains proposed; no build or runtime test is authorized. DR-02 continuation further requires a build-time fixed non-root UID/GID with a separately proven volume-ownership method (UID-04's tested `nomap` bind-mount sequence failed), one consistent `DATA_DIR`/`DATABASE_URL` path, and an operator-controlled first-admin bootstrap that cannot be raced by other local processes. Disabling built-in MCP is not sufficient: shell, Python, Cookbook, custom MCP and background execution must be removed or hard-disabled at both API route registration and Agent tool dispatch; application-level checks are not an OS sandbox. The deployment-specific entrypoint must fail closed without runtime user creation, ownership repair or `setup.py`; custom-font image-tree writes and implicit `npx` downloads remain disabled. These are source/design requirements only, not runtime proof. The canonical audit is v3.10; Source follow-up confirmed relative SQLite URLs normalize against the app root and identified `AuthManager.setup()` as a candidate one-shot offline bootstrap primitive; its lock is process-local, so the HTTP setup route alone is not a cross-process race boundary. The current canonical audit is v3.10. Completed runtime-test count remains 3/5, with no archive snapshot triggered by this source review. DR-02 is now consolidated into a design-only implementation checklist in §18.2: fixed non-root identity/volume ownership, one-root storage/database consistency, fail-closed startup and offline bootstrap, Agent/API execution-surface removal, network/service policy, immutable build inputs, release acceptance and rollback. Six blockers remain; next gate is targeted read-only closure review, starting with UID/volume strategy and bootstrap details. No implementation/build/runtime authorization is granted. The first bootstrap/persistence closure review found that `AuthManager.setup()` can be called without importing the database module, but auth/session JSON writes do not explicitly enforce mode 0600, corrupt existing auth state can be treated as unconfigured, and setup locking is process-local. The separate `.app_key` and `.key` files are critical backup material; database initialization/migrations run during module import, and a sensitive DB chmod failure is warning-only upstream. See audit §18.2 for the source hashes and required safeguards. The canonical audit is now v3.10: VOL-01's read-only host preflight confirmed Podman 6.0.2, the subordinate UID/GID mapping (container UID/GID 1000 maps to host 100999), and the rootless storage/volume paths. Six existing generated-name volumes were inventoried but not touched. Named-volume ownership remains unproven; the next gate is VOL-02, a read-only review of Podman volume and user-namespace capabilities. No volume/container test or installation is authorized. VOL-02 read-only capability review found that Podman 6.0.2 supports `podman volume create --uid/--gid`, `podman unshare`, and explicit container user-namespace/UID/GID mapping options. The native named-volume ownership mechanism is promising but its rootless ID semantics and non-root writability remain unproven; VOL-03 is a read-only local-manual review. No volume/container was created. VOL-03 and corrected VOL-03-R then found that SteamOS has no local manual entries for podman-volume-create, podman-volume-mount or podman-unshare, and no matching Podman manual files in the searched manual tree. The documentation route is closed as inconclusive: the --uid/--gid namespace semantics and non-root volume writability remain unproven. The next gate is VOL-04, a proposed disposable named-volume experiment only; it requires a suitable already-cached probe image and separate explicit approval before any resource is created. No volume/container was created by VOL-03. VOL-04-PREFLIGHT inventoried cached images without pulling or modifying them: Python 3 Alpine (image ID sha256:b7d482700d83c15b2bcc100042762f32064728a74ff84abe9183d892690779a5; digest sha256:d44b1254cb92329418d164b22b20d86bbd3869d48e80e09e476531a409a728bb) and Debian 12 slim are candidates, both reported with zero containers. Python Alpine is the provisional probe-image candidate, pending read-only image-config inspection; any future experiment must use its exact local image ID and disable pulling. The storage summary also reports per-container LOCAL VOLUMES counts that do not reconcile directly with the six named volumes, so all existing resources remain protected and untouched. Next gate: VOL-04-PREFLIGHT-2, read-only inspection of the candidate image configuration. No image/container/volume/network operation was performed. Completed runtime-test count remains 3/5.

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

These are scoped findings, not a final security certification. NET-06 is complete: the exact temporary container and network were removed and independently verified absent; the 10-second SIGTERM timeout/SIGKILL escalation is recorded as a lifecycle caveat. UID-04 has completed Gate 5's focused runtime probe with a scoped FAIL. Consult canonical audit v3.7 for exact evidence, limitations and DR-01/DR-02: the proposed named-volume/non-root direction, sensitive `DATA_DIR` contract, Agent access limitations, and pinned-source findings. The active search cache writes under `DATA_DIR/cache/`; the Dockerfile's `services/cache/search` pre-created path appears unused. The primary app logger writes under `DATA_DIR/logs/`, so a separate `/app/logs` volume is not justified by the reviewed code. ChromaDB is an optional separate HTTP service for vector memory/RAG; if retained it needs its own volume and backup. The pinned upstream threat model explicitly acknowledges no shell/filesystem sandbox for admin Agent tools. The source also exposes a rate-limited first-run `/api/auth/setup` route while no users exist; a custom non-root profile can investigate using it instead of running upstream `setup.py`, but must remain loopback-only until the first admin is created and authentication verified. Further source tracing found that built-in MCP is enabled by default and browser MCP can install via `npx` at first startup; the initial profile must set `ODYSSEUS_DISABLE_MCP=1`. Custom-font additions write under `static/fonts/custom` outside the data volume and must be disabled or redesigned for a read-only root. A second source-integrity review added SRC-01–SRC-10: the Phase 1.3 historical installation-baseline candidate `odysseus-dev/odysseus@03d25943ee4a35f6f0535112976123a721cff5cb` remains unreconciled with the final Phase 1.3 Authority Matrix / Phase 1.4 source-review pin `odysseus-dev/odysseus-current@142b93ad86073efb24981df385423f58fe5376b1`; their Dockerfiles have different blob SHAs and materially different build instructions. **SRC-01 is now the first open dependency and blocks any build** until the user confirms the intended upstream source authority. Other findings cover stale MCP documentation and the limited scope of `ODYSSEUS_DISABLE_MCP=1` (custom MCP routes remain registered), root-dependent entrypoint ownership repair, setup.py's `.env` write failure masked by `|| true`, custom-font writes outside `DATA_DIR`, possible `DATA_DIR`/`DATABASE_URL` divergence, first-admin local-process race risk, and mutable build inputs including base/OS/runtime/service images. The named-volume/non-root architecture remains PROPOSED; no runtime experiment or installation is authorized.

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


## 6. Latest continuation state — 2026-11-08

The authoritative audit is **v3.18**. VOL-04 has been attempted within the approved disposable boundary. Rootless Podman successfully created the exact temporary named volume with `--uid 1000 --gid 1000`; volume inspection reported UID/GID 1000, and `podman unshare stat` reported owner 1000:1000, mode 755. The subsequent container creation failed because the explicit `--userns=private` invocation supplied no UID/GID mapping. No probe container was created, the application-identity write/readback test did not run, and no conclusion about volume writability can be drawn. The exact temporary volume was removed and independent container/volume absence checks passed.

VOL-05-MAP-A has now completed as a read-only mapping inspection. It reconfirmed the configured rootless UID/GID maps (container ID 0 → host 1000; IDs 1–65536 → host 100000–165535), showed the host process's full-range map separately from the Podman unshare map, and confirmed the same subordinate allocation in `/etc/subuid` and `/etc/subgid`. The installed CLI exposes `--uidmap`, `--gidmap`, `--subuidname`, `--subgidname` and `--userns`; the existence of these options does not establish correct private-namespace semantics. The mapping arithmetic aligns container UID/GID 1000 with host 100999 and `podman unshare` UID/GID 1000, but container-visible named-volume writability remains unproven. No resource or host configuration changed.

VOL-05-MAP-B has now completed as a read-only Podman configuration/package review. The inspected main configuration and drop-in locations showed no active userns, uidmap, gidmap, subuid or subgid override. The packaged `/usr/share/containers/containers.conf` contains `userns = "host"` only as a commented example; `/etc/containers/containers.conf` and the user's main config are absent. The architecture drop-in exists but had no matching setting. Local help describes `--userns` only as “User namespace to use” and does not explain `private` semantics. Installed package identity is Podman 6.0.2-2.1, containers-common 1:0.68.1-1 and shadow 4.19.4.arch1-1; `/usr/bin/podman` belongs to the Podman package. No active override was found, but the exact VOL-04 error remains unexplained.

VOL-05-MAP-C has completed as a read-only review of official Podman documentation and source-model descriptions. The CLI docs describe `--uidmap`/`--gidmap` as creating a new user namespace with explicit mappings and document these flags as conflicting with `--userns`. Podman's source model documentation says `UserNS=private` requires `IDMappings`, which is consistent with the VOL-04 error. The exact v6.0.2-tagged source file could not be retrieved through the available source interface, so the exact-version verification limitation is recorded in canonical §18.5.2. The important operational conclusion is that simply adding mapping flags to the old `--userns=private` command is not a valid correction, and mapping values must be derived in the rootless intermediate-ID space rather than guessed.

VOL-05-MAP-D has completed as a design-only mapping review. A full-range candidate uses five disjoint mapping segments for both UID and GID: `0:1:1`, `1:2:998`, `999:1001:1`, `1000:1000:1`, and `1001:1002:64535`. Under the recorded rootless parent map, this maps container root to host UID/GID 100000 and application UID/GID 1000:1000 to host 100999:100999, matching the VOL-04 `podman unshare stat` ownership arithmetic. The design avoids parent namespace ID 0 (Deck UID/GID 1000), covers container IDs 0–65535 and uses the complete subordinate range. It is arithmetic-only: exact Podman 6.0.2 parser acceptance, container-visible named-volume ownership and application write access remain unproven. No runtime resource or host setting changed.

VOL-05-MAP-E has now completed as a read-only local CLI and image-cache check. The installed executable reports Podman 6.0.2, API 6.0.2, Go `1.26.5-X:nodwarf5`, Git commit `b28edb9ad70ce4317dc762ee9ce0a6d081d154e9`, built 2026-08-06 for linux/amd64. Local `podman create --help` exposes `--uidmap strings`, `--gidmap strings` and `--userns string`. This confirms option presence only; it does not prove repeated map acceptance, exact engine semantics or rootless intermediate-ID interpretation. The pinned Compose image `ghcr.io/odysseus-dev/odysseus:latest` is not cached, and no pull was attempted, so its configured user and numeric filesystem ownership remain uninspected. No resources or host settings changed.

**Checkpoint status:** VOL-05-MAP-F is complete — PASS. The five-test checkpoint (NET-05, NET-06, UID-04, VOL-04 and VOL-05-MAP-F) is preserved in the unchanged v3.20 archive snapshot. The active canonical audit is v3.23; the runtime-test counter is 0/5 since v3.20. No volume was attached during MAP-F, so named-volume ownership and application-identity write/readback remain untested.

### Latest continuation — 2026-11-08 (canonical audit v3.23)

**VOL-05-MAP-F is complete — PASS.** Podman 6.0.2 accepted the five explicit UID and five GID mapping entries without a separate --userns option. Read-only inspection confirmed the restricted created-container configuration and normalized map. At runtime, the process reported UID/GID 1000:1000, both proc maps matched the intended mapping, and the probe exited with code 0. The exact disposable container was removed; both its name and full ID were independently verified absent. No volume was mounted, so named-volume ownership and application-identity write/readback remain unproven. The result and stage commands/output are in canonical audit §11, §18.5.6 and the complete shell-wrapper transcript supplement in §18.5.7.

The five-test checkpoint was completed and preserved as an unchanged v3.20 snapshot at:

2.audit/archive/2026-11-08/ODYSSEUS-PHASE-1.4-DEPLOYMENT-FEASIBILITY-AUDIT-v3.20.md

The archived file was fetched back and verified byte-for-byte against the v3.20 canonical content. The active canonical audit is now v3.23; runtime-test accounting has reset to 0/5 since the v3.20 checkpoint.

**Next gate — VOL-05-MAP-G:** run a read-only preflight for a new unique volume/container name and the exact cached Python image. After reviewing the preflight, obtain separate explicit approval before creating either resource. The proposed probe will use the MAP-F-validated UID/GID maps, a single named volume mounted read/write, no network, read-only container root, dropped capabilities and no-new-privileges. It will verify container-visible directory/file ownership, bounded write/readback as UID/GID 1000, host-side ownership through podman unshare, and exact cleanup of both resources. No resource creation is authorized by the preflight. Do not pull the Odysseus image or mutable latest; installation remains unauthorized.

### VOL-05-MAP-G continuation — 2026-11-08 (canonical audit v3.24)

VOL-05-MAP-G Stage A read-only preflight passed. Stage B then created the disposable named volume `odysseus-vol05-mapg-20261108` and stopped probe container `odysseus-vol05-mapg-20261108` (full ID `61f8eb161d7d2a4a8452ebadcfa0e108ef6ecaf53ad106f9f6762aca98acef30`) using the MAP-F-validated explicit UID/GID maps and restricted configuration. The container was **not started**; volume ownership and write/readback remain unproven. Runtime-test accounting remains 0/5 since the unchanged v3.20 archive checkpoint. **Next gate: Stage B2 read-only inspection** of the exact container and volume; do not start the container until that inspection is reviewed. Exact evidence is recorded in canonical audit §§18.5.8–18.5.9. Installation remains unauthorized.

VOL-05-MAP-G Stage A read-only preflight has passed. Podman is 6.0.2; the exact cached Python image ID `sha256:b7d482700d83c15b2bcc100042762f32064728a74ff84abe9183d892690779a5` is present and reports linux/amd64; both proposed temporary names are available; rootless UID and GID maps match the MAP-F assumptions. No resource was created and no image was pulled. Runtime-test accounting remains 0/5 since the unchanged v3.20 archive checkpoint. **Next gate: Stage B resource creation, pending separate explicit approval.** Stage B will create only the disposable named volume and stopped, restricted probe container; Stage B2 inspection must be reviewed before any start/attach runtime test. Exact Stage A evidence is recorded in canonical §18.5.8. Installation remains unauthorized.


### Latest continuation — 2026-11-08 (canonical audit v3.25)

**VOL-05-MAP-G Stage B2 is complete — PASS.** Read-only inspection confirmed the exact disposable container ID/name, `Created` state (`Running=false`, PID 0), exact cached Python image ID/digest, configured process identity 1000:1000, MAP-F-validated UID/GID mappings, `--network=none`, read-only root, all capabilities dropped, no-new-privileges, and the intended read/write named-volume mount at `/probe` with `rprivate,nosuid,nodev,rbind`. The volume exists and reports UID/GID 1000:1000, `MountCount=0` and `NeedsCopyUp=true`. These volume metadata values do not prove application-process write access. The container remains stopped; the Python probe has not executed.

The canonical audit was advanced to **v3.25** and the Stage B2 evidence was recorded in §18.5.10. The read-back verification confirmed the new version and section. Stage B2 was read-only, so runtime-test accounting remains **0/5 since the unchanged v3.20 archive checkpoint**. **Next gate — Stage C:** execute the bounded Python probe in the exact existing disposable container; do not recreate or modify either resource. Review the process identity, directory/file ownership and write/readback result before any cleanup. Host-side ownership inspection and exact cleanup remain subsequent gates. Installation remains unauthorized.


### Latest continuation — 2026-11-08 (canonical audit v3.26)

**VOL-05-MAP-G Stage C is complete — PASS.** The exact disposable container ran the bounded Python probe as UID/GID 1000:1000. The mounted volume directory was owned by 1000:1000 with mode 0755; the bounded write/readback matched; the proof file was owned by 1000:1000 with mode 0600. `podman start --attach` and the container exit code were 0; the container exited normally, OOMKilled was false, and the logs repeated the successful output. The supplied output did not independently identify fsync as a separate observation or disclose the proof-file path.

**VOL-05-MAP-G Stage D is complete — PARTIAL overall.** `podman unshare stat/find` confirmed the volume directory UID/GID 1000:1000 mode 755 and discovered `mapg-proof.txt` UID/GID 1000:1000 mode 600. Ordinary host `ls -lan` returned `Permission denied`; the direct host view is unavailable and is not treated as evidence of missing data. The container and named volume remain present; cleanup has not been performed.

The canonical audit advanced to **v3.26**, with exact command/output recorded in §18.5.11, dependency gate §12 and continuation handoff §18 updated. Read-back verification passed. Runtime-test accounting is **1/5 since the unchanged v3.20 archive checkpoint**; no archive snapshot is due yet.

**Next gate:** VOL-05-MAP-G Stage D — read-only host-side ownership inspection through `podman unshare`, using the existing volume mountpoint and discovering the proof-file name from its contents. Review Stage D before separate exact cleanup.

**Installation authorization policy:** Installation remains **NOT AUTHORIZED**. Per the user's instruction, the audit now records a conditional status transition to **INSTALLATION: AUTHORIZED** only after every required container/runtime, source/build, security-boundary, lifecycle/recovery and final security-acceptance gate is evidence-backed GREEN/PASS, with no unresolved blocker. This successful volume probe alone does not authorize installation or any host changes.


### Latest continuation — 2026-11-08 (canonical audit v3.28)

VOL-05-MAP-G Stage D is recorded in canonical audit §18.5.12. The container remains exited (exit 0), and the volume metadata reports UID/GID 1000:1000. Ordinary host `ls -lan` could not access the mountpoint (`Permission denied`). In contrast, `podman unshare stat` confirmed the directory as UID/GID 1000:1000 mode 755, and `podman unshare find` discovered `mapg-proof.txt` as UID/GID 1000:1000 mode 600. Stage D is PARTIAL overall because the ordinary host listing was unavailable; the namespace-view ownership inspection succeeded. This was read-only and does not increment the runtime-test counter, which remains 1/5 since the unchanged v3.20 archive snapshot. The next gate is separately documented exact cleanup of the disposable container and named volume, followed by independent absence verification. Installation remains NOT AUTHORIZED under the user's conditional all-gates-green rule.

### Latest continuation — 2026-11-08 (canonical audit v3.29)

**VOL-05-MAP-G exact disposable-resource cleanup is complete — PASS.** The exact stopped container `odysseus-vol05-mapg-20261108` (ID `61f8eb161d7d2a4a8452ebadcfa0e108ef6ecaf53ad106f9f6762aca98acef30`) and exact named volume `odysseus-vol05-mapg-20261108` were removed. The preflight confirmed the container identity and `STATUS=exited`, `RUNNING=false`; the exact volume was inspected before removal. Independent `podman container exists` and `podman volume exists` checks each returned exit code 1, confirming both resources absent. No broader Podman cleanup was performed.

Stage D remains **PARTIAL overall**: `podman unshare stat/find` confirmed directory/file ownership and modes, but ordinary host `ls -lan` was denied. The cleanup PASS does not upgrade that host-view result. This cleanup is not a runtime test; accounting remains **1/5 since the unchanged v3.20 archive snapshot**, so no archive is due.

**Next gate: Gate 6 — candidate mount allowlist.** Begin with read-only reconciliation of the canonical DR-02 storage contract and identify each candidate mount and required access mode. Do not create another container or volume until a mount-specific test design, read-only preflight and separate approval boundary are documented. Installation remains **NOT AUTHORIZED** under the conditional all-gates-green rule. See canonical audit §§12, 18.5.12–18.6 for the authoritative detail.



## 5. Installation — future phase only

**NOT AUTHORIZED.** The installation guide is a separate planning document, not part of the active audit and not an executable installation procedure.

[Odysseus — Future Installation & Deployment Guide](./3.installation/ODYSSEUS-INSTALLATION-GUIDE.md)

It records the durable /home/deck/odysseus-box/ project layout, SteamOS-update resilience requirements, security constraints inherited from Phase 1.4, recovery requirements and future approval gates. It must remain consistent with the audit and the shared Deck baseline.

**Distrobox reminder:** if Distrobox is selected for a project environment, keep that project's deployment rooted under /home/deck/<project-name>/ and use a dedicated HOME beneath that root. This is not permission to expose the whole host home or to treat Distrobox as a hardened sandbox.


## 6. Current Gate 6 handoff — 2026-11-09

The canonical Phase 1.4 audit is **v3.31**. Installation remains **NOT AUTHORIZED**. The latest unchanged archive snapshot is v3.20; runtime-test accounting is **1/5** since that checkpoint.

Gate 5's explicit UID/GID map and generic named-volume write/readback probe passed for the tested configuration. The ordinary host ownership listing remained PARTIAL because it was denied; the rootless Podman namespace view confirmed ownership and modes. Exact cleanup passed.

**Gate 6 source reconciliation is complete (MOUNT-02-REVIEW-01).** At the pinned upstream commit, the only provisional application-container persistent mount is one dedicated named volume at `/app/data`, read/write. The application database, auth/session state, encryption keys, uploads, personal documents, logs and other persistent stores resolve under `DATA_DIR`; `ODYSSEUS_DATA_DIR` and `DATABASE_URL` must point to the same data root.

Do not adopt the upstream Compose convenience mounts for `/app/logs`, `/app/.ssh`, `/app/.cache/huggingface` or `/app/.local`. Do not expose the host home, project root, source tree or runtime sockets. Custom-font writes outside `DATA_DIR` must be disabled or redesigned for a read-only image root. The Agent workspace is a child of `/app/data`, not an independent sandbox; shell/Python execution must remain disabled or separately brokered. No read-only Inspector mount has been selected because no concrete host source path or Inspector implementation exists. ChromaDB remains an unresolved separate-service decision.

**Next:** read-only Stage A preflight for a new disposable mount probe at `/app/data`, using the exact cached Python image and MAP-F-validated mapping. Resource creation/runtime execution require separate approval after Stage A review. See canonical audit §18.8 for evidence, scope and exact validation criteria.

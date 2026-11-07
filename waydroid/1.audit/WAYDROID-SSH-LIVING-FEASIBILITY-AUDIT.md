# Waydroid SSH — Living Container Feasibility Audit & Continuation Record

> **Document role:** Canonical, cumulative engineering record for the Waydroid-on-Steam-Deck / remote-client project. This document is deliberately written for future ChatGPT sessions: it preserves the decisions, evidence, test history, exact continuation point, and anti-repetition rules needed to resume the audit without replaying completed groundwork.
>
> **Status:** Read-only Waydroid feasibility phase CLOSED; independent LXC-only experimental investigation OPEN — temporary LXC package/runtime experiments approved in principle, but package-manager safety and exact package manifest remain blocked; no installation performed — **Deck-local LXC 1:7.0.0-1 candidate and print-only transaction reported; upstream LXC v7.0.0 cgroup implementation reconciled with host tests; direct-host delegated child-cgroup creation/removal and process placement confirmed; LXC v7.0.0 unprivileged systemd-scope path requires non-root execution and controller activation; stock Waydroid's D-Bus/systemd container service runs as root and therefore bypasses that LXC path; wrapping the user CLI does not wrap the root service's actual lxc-start process; rootless Podman cgroup mount remains read-only; package file-manifest inspection remains blocked; controller activation and LXC runtime remain untested; no LXC installation performed**.
>
> **Document version:** 3.8  
> **Last source refresh:** 2026-11-07  
> **Current branch:** `main`  
> **Scope:** Closed container-only Waydroid feasibility record plus separately scoped LXC-only experimental investigation; no Waydroid installation authorized. Temporary LXC-only installation may be considered only after package provenance, package-manager safety, exact transaction and rollback plan are verified and separately confirmed.

---

## 0. Read this first — mandatory continuation protocol

This is the living project record. Read this section and the latest test ledger before proposing any command.

### 0.1 The project in one sentence

Run Android on the Steam Deck OLED, with the Deck doing Android CPU/GPU work, while Linux Mint and Windows act as remote display and input clients; SSH-based launch/control and secure transport are mandatory.

### 0.2 Non-negotiable project decisions

| ID | Decision / constraint | Status |
|---|---|---|
| D-01 | Waydroid must run inside a container environment (rootless Podman baseline; Distrobox may be evaluated as a userspace convenience layer) | **MANDATORY** |
| D-02 | Do not install Waydroid natively on SteamOS | **REJECTED TARGET** |
| D-03 | Ryan Rudolf's former native SteamOS installation/scripts are historical reference only | **REFERENCE ONLY** |
| D-04 | SSH launch/control from Linux Mint and Windows is mandatory | **MANDATORY** |
| D-05 | Prefer a separate Android window on the client, not a full Deck desktop stream | **PREFERRED TARGET** |
| D-06 | Reuse the existing KDE Plasma / Wayland session if feasible | **PREFERRED** |
| D-07 | No privileged outer container, broad host mounts, host network/PID/IPC sharing, or unnecessary device passthrough | **SECURITY BASELINE** |
| D-08 | No host-wide firewall, forwarding, kernel, service, or package changes just to force feasibility | **NOT AUTHORIZED** |
| D-09 | Pi-hole, Stable Diffusion, LocalAI/Shyrka, Odysseus, and all other existing projects are protected | **MUST NOT DISTURB** |
| D-10 | No automatic startup, boot service, background daemon, or persistent permission change without explicit approval | **NOT AUTHORIZED** |
| D-11 | Diagnose first; use read-only checks; back up before any approved edit; destructive operations require explicit approval | **MANDATORY** |
| D-12 | A finding that secure container deployment is infeasible is an acceptable audit outcome | **ACCEPTED** |

**Important scope correction:** Early discussion considered native and remote launch modes. The later accepted project definition narrowed the target to **container-only Waydroid**. Do not reopen native SteamOS installation as an implementation option unless the user explicitly changes the requirement.

### 0.3 What this document is — and is not

- It is the cumulative index and evidence ledger for the audit.
- It is not an authorization to execute historical commands.
- It is not an installation guide.
- Historical environment values are not automatically current values.
- A passed primitive test is not proof that the complete Waydroid workflow works.
- When a new test is performed, append its exact command, complete relevant output, exit status, scope, interpretation, limitations, and repeat policy to this document **immediately, before proposing or running the next test**.
- **Approved maintenance cadence:** every completed test is recorded immediately in this canonical document. After every five completed tests, perform a documentation consistency review and preserve an unchanged versioned archive snapshot. Create an earlier snapshot before a significant architecture/security decision or material restructuring.
- Every new ChatGPT conversation must begin from this canonical handoff and current test ledger; never rely on assumed conversation memory. The handoff must identify the next exact gate and current document version.

### 0.4 Status vocabulary

Use these labels consistently:

| Label | Meaning |
|---|---|
| **CONFIRMED** | Directly established by observed output, an actual test, or authoritative source inspection |
| **HISTORICAL** | Confirmed earlier; current state has not been refreshed |
| **PARTIAL** | A sub-operation succeeded or failed, but the full requirement was not tested |
| **PENDING** | Defined as the next test or action; no result recorded |
| **UNTESTED** | No experiment has been performed |
| **INCONCLUSIVE** | Evidence is insufficient or ambiguous |
| **SUPERSEDED** | An earlier result or design was corrected or replaced |
| **ASSUMPTION** | Plausible hypothesis without direct evidence |
| **BLOCKED** | Cannot proceed until a prerequisite or policy decision is resolved |
| **NOT AUTHORIZED** | Technically possible perhaps, but outside the current approval boundary |

---

## 1. Executive assessment

### 1.1 Current verdict

**The direct-host cgroup primitives now pass, but the stock Waydroid launch path does not enter LXC 7.0.0's unprivileged systemd-delegation path.** The Deck-reported package candidate is LXC 1:7.0.0-1 (not installed); the matching upstream v7.0.0 release source was inspected. In a pure unified cgroup-v2 system, when LXC runs with a non-root effective UID, LXC 7.0.0 can create its own transient systemd user scope with Delegate=yes, move its launcher process into an init child cgroup, and write every controller listed in cgroup.controllers into the scope's cgroup.subtree_control. It then creates monitor/container cgroups, moves processes between them, and removes those trees during teardown. LXC-CGROUP-01/02 proved the host's delegated child-cgroup create/remove and single-process placement primitives, but did not test controller activation, whole-parent process migration, LXC monitor/payload lifecycle, or device BPF operations.

The stock Waydroid path is materially different: the system D-Bus activation service and systemd unit run the Waydroid container manager as root. That manager invokes lxc-start directly as a background child process. LXC 7.0.0 explicitly skips its unprivileged systemd user-scope creation when geteuid() is 0. Therefore, putting a user-side waydroid CLI request inside systemd-run --user --scope does not place the root D-Bus-activated service or its lxc-start child in that user scope. The source evidence identifies a real privilege-context/integration mismatch; it does not prove that a redesigned split-privilege architecture is impossible.

The separate rootless Podman route remains blocked by the read-only cgroup2 mount observed inside the disposable container. A rootless LXC process directly on the host and LXC nested inside rootless Podman are distinct architectures; the direct-host tests do not make the nested Podman mount writable. Waydroid's base config explicitly mounts cgroup read-only and retains capabilities inside the Android container, while the effective LXC device policy still depends on package defaults and generated config. LXC's cgroup-v2 device-rule implementation uses eBPF load/attach/detach when device rules are configured; the Waydroid base config reviewed here does not itself specify cgroup2 device rules, so actual BPF use is not asserted.

**Decision:** Do not install or launch LXC/Waydroid yet. The package file manifest remains blocked and the original pacman DB lock failure unexplained. The source review establishes that a real LXC runtime test would need to cover controller activation and LXC's own lifecycle, but it does not authorize a controller write, package-manager retry, installation, service change, or launcher modification. SPLIT-ARCH-01 has now reviewed that design question: a custom manual-only split is technically conceivable but would require manager/launcher adaptation, unresolved rootfs/device handling, and a network solution incompatible with the current no-host-network-change boundary. It is not recommended for implementation under the current constraints. A safe resolution of the package-manifest prerequisite also remains necessary for any future LXC runtime work.

### 1.2 Positive evidence

- KDE Plasma / KWin Wayland session and its runtime socket were present during the historical audit.
- AMD Van Gogh GPU and `/dev/dri/renderD128` were identified on the host.
- Rust Binder is built into the recorded SteamOS kernel; BinderFS is registered.
- BinderFS mounted in a disposable rootless Podman container when `CAP_SYS_ADMIN` was explicitly granted.
- The three Binder nodes (`binder`, `vndbinder`, `hwbinder`) were created in that disposable BinderFS instance.
- The Binder device opened and returned protocol version 8 through `BINDER_VERSION`.
- Host nested user namespace creation succeeded.
- Nested user namespace creation inside rootless Podman succeeded with `SETUID + SETGID + SETPCAP + SETFCAP` in Test 19.
- Test 20 removed `SETPCAP`; nested user namespace creation succeeded with `SETUID + SETGID + SETFCAP` under `seccomp=unconfined`.
- Test 21 repeated the same operation and capability set with Podman's **default seccomp** profile (`Seccomp: 2`); nested user namespace creation and UID/GID mapping succeeded, with inner and outer exit codes `0`. Default seccomp is confirmed for this specific operation.
- Host-side private user/network namespace bridge, forwarding, and NAT operations succeeded without changing the host's persistent forwarding state.
- Ordinary outbound networking/DNS from a disposable Podman container succeeded.

### 1.3 Remaining gates

1. Complete source/dependency review of Waydroid manager/service assumptions, install-time dependencies, generated LXC configuration, cgroups, Binder, GPU, network, Wayland and D-Bus.
2. Resolve the architecture boundary: Android itself is an LXC container; the Waydroid manager normally runs as host-side userspace. An outer container does not automatically remove the inner LXC requirement.
3. Determine whether direct host-level unprivileged LXC can be tested with a temporary delegated user scope, without persistent service enablement or host-wide cgroup changes. Test 24 applies to the Podman boundary, not direct host-level LXC.
4. Only if necessary, present a bounded installation/test/rollback plan before installing LXC. Conditional permission does not authorize Waydroid packages, services or persistent configuration.
5. If the LXC gate passes, test Binder device handoff and actual transactions.
5. Test the minimum AMD render-node access required; no GPU workload has been run inside the target boundary.
6. Test Wayland, D-Bus, audio, and session handoff from a headless SSH-launched process without broad host runtime mounts.
7. Resolve Android networking without host-wide forwarding/firewall changes or Pi-hole impact.
8. Test localhost-only ADB plus SSH forwarding and scrcpy end-to-end from both Mint and Windows.
9. Assess Rust Binder stability under real Android workloads, including large-transaction behavior.
10. Test Android data persistence/recovery and manual lifecycle only if the runtime passes earlier gates.

**No permanent Waydroid container, package installation, host kernel modification, Binder service, firewall change, or persistent Android data store is justified yet.**

---

## 2. Target architecture and acceptance criteria



### 2.1B Upstream packaging, D-Bus control plane and SteamOS package implications

#### Waydroid packaging is a host integration bundle

The upstream Debian control file declares the Waydroid package dependencies as LXC, Python runtime, python3-gbinder, python3-gi, GTK introspection, python3-dbus, D-Bus, PolicyKit, PipeWire PulseAudio or PulseAudio, and iptables. This is the dependency set for the **Waydroid manager package**, not a requirement list for an isolated LXC-only audit. Distribution package dependencies vary; Debian names must not be copied as SteamOS/Arch package names.

The upstream Makefile defaults to PREFIX=/usr, USE_SYSTEMD=1 and USE_DBUS_ACTIVATION=1. A normal install copies manager code/data to /usr/lib/waydroid, creates /usr/bin/waydroid, installs desktop integration and icons under /usr/share, a system D-Bus policy under /usr/share/dbus-1/system.d, a PolicyKit action under /usr/share/polkit-1/actions, a D-Bus activation service under /usr/share/dbus-1/system-services, and a systemd unit under /usr/lib/systemd/system. This confirms that the normal Waydroid install is not a self-contained payload inside an outer container.

#### D-Bus and PolicyKit behavior inspected

| File | Source behavior | Project implication |
|---|---|---|
| [dbus/id.waydro.Container.service](https://github.com/waydroid/waydroid/blob/main/dbus/id.waydro.Container.service) | D-Bus activation names id.waydro.Container; executes /usr/bin/waydroid container start as User=root; associates activation with waydroid-container.service. | D-Bus activation can request root-owned manager startup. Do not install this host activation file. |
| [dbus/id.waydro.Container.conf](https://github.com/waydroid/waydroid/blob/main/dbus/id.waydro.Container.conf) | Allows root to own id.waydro.Container and default-context clients to send to/receive from that name. | System-bus access policy is part of the host trust boundary. Do not install. |
| [dbus/id.waydro.Container.policy](https://github.com/waydroid/waydroid/blob/main/dbus/id.waydro.Container.policy) | Declares a PolicyKit action for Waydroid initialization, with administrator authentication defaults. | Another host-level privilege integration; not needed for an LXC-only test. |
| [systemd/waydroid-container.service](https://github.com/waydroid/waydroid/blob/main/systemd/waydroid-container.service) | Starts /usr/bin/waydroid container start, claims BusName=id.waydro.Container, and has WantedBy=multi-user.target. | Would provide system-service lifecycle and can be enabled for boot startup. Must not be installed/enabled as part of this audit. |

The manager code uses the system D-Bus, exports methods to start/stop/freeze/unfreeze and query the container, checks caller UID/session PID for session starts, and starts a GLib main loop. The container manager then performs host-side preparation (Binder probing/node permissions, optional driver loading, network script, session-specific config, rootfs mount, LXC start, hardware manager). Therefore a custom manual-only manager would still need a deliberate replacement for this host control plane and its privilege boundary; simply invoking lxc-start does not reproduce Waydroid lifecycle behavior.

#### LXC package scope versus Waydroid package scope

The upstream Arch LXC package metadata currently describes LXC as a standalone package with runtime dependencies including bash, dbus, libcap, libseccomp, perl, Python, rsync and wget; dnsmasq is listed as optional for lxc-net.service. The listed package installed size is about 2.8 MB in that Arch metadata. This is a reference for likely package shape, **not a verified SteamOS transaction**. Deck-local LXC-PKG-01 reported candidate lxc version 1:7.0.0-1 from extra-3.9 and a print-only transaction containing only lxc, with all seven listed dependencies already installed. LXC-PKG-02 could not inspect the file manifest because the repository file-list databases were absent locally; this does not invalidate the sync-database candidate. The raw PKG-01 output was not included in the current continuation handoff, so those values remain reported rather than independently reverified.

The optional LXC network helper/service is not required merely to run the LXC CLI. Do not enable lxc-net, lxc-containers, or any LXC autostart/network unit. Waydroid's own default network script independently creates a bridge, configures forwarding, starts dnsmasq and adds firewall rules; that script remains prohibited for this project.

#### SteamOS package persistence and update behavior

Valve states that SteamOS updates deliver a complete OS image and that software installed outside Flatpak (including with pacman) may be wiped by the next SteamOS update. Valve recommends Flatpak for desktop applications. Third-party SteamOS partition/update research describes the A/B image slots, persistent /home and special handling/synchronization of /var and /etc; treat those implementation details as corroboration rather than a guarantee for every future build.

Implications for LXC:
- A normal pacman installation places LXC executables, libraries, templates and related files under system paths such as /usr. Those changes are not update-stable; assume they may be removed or replaced by a SteamOS image update.
- LXC package data/config under /etc or /var must not be assumed durable merely because those paths are writable; SteamOS synchronizes /var as part of its update process and /etc is an overlay backed by /var.
- Keep any future container rootfs, userdata, audit scripts, logs and backups in a deliberately chosen persistent /home path, not in /usr, /var/lib/waydroid or transient locations.
- Do not use a broad pacman -Syu or change the host's package-management state for this audit.
- A portable/custom LXC install under /home or /opt is not yet demonstrated to be safe or maintainable: dynamic library compatibility, helper binaries, system integration, security updates and the exact delegated-scope behavior still need evidence. Do not assume it solves the update problem.
- A post-update check/recovery script could verify package/runtime versions and kernel/cgroup/device prerequisites, but it cannot make an unsupported host package installation update-proof.

#### What is known versus what still requires a Deck-local read-only check

| Item | Current evidence | Remaining requirement |
|---|---|---|
| LXC package dependencies | Arch upstream package metadata gives a reference dependency set. | Query the Deck's own installed/sync package metadata to calculate the exact transaction and dependency delta. |
| LXC package availability/version in the user's configured SteamOS repos | Public Valve mirror indexes are not sufficient to prove the package candidate for the user's exact active branch/build. | Read-only local package metadata check against the user's configured repositories. |
| Existing required libraries/tools | General host context is known, but not a complete current package ownership/dependency inventory. | Read-only local package query; do not assume dbus, libcap, libseccomp, perl, rsync or wget are all present at compatible versions. |
| Package install persistence | Valve explicitly warns pacman-installed packages may be wiped by SteamOS updates. | Treat conventional /usr package installation as temporary and potentially requiring reinstallation after updates. |
| Waydroid manager host dependencies | Upstream package and Makefile show broad host integrations. | None of these are approved for installation; manager architecture remains unresolved. |

**Installation decision at this stage: NOT YET.** The read-only review has established that an LXC-only install can be scoped independently from Waydroid, but it has not yet established the exact SteamOS package transaction or shown that direct host-level LXC will pass the cgroup and namespace gates. Before installing anything, obtain a Deck-local read-only package/dependency report. If the package delta is small and does not upgrade/remove core system packages, a temporary LXC-only install may be proposed for explicit confirmation. Any such install would be treated as a temporary audit instrument that may be lost on SteamOS update—not as a durable deployment.


### 2.1A LXC and Waydroid — terminology and runtime boundary

**LXC (Linux Containers)** is a Linux userspace container-management toolset. It uses kernel facilities—namespaces, cgroups, capabilities, mount operations and security modules—to create isolated process environments. It is not a virtual machine and does not provide a separate guest kernel. The liblxc library and lxc-* commands manage container lifecycle and access.

**Waydroid already uses LXC for its Android system container.** The distinction is important:

- **Waydroid manager/userspace:** host-facing software that initializes images, generates LXC configuration, prepares Binder/devices and session mounts, coordinates networking/session state, and calls LXC commands.
- **Android runtime:** the LXC container named waydroid, containing the Android root filesystem and userdata.
- In a conventional installation, the manager, helper scripts, D-Bus/service integration and LXC tools are installed on the Linux host; Android itself runs inside LXC. “Waydroid runs in a container” does not necessarily mean its manager is inside an outer container.

This is not yet accepted as satisfying the user's stricter container-only requirement. The working interpretation remains: **do not install the Waydroid manager, Waydroid system service, or Waydroid host integration on SteamOS** unless the user explicitly clarifies otherwise. A host-level LXC runtime alone is not the same as a native Waydroid installation, but whether it is acceptable must be decided before implementation.

#### Current upstream source observations (2026-11-06)

| Source | Directly observed behavior | Feasibility implication |
|---|---|---|
| [Waydroid tools/helpers/lxc.py](https://github.com/waydroid/waydroid/blob/main/tools/helpers/lxc.py) | Checks for lxc-info; generates /var/lib/waydroid/lxc/waydroid/config; generates device and session mount snippets; directly invokes lxc-start -F, lxc-stop, lxc-attach, lxc-info, lxc-freeze and lxc-unfreeze. | Stock launcher assumes LXC commands are callable directly; the documented delegated-scope wrapper is not visible in these calls. |
| [Waydroid data/configs/config_base](https://github.com/waydroid/waydroid/blob/main/data/configs/config_base) | Sets Android rootfs path, lxc.autodev = 0, lxc.mount.auto = cgroup:ro sys:ro proc, and includes generated device/session config. Its lxc.cap.keep includes powerful capabilities such as sys_admin, net_admin and sys_time. | Exact config must be assessed against SteamOS and outer containment. Inner Android-container capabilities are not equivalent to granting those capabilities to the outer container or host. |
| [Waydroid tools/actions/container_manager.py](https://github.com/waydroid/waydroid/blob/main/tools/actions/container_manager.py) | Coordinates Binder preparation, permission changes, session config, rootfs mounts, LXC startup, hardware manager and networking cleanup/start-stop behavior. | Waydroid is more than lxc-start; a manual launcher must account for lifecycle side effects and cleanup. |
| [Waydroid tools/actions/initializer.py](https://github.com/waydroid/waydroid/blob/main/tools/actions/initializer.py) | Initialization creates image/rootfs/overlay state, prepares host permissions and LXC config, and can restart the container through manager/service paths. | Initialization and host integration need separate review; do not copy the native installer. |
| [LXC Getting Started](https://linuxcontainers.org/lxc/getting-started/) | For unprivileged cgroup-v2 containers, LXC documents an empty delegated cgroup and wraps each lxc-* invocation with systemd-run --user --scope -p Delegate=yes. | The Waydroid launcher integration gap is a key review item. |
| [Debian LXC cgroup-v2 guidance](https://wiki.debian.org/LXC/CGroupV2) | Notes foreground/background lifecycle nuances when invoking LXC through delegated systemd scopes. | Any wrapper must cover start, status/attach/stop and process lifetime—not just a one-off start. |
| [Waydroid systemd/waydroid-container.service](https://github.com/waydroid/waydroid/blob/main/systemd/waydroid-container.service) | Defines a system service with ExecStart=/usr/bin/waydroid container start and WantedBy=multi-user.target. | Enabling it would create boot-time startup; this is expressly outside the desired manual-only lifecycle. Do not enable it. |
| [Waydroid data/scripts/waydroid-net.sh](https://github.com/waydroid/waydroid/blob/main/data/scripts/waydroid-net.sh) | Creates/uses waydroid0 and includes host iptables INPUT, FORWARD and NAT rules plus IPv6 forwarding/address operations. | Default network setup is a host networking side effect and conflicts with the no-host-firewall/forwarding-change baseline unless replaced by a separately approved isolated design. |
| [Waydroid tools/config/__init__.py](https://github.com/waydroid/waydroid/blob/main/tools/config/__init__.py) | Default work paths place images, rootfs, overlays, userdata, LXC config and host-permissions beneath the configured Waydroid work directory (commonly /var/lib/waydroid). | A container-only design must relocate/persist these deliberately; default paths are not automatically suitable for SteamOS updates or the user's no-host-install requirement. |


#### Service and network side effects — newly confirmed

Two source findings materially narrow the design:

1. The upstream Waydroid container unit is a **system service** whose ExecStart runs /usr/bin/waydroid container start and whose install target is multi-user.target. Enabling this unit would introduce boot-time startup. It must remain disabled; the user's required lifecycle is manual start/stop only. A manual command can still invoke manager code without enabling the unit, but its dependencies and D-Bus expectations need review.
2. The upstream waydroid-net.sh script is not a passive container-local network configuration. Its default path manages the waydroid0 bridge and changes host INPUT/FORWARD/NAT firewall rules; IPv6 paths can also alter forwarding and interface settings. This conflicts with the project's no host-wide firewall/forwarding changes and Pi-hole protection. The default script must not be run on SteamOS during audit. A future network design must isolate effects or omit/rewrite this integration and be independently reviewed.

The upstream default work-directory configuration also places images, rootfs, overlays, userdata, LXC configuration and host-permissions under the Waydroid work path (commonly /var/lib/waydroid). A container-only design must explicitly relocate and persist state rather than assume the stock host paths are acceptable.

#### Generated mount/device requirements seen in source

The upstream helper conditionally generates LXC mount entries for Binder/vndbinder/hwbinder nodes; the selected DRM render node and optional graphics/video/device nodes; /dev/net/tun, /dev/uhid, pseudo-terminals and selected sysfs paths; the Wayland socket and PulseAudio native socket; and Android userdata.

This is a **source-level inventory**, not proof that every optional node is required on this Steam Deck. The minimum device and mount set must be established from the Deck's kernel and Android image. Broadly mounting /dev, /sys, the whole user runtime directory or host filesystem is not an acceptable shortcut.

#### Cgroup-v2 delegation distinction

LXC's rootless documentation says unprivileged containers require an empty delegated cgroup; Delegate=yes is normally applied to a systemd user scope wrapping LXC commands. The prior Test 24 result (read-only cgroup mount inside rootless Podman) is evidence about the **Podman outer-container boundary**, not a direct host-level LXC experiment. Test 25's Delegate=yes on user@1000.service is not proof that every process or nested container receives a writable delegated subtree.

- Do not claim direct host-level rootless LXC is impossible based only on Test 24.
- Do not claim it will work merely because the user manager has Delegate=yes.
- A direct host-level test, if justified, must use a temporary user scope, inspect its delegated cgroup and avoid persistent systemd changes.
- The stock Waydroid manager's direct LXC calls must be accounted for; a wrapper/patch would need to cover all lifecycle commands consistently.

#### Architecture alternatives — not yet approved

| Design | Shape | Main issue | Current status |
|---|---|---|---|
| A — stock Waydroid manager on SteamOS + LXC Android container | SteamOS has Waydroid manager/tools and LXC CLI; Android is inside LXC | May violate the user's no-native-Waydroid requirement because manager/service/integration are host-installed | **NOT ACCEPTED** |
| B — Waydroid manager in rootless Podman + inner LXC | SteamOS → Podman → Waydroid userspace → Android LXC | Test 24 showed read-only cgroup view in Podman; nested LXC delegation unproven; stock launcher has no documented delegated-scope wrapper | **BLOCKED / UNPROVEN** |
| C — Waydroid manager in outer host-level LXC + inner LXC | SteamOS → outer LXC containing Waydroid userspace → inner LXC | Still nested LXC; cgroup delegation and device/session handoff are unproven; may not remove inner LXC requirement | **UNPROVEN** |
| D — single LXC container directly treated as Android runtime, without Waydroid manager | SteamOS → one LXC container | Not established as a supported Waydroid deployment; would require reproducing image/config/init/device/session/network integration | **UNPROVEN; do not present as supported** |

**Current interpretation:** the container-only requirement rules out the native Waydroid installer, but does not yet tell us whether host-side LXC runtime binaries only are acceptable. Do not install Waydroid host packages or service files. Continue dependency review and ask for clarification only if the viable design requires host-side LXC binaries or Waydroid manager components.


### 2.1 Intended architecture

```text
LINUX MINT CLIENT                              WINDOWS CLIENT
  SSH client                                     SSH client
  scrcpy / ADB client                            scrcpy / ADB client
  keyboard / mouse                               keyboard / mouse
        |                                               |
        +---------------- SSH tunnel -------------------+
                                |
                                v
STEAM DECK OLED — STEAMOS HOST
  SSH service
  KDE Plasma / KWin Wayland session
  AMD Van Gogh GPU / amdgpu
  Rootless Podman
        |
        v
  Dedicated, least-privilege outer container
  (Distrobox only if it adds value without widening access)
        |
        v
  Waydroid userspace / service manager
        |
        v
  Inner LXC Android container
        |              |               |
      Binder          GPU           Android userdata
      devices       render node       dedicated store
        |
  Android applications
```

### 2.2 Responsibility boundaries

| Component | Responsibility | Must not do |
|---|---|---|
| Steam Deck host | Android CPU/GPU execution, container runtime, session integration, SSH endpoint | Become a permanently modified Android appliance without explicit approval |
| Outer Podman container | Isolated Waydroid userspace and runtime dependencies | Share broad host namespaces or mount the host filesystem wholesale |
| Inner LXC | Android system container | Escape its intended device, mount, network, or data boundaries |
| Mint / Windows | Display, input, SSH client, scrcpy/ADB client | Run Android workloads locally |
| SSH tunnel | Protect ADB/control transport over LAN | Expose unauthenticated ADB on the LAN |
| Android userdata store | Preserve Android state independently of container recreation | Be mixed into broad host home mounts |

### 2.3 Acceptance criteria

| Area | Acceptance condition | Evidence required |
|---|---|---|
| Execution location | Android workload executes on Deck | Process/cgroup/device evidence during actual workload |
| CPU/RAM | Android runtime resources are Deck-side | Host-side process/resource observations |
| GPU | Hardware rendering uses Deck GPU | Renderer evidence and actual workload, not just device-node presence |
| Container isolation | No privileged mode or broad host access | Effective OCI config, mounts, namespaces, capabilities, security profile |
| Binder | Android can communicate reliably through Binder | Real Binder transactions and Android services |
| LXC | Inner LXC starts and remains stable | Actual disposable LXC test, cgroup and namespace evidence |
| Session | Existing KDE Wayland session can be used safely | Tested socket/D-Bus/audio access from intended launcher |
| Networking | Android networking works without unsafe host side effects | Tested network path, firewall scope, cleanup and before/after state |
| Remote display | Android display appears on Mint and Windows | End-to-end scrcpy tests |
| Security | ADB is localhost-only and carried through SSH | Listener inspection and successful authenticated tunnel |
| Lifecycle | Manual start/stop only | Explicit lifecycle commands; no autostart |
| Recovery | Android data survives container recreation | Backup/restore test before relying on it |

### 2.4 Remote display clarification

The leading candidate is **scrcpy over an SSH tunnel**. This mirrors and controls an Android display; it does not prove that every Android app can be exported as an independent client-side window. Waydroid multi-window behavior and remote app-window behavior are separate requirements and must be evaluated separately.

SSH by itself launches and controls processes; it does not forward a graphical Android display. Video encoding on the Deck and decoding on the client will consume resources on both ends. The Android workload and rendering should remain on the Deck if the design works as intended.

---

## 3. Historical host and runtime baseline

> All values in this section are **HISTORICAL** observations from the audit export. Refresh only when the relevant system, kernel, runtime, or session has changed, or when a new test specifically requires current values.

### 3.1 Steam Deck host

| Item | Last recorded value | Status |
|---|---|---|
| Device | Steam Deck OLED | HISTORICAL |
| Hostname | `Laco` | HISTORICAL |
| User | `deck` | HISTORICAL |
| UID/GID | `1000:1000` | HISTORICAL |
| SteamOS build ID | `20261023.100` | HISTORICAL |
| SteamOS version reported by Podman | `3.9.5` | HISTORICAL |
| Kernel | `7.2.7-valve2-2-neptune-72-g31504582a073` | HISTORICAL |
| Architecture | `x86_64` | HISTORICAL |
| Desktop | KDE Plasma / Wayland | HISTORICAL |
| Compositor | `kwin_wayland` | HISTORICAL |
| Runtime directory | `/run/user/1000` | HISTORICAL |
| Wayland socket | `/run/user/1000/wayland-0` | HISTORICAL |
| User systemd manager | Active | HISTORICAL |
| SSH shell | Headless TTY; graphical variables not inherited automatically | CONFIRMED in recorded session |

### 3.2 GPU

| Item | Recorded observation | Status |
|---|---|---|
| GPU vendor | AMD `0x1002` | HISTORICAL |
| Device ID | `0x1435` (Van Gogh) | HISTORICAL |
| Kernel driver | `amdgpu` | HISTORICAL |
| Primary node | `/dev/dri/card0` | HISTORICAL |
| Render node | `/dev/dri/renderD128` | HISTORICAL |
| Recorded permissions | card0 root:video mode 0660 plus ACL; renderD128 root:render mode 0666 | HISTORICAL |
| User groups | `deck` was not a member of `video` or `render` in recorded `id` output | HISTORICAL |

Node presence and host permissions do **not** prove rendering from a container or Waydroid.

### 3.3 Kernel Binder configuration

Recorded kernel configuration:

```text
# CONFIG_ANDROID_BINDER_IPC is not set
CONFIG_ANDROID_BINDER_IPC_RUST=y
CONFIG_ANDROID_BINDER_DEVICES=""
```

Additional historical observations:

- `/sys/module/rust_binder` existed.
- `/sys/module/rust_binder/parameters/rust_devices` existed and was empty.
- `/proc/filesystems` listed `nodev binder`.
- Traditional Binder module was not listed.
- No persistent host BinderFS mount or `/dev/binder*` nodes were present.
- Recorded `bindgen` version: `0.72.1`.

This is the **Rust Binder / BinderFS route**, not a conventional pre-created Binder device setup. Do not conflate “BinderFS registered” with “Waydroid Binder runtime proven.”

### 3.4 Podman baseline

| Item | Last recorded value |
|---|---|
| Engine | Podman `6.0.2` |
| OCI runtime | `crun 1.28-dirty` |
| Cgroup manager | systemd |
| Cgroup version | v2 |
| Network backend | Netavark `2.0.0` |
| Rootless network helper | pasta |
| Storage | overlay |
| Rootless | true |
| Subordinate UID range | `deck:100000:65536` |
| Subordinate GID range | `deck:100000:65536` |
| Test image | `docker.io/library/debian:12-slim` |
| Default Podman network | `10.88.0.0/16` |

Recorded rootless mapping:

```text
Container ID 0        -> host ID 1000 (deck)
Container IDs 1-65536 -> host IDs 100000-165535
```

Recorded default rootless capability list:

```text
CAP_CHOWN
CAP_DAC_OVERRIDE
CAP_FOWNER
CAP_FSETID
CAP_KILL
CAP_NET_BIND_SERVICE
CAP_SETFCAP
CAP_SETGID
CAP_SETPCAP
CAP_SETUID
CAP_SYS_CHROOT
```

### 3.5 Existing projects — protected inventory

Recorded inventory at audit time:

| Name | Recorded state | Protection |
|---|---|---|
| `pihole` | Running | Do not stop, modify, prune, repurpose, or reconfigure |
| `pihole-box` | Stopped | Protected |
| `Stable-box` | Stopped | Protected |
| `localai-box` | Stopped | Protected |

Existing Distrobox configurations were inspected and found to be permissive: `Privileged=true`, host network/PID/IPC, unconfined AppArmor, disabled SELinux labels, broad writable mounts including `/home/deck`, `/dev`, `/sys`, `/tmp` and `/`, and no explicit capability drops. **Do not copy these settings.** Rootless does not neutralize the risk of broad mounts; container root maps to host UID 1000.

---

## 4. Chronological audit map — work already performed

This section is the anti-repetition index. Read it before proposing another inventory or diagnostic script.

### Phase A — Goal, display path and scope

| Investigation | Historical result | Status | Repeat policy |
|---|---|---|---|
| Remote execution vs display separation | SSH controls remote process; separate display transport is needed | CONFIRMED | Do not repeat concept explanation |
| scrcpy vs Sunshine/Moonlight/remote desktop | scrcpy became leading candidate for separate Android display window | HISTORICAL DECISION | Revisit only if scrcpy proves unsuitable |
| Existing KDE desktop preference | Reuse current KDE session preferred | ACCEPTED PREFERENCE | Do not create another compositor by default |
| Individual app window | Desired, but not established by scrcpy alone | UNTESTED | Dedicated later acceptance test |
| Container-only scope | Later user direction excluded native install | MANDATORY | Do not propose native installation |

### Phase B — Host/session/kernel/GPU baseline

Investigations completed:

- SteamOS release and kernel identification.
- Session type and compositor identification.
- Active login session and process inspection.
- Runtime directory and Wayland socket presence.
- SSH environment compared with graphical session environment.
- GPU PCI vendor/device and driver identification.
- DRM node existence and permissions.
- Kernel config and Binder implementation inspection.
- Rust Binder module and parameter inspection.

**Result:** historical host prerequisites were identified. The ordinary SSH shell was headless and did not automatically inherit the KDE graphical environment. No Android GUI session was launched.

**Repeat only if:** SteamOS/kernel update, user/session layout changes, GPU driver/device changes, or a specific later integration test needs fresh evidence.

### Phase C — Upstream Waydroid implementation inspection

The historical review examined these areas of upstream source:

| Source area | Question answered | Key finding |
|---|---|---|
| `tools/helpers/drivers.py` | How Binder drivers/devices are discovered and initialized | Waydroid attempts Binder setup and uses BinderFS-related logic |
| `tools/helpers/lxc.py` | How Waydroid builds LXC configuration | LXC receives device/mount/runtime integration; security implications need narrow review |
| `tools/helpers/net.py` | How network setup is invoked | Host networking integration is part of normal setup |
| `data/scripts/waydroid-net.sh` | What network side effects occur | Creates bridge, changes forwarding, adds firewall/NAT rules, runs dnsmasq |
| `tools/actions/session_manager.py` | How graphical session starts | Session manager expects access to the host graphical environment |
| `tools/actions/container_manager.py` | How container lifecycle is managed | Waydroid wraps LXC lifecycle and initialization |

Key observations retained:

- Waydroid stores selected Binder device names during initialization.
- Its network helper manipulates forwarding/firewall state.
- The inspected shutdown path did not restore the previous `net.ipv4.ip_forward` value.
- The Android userdata mount and device permission handling need deliberate security review.
- An SSH-launched shell does not automatically inherit Wayland, X11 or desktop D-Bus variables.
- Upstream source behavior is not proof that the same behavior is safe or viable inside rootless Podman on SteamOS.

**Do not repeat source inspection without a specific changed upstream version or a concrete unanswered question.** If upstream is updated, record the exact commit/tag and compare relevant functions rather than replacing the historical record.

### Phase D — Existing container engine and security inspection

Completed:

- Distrobox inventory and state inspection.
- Docker executable availability check; Docker was not the engine.
- Podman version/runtime/cgroup/network backend inspection.
- Rootless status and subordinate UID/GID mapping inspection.
- Existing Distrobox configuration comparison.
- Effective UID/GID maps and namespace/security inspection.
- Capability masks and security flags inspected.
- Existing project mounts, namespaces and privileges identified.

Key result: rootless Podman is the chosen audit baseline; existing Distroboxes are not acceptable security templates.

**Do not repeat broad container inventory** unless the runtime or configuration has changed. Use a targeted check for the exact property under investigation.

### Phase E — BinderFS and Binder device experiments

Completed:

1. Host BinderFS availability inspected.
2. Host BinderFS mount attempted in a private user/mount namespace.
3. Binder device creation attempted with a corrected ioctl definition.
4. Compiler/tool availability inspected to avoid installing packages on SteamOS.
5. Rootless Podman BinderFS mount attempted with all capabilities dropped.
6. Same operation attempted with narrowly added `CAP_SYS_ADMIN`.
7. Corrected BinderFS device-creation ioctl executed inside disposable Podman.
8. Binder device opened and `BINDER_VERSION` queried.

Important correction: the first ioctl attempt returned `EINVAL`, but the request/structure encoding was wrong. That attempt was invalid and was superseded by the corrected ioctl. Do **not** interpret the initial `EINVAL` as proof of a Binder limitation.

Detailed results are in Section 5.

### Phase F — cgroup/LXC prerequisites

Completed:

- Host cgroup v2 filesystem and controller inventory.
- Host `cgroup.controllers` and `cgroup.subtree_control` inspection.
- User systemd service delegation inspection.
- Podman user namespace cgroup view.
- Disposable container cgroup mount and controller inspection.
- Nested user/mount/PID namespace prerequisite investigations.

Key result: the host had cgroup v2 and systemd user delegation, but the disposable Podman container saw a read-only cgroup2 mount and an empty subtree-control file. Visibility of cgroup v2 does not establish writable delegation for nested LXC.

**Do not repeat the host cgroup inventory.** A later test should specifically establish whether the actual intended LXC mode can run with the available read-only/no-delegation boundary, or whether a secure delegated arrangement is required.

### Phase G — Network prerequisites

Completed:

- Host network tools and interfaces inventory.
- Host `net.ipv4.ip_forward` recorded as `0`.
- Private host user/network namespace bridge creation/deletion.
- Private namespace forwarding and NAT chain creation/cleanup.
- Podman network configuration and default network inspection.
- Disposable Podman outbound networking and DNS test.
- Rootless Podman `NET_ADMIN` forwarding attempt.

Key result: namespace-local bridge/forwarding/NAT worked in a private host namespace. The Podman test failed at `sysctl -w net.ipv4.ip_forward=1` with permission denied; bridge/NAT were not reached. Host forwarding remained `0`.

**Do not claim Podman bridge/NAT failed**: that stage was not reached. Do not claim private namespace success proves Podman network success.

### Phase H — Nested UID/GID mapping and capability isolation

Completed through Test 19:

- All-capabilities-dropped nested user namespace attempt failed.
- Default Podman capability baseline passed under the recorded relaxed security test conditions.
- seccomp and `no_new_privs` were varied independently; neither alone resolved the failure.
- Host nested user namespace passed.
- Podman mapping policy, `/proc/self/setgroups`, UID/GID maps and capability masks inspected.
- Capability groups were isolated sequentially.
- `CAP_SETFCAP` was identified as sufficient when added to the original `SETUID + SETGID + SETPCAP` trio.

**Current exact stopping point:** Test 20 passed. The smallest successful set identified so far is `SETUID + SETGID + SETFCAP` under `seccomp=unconfined`. Do not rerun Tests 1–20.

---

## 5. Detailed technical test ledger

This is the authoritative audit register. If an item is already complete, do not repeat it without recording a changed condition and explaining why.

### 5.1 Host, kernel, session and GPU

| Test ID | Objective / inspection | Recorded result | Status | Repeat condition |
|---|---|---|---|---|
| H-01 | Identify OS/build and kernel | SteamOS build `20261023.100`; kernel `7.2.7-valve2-2-neptune-72-g31504582a073` | HISTORICAL | OS/kernel update |
| H-02 | Identify active graphical session | KDE Plasma / KWin Wayland | HISTORICAL | Session architecture changes |
| H-03 | Inspect session runtime and Wayland socket | `/run/user/1000` and `wayland-0` present | HISTORICAL | Session/runtime changes |
| H-04 | Compare SSH shell with desktop session | SSH session is headless TTY; graphical environment not inherited automatically | CONFIRMED | Only if launcher/session handoff changes |
| H-05 | Identify GPU/driver | AMD `1002:1435`, `amdgpu` | HISTORICAL | Kernel/driver/hardware changes |
| H-06 | Inspect DRM nodes and permissions | card0 and renderD128 present; historical permissions recorded in §3.2 | HISTORICAL | GPU/permissions change or container device test |
| H-07 | Inspect kernel Binder configuration | Rust Binder built in; C Binder disabled; BinderFS registered | HISTORICAL | Kernel update |
| H-08 | Inspect Rust Binder module parameters | Module and parameter path present; device parameter empty | HISTORICAL | Kernel update |

### 5.2 BinderFS and Binder

| Test ID | Environment / procedure | Actual result | Status | What it proves / does not prove |
|---|---|---|---|---|
| B-01 | Host private user + mount namespace; mount BinderFS | Mount succeeded | CONFIRMED | BinderFS can mount in that namespace; not Waydroid |
| B-02 | Host private BinderFS; corrected `BINDER_CTL_ADD` | Created `binder`, `vndbinder`, `hwbinder` | CONFIRMED | BinderFS device creation works in that test namespace |
| B-03 | Disposable rootless Podman, `--cap-drop=ALL`; mount BinderFS | Denied, exit 32 | CONFIRMED FAILURE | Strict no-capability baseline cannot mount BinderFS |
| B-04 | Same disposable Podman test with `CAP_SYS_ADMIN` | BinderFS mount passed; binder-control device major/minor 243:0 | CONFIRMED | This capability allowed the mount in that disposable test; not approval to grant permanently |
| B-05 | First Perl ioctl encoding | `EINVAL` | SUPERSEDED / INVALID TEST | Incorrect request/structure; do not repeat |
| B-06 | Corrected ioctl `0xC1086201`, structure `char name[256] + __u32 major + __u32 minor` | Created nodes 243:1, 243:2, 243:3 | CONFIRMED | BinderFS device creation in disposable Podman |
| B-07 | Open Binder device and issue `BINDER_VERSION` ioctl `0xC0046209` | Returned protocol version 8 | CONFIRMED | Device responds to version query; no transactions or Android service tested |
| B-08 | Android-like Binder transactions | Not run | UNTESTED | Needed only after LXC/Android runtime prerequisites pass |
| B-09 | Binder device permission/security propagation through nested LXC | Not run | UNTESTED | Must test with least privilege; do not assume upstream 0666 is acceptable |
| B-10 | Rust Binder stability under Android workload | Not run | UNTESTED | Include realistic large-transaction/service stability testing |

**Critical limitation:** BinderFS mount and a successful `BINDER_VERSION` query are low-level checks only. They do not prove Binder transaction semantics, Waydroid service startup, Android boot, or long-term Rust Binder stability.

### 5.3 Cgroups and nested LXC

| Test ID | Environment / procedure | Recorded result | Status | Repeat condition |
|---|---|---|---|---|
| C-01 | Host cgroup filesystem type | cgroup v2 | HISTORICAL | Host cgroup configuration changes |
| C-02 | Host controllers and subtree controls | Controllers observed: `cpuset cpu io memory hugetlb pids rdma misc dmem`; subtree included `cpu memory pids dmem` | HISTORICAL | Host changes |
| C-03 | `user@1000.service` delegation | `Delegate=yes`; controllers included `cpu memory pids` | HISTORICAL | systemd/user service config changes |
| C-04 | Podman user namespace cgroup view | Host hierarchy visible | HISTORICAL | Podman/runtime changes |
| C-05 | Disposable container cgroup mount | cgroup2 mounted read-only; visible controllers included cpu/memory/pids; subtree control empty | CONFIRMED for test | Only if Podman/cgroup setup changes |
| C-06 | Actual nested LXC start | Not attempted | UNTESTED | After namespace/cgroup prerequisites |
| C-07 | LXC with reduced/no cgroup management | Not attempted | UNTESTED | Determine from exact LXC version/config requirements |
| C-08 | Writable delegated cgroup design | Not established | BLOCKED / UNTESTED | Requires technical need and explicit security review |

**Do not repeat C-01 to C-05 as a generic inventory.** The next cgroup work must be an LXC-specific feasibility experiment or a targeted check following a changed runtime configuration.

### 5.4 Host namespace and Podman namespace tests

| Test ID | Operation | Result | Status |
|---|---|---|---|
| N-01 | Host `unshare --user --map-root-user` | Passed; nested UID/GID mapping `0 -> 1000` | CONFIRMED |
| N-02 | Host private user + network namespace | Passed | CONFIRMED |
| N-03 | Host private namespace bridge create/up/delete | Passed | CONFIRMED |
| N-04 | Host private namespace forwarding + NAT chain | Passed; cleanup completed | CONFIRMED |
| N-05 | Podman nested user namespace with all capabilities dropped | Failed | CONFIRMED FAILURE |
| N-06 | Podman nested mount namespace with all capabilities dropped | UID mapping denied; mount namespace not reached | CONFIRMED FAILURE |
| N-07 | Podman nested PID namespace with all capabilities dropped | UID mapping denied; PID namespace not reached | CONFIRMED FAILURE |
| N-08 | Podman nested user namespace with default rootless capabilities and relaxed security settings | Passed | CONFIRMED in that test configuration |
| N-09 | Repeat namespace test after reducing capabilities | Covered by capability tests below | See N-10 onward |

### 5.5 Capability isolation — exact test sequence

The tests below used disposable Debian 12 Slim containers, `--network=none`, and `seccomp=unconfined` unless otherwise stated. Results are specific to the recorded SteamOS / Podman / crun environment.

| Test ID | Retained capabilities | Result | Status |
|---|---|---|---|
| CAP-01 | None (`--cap-drop=ALL`) | Nested user namespace failed | CONFIRMED FAILURE |
| CAP-02 | `SETUID + SETGID` | Failed | CONFIRMED FAILURE |
| CAP-03 | `SETUID + SETGID + SETPCAP` (Test 12B) | Failed | CONFIRMED FAILURE |
| CAP-04 | Above + `CHOWN + DAC_OVERRIDE + FOWNER + FSETID` (Test 14) | Failed | CONFIRMED FAILURE |
| CAP-05 | Above + `KILL + NET_BIND_SERVICE + SYS_CHROOT + SETFCAP` (Test 15) | Passed | CONFIRMED |
| CAP-06 | Base three + `KILL + NET_BIND_SERVICE` (Test 16) | Failed | CONFIRMED FAILURE |
| CAP-07 | Base three + `SYS_CHROOT + SETFCAP` (Test 17) | Passed | CONFIRMED |
| CAP-08 | Base three + `SYS_CHROOT` only (Test 18) | Failed | CONFIRMED FAILURE |
| CAP-09 | Base three + `SETFCAP` only (Test 19) | Passed | CONFIRMED |
| CAP-10 | `SETUID + SETGID + SETFCAP` (remove `SETPCAP`; Test 20; seccomp unconfined) | Passed; capability mask `00000000800000c0`; inner and outer exit codes `0` | **CONFIRMED** |
| CAP-11 | Same three capabilities under Podman's default seccomp profile (Test 21) | Passed; `Seccomp: 2`; capability mask `00000000800000c0`; inner and outer exit codes `0` | **CONFIRMED** |
| CAP-12 | Same three capabilities; nested user then mount namespace under default seccomp (Test 22) | Passed; distinct mount namespace IDs; `Seccomp: 2`; nested and outer exit codes `0`; shell comparison emitted a quoting diagnostic | **CONFIRMED — namespace creation; validation guard defective** |

Successful Test 19 output:

```text
CapPrm: 00000000800001c0
CapEff: 00000000800001c0
CapBnd: 00000000800001c0
NoNewPrivs: 0
Seccomp: 0

Namespace created successfully
UID map:
         0          0          1
GID map:
         0          0          1
uid=0(root) gid=0(root) groups=0(root)

Nested namespace exit code: 0
```

Interpretation: `SETFCAP` is sufficient when added to the original three capabilities in this exact test. It is not established as a Waydroid requirement or a permanent permission recommendation.

#### Test 20 — completed: `SETPCAP` removed

- **Date:** 2026-11-06
- **Status:** CONFIRMED
- **Environment:** Steam Deck host launching a disposable rootless Podman container
- **Image/runtime:** `docker.io/library/debian:12-slim`; Podman configuration as recorded in §3.4
- **Prerequisite:** CAP-09 / Test 19
- **Question:** Can nested user-namespace creation and root UID/GID mapping succeed without `CAP_SETPCAP`?
- **Why new:** Isolates the necessity of `SETPCAP` after Test 19 established that `SETFCAP` was sufficient when combined with the original three capabilities.
- **Repeat policy:** Do not repeat unless SteamOS kernel, Podman/crun, user-namespace policy, or the tested capability/security configuration changes.
- **Side-effect boundary:** Disposable container, `--rm`, `--network=none`, `--pull=never`; no host networking, persistent files, services, or configuration changes.

**Exact command executed**

```bash
podman run --rm --pull=never \
  --name waydroid-map-cap-audit-20 \
  --network=none \
  --cap-drop=ALL \
  --cap-add=SETUID \
  --cap-add=SETGID \
  --cap-add=SETFCAP \
  --security-opt=seccomp=unconfined \
  docker.io/library/debian:12-slim \
  sh -c '
    echo "===== CAPABILITIES ====="
    grep -E "^(CapPrm|CapEff|CapBnd|NoNewPrivs|Seccomp):" /proc/self/status

    echo
    echo "===== NESTED USER NAMESPACE TEST ====="

    unshare --user --map-root-user sh -c "
      echo Namespace created successfully
      echo UID map:
      cat /proc/self/uid_map
      echo GID map:
      cat /proc/self/gid_map
      id
    "

    result=$?

    echo
    echo "Nested namespace exit code: $result"

    exit "$result"
  '

PODMAN_EXIT=$?
echo
echo "===== OUTER PODMAN EXIT STATUS ====="
echo "Podman exit code: $PODMAN_EXIT"
```

**Actual output**

```text
===== CAPABILITIES =====
CapPrm: 00000000800000c0
CapEff: 00000000800000c0
CapBnd: 00000000800000c0
NoNewPrivs:     0
Seccomp:        0

===== NESTED USER NAMESPACE TEST =====
Namespace created successfully
UID map:
         0          0          1
GID map:
         0          0          1
uid=0(root) gid=0(root) groups=0(root)

Nested namespace exit code: 0

===== OUTER PODMAN EXIT STATUS =====
Podman exit code: 0
```

**Observed result**

- The capability mask was `00000000800000c0` in permitted, effective, and bounding sets. This corresponds to the requested retained set `SETUID + SETGID + SETFCAP`; `SETPCAP` was absent.
- Nested user namespace creation succeeded.
- UID and GID maps each showed `0 -> 0` with a one-ID range inside the disposable container's namespace view.
- Inner `unshare` exit status: `0`.
- Outer Podman exit status: `0`.

**Interpretation**

- **What this proves:** `CAP_SETPCAP` is not required for this specific nested user-namespace creation and root mapping operation under the tested Debian 12 Slim / rootless Podman / seccomp-unconfined configuration.
- **What this does not prove:** It does not establish that this set is sufficient for nested mount/PID namespaces, LXC, Binder handoff, Waydroid startup, or a secure production container. It does not show compatibility with Podman's default seccomp profile.
- **Security note:** `SETFCAP` remains present in the smallest successful set identified by these tests. It is not yet justified as a permanent runtime capability; subsequent tests must determine whether it can be removed or whether the operation can be redesigned.

**Decision / next step**

- Mark Test 20 passed; do not repeat Tests 1–20 without a changed condition.
- Next: test the same `SETUID + SETGID + SETFCAP` set with Podman's default seccomp profile (omit `--security-opt=seccomp=unconfined`).
- Then test nested mount and PID namespaces only if the default-seccomp user-namespace gate passes.

**Evidence-quality correction:** The earlier proposed Test 20 command ended with `exit 0`, which could mask an inner `unshare` failure. The executed command propagated `result` using `exit "$result"` and separately reported `PODMAN_EXIT`; both returned `0`. Future nested tests must preserve this exit-status propagation pattern.

#### Test 21 — completed: default seccomp profile

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **CONFIRMED**
- **Environment:** Steam Deck host launching a disposable rootless Podman container
- **Image/runtime:** `docker.io/library/debian:12-slim`; rootless Podman; Podman's default seccomp profile (no `--security-opt=seccomp=unconfined` argument)
- **Prerequisite:** Test 20 / CAP-10
- **Question:** Does `SETUID + SETGID + SETFCAP` still permit nested user-namespace creation and root UID/GID mapping under Podman's default seccomp profile?
- **Why new:** Test 20 established the reduced capability set only with seccomp unconfined. Test 21 changes that one security dimension and verifies the same operation under the default filter.
- **Repeat policy:** Do not repeat unless SteamOS kernel, Podman/crun, seccomp profile, user-namespace policy, image, or tested capability configuration changes.
- **Side-effect boundary:** Disposable container, `--rm`, `--network=none`, `--pull=never`; no host networking, persistent files, services, or configuration changes.

**Exact command executed**

```bash
podman run --rm --pull=never \
  --name waydroid-map-cap-audit-21 \
  --network=none \
  --cap-drop=ALL \
  --cap-add=SETUID \
  --cap-add=SETGID \
  --cap-add=SETFCAP \
  docker.io/library/debian:12-slim \
  sh -c '
    echo "===== CAPABILITIES ====="
    grep -E "^(CapPrm|CapEff|CapBnd|NoNewPrivs|Seccomp):" /proc/self/status

    echo
    echo "===== NESTED USER NAMESPACE TEST ====="

    unshare --user --map-root-user sh -c "
      echo Namespace created successfully
      echo UID map:
      cat /proc/self/uid_map
      echo GID map:
      cat /proc/self/gid_map
      id
    "

    result=$?

    echo
    echo "Nested namespace exit code: $result"

    exit "$result"
  '

PODMAN_EXIT=$?
echo
echo "===== OUTER PODMAN EXIT STATUS ====="
echo "Podman exit code: $PODMAN_EXIT"
```

**Actual output**

```text
===== CAPABILITIES =====
CapPrm: 00000000800000c0
CapEff: 00000000800000c0
CapBnd: 00000000800000c0
NoNewPrivs:     0
Seccomp:        2

===== NESTED USER NAMESPACE TEST =====
Namespace created successfully
UID map:
         0          0          1
GID map:
         0          0          1
uid=0(root) gid=0(root) groups=0(root)

Nested namespace exit code: 0

===== OUTER PODMAN EXIT STATUS =====
Podman exit code: 0
```

**Observed result**

- `CapPrm`, `CapEff`, and `CapBnd` were all `00000000800000c0`, matching `SETUID + SETGID + SETFCAP`; `SETPCAP` was absent.
- `Seccomp: 2` confirms seccomp filter mode; seccomp was not disabled.
- Nested user-namespace creation succeeded; UID/GID maps each showed `0 -> 0` with a one-ID range inside the disposable container's namespace view.
- Inner `unshare` exit status: `0`; outer Podman exit status: `0`.

**Interpretation**

- **Proves:** This nested user-namespace creation and root UID/GID mapping operation succeeds with the three retained capabilities under Podman's default seccomp profile in this specific Debian 12 Slim / rootless Podman / SteamOS configuration. `seccomp=unconfined` is not required for this operation.
- **Does not prove:** Sufficiency for nested mount/PID namespaces, LXC, Binder handoff, Waydroid startup, or a secure production container; nor that every required syscall is allowed by the default profile.
- **Security note:** `SETFCAP` is still not justified as a permanent runtime capability; later tests must determine whether it can be removed.

**Decision / next step**

- Keep seccomp enabled for subsequent experiments; do not add `seccomp=unconfined` without a narrowly scoped reason.
- Proceed to Test 22: nested mount namespace feasibility with the same three capabilities, default seccomp, `--cap-drop=ALL`, `--network=none`, and `--pull=never`. Do not add capabilities speculatively; preserve the operation's exit status.
- Test 21 created no persistent container, host configuration, service, or network state.

---

#### Test 22 — completed: nested mount namespace creation

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **CONFIRMED — namespace creation**; **shell assertion defective**
- **Environment:** Steam Deck host launching a disposable rootless Podman container
- **Image/runtime:** `docker.io/library/debian:12-slim`; rootless Podman; Podman's default seccomp profile
- **Prerequisite:** Test 21 / CAP-11, which confirmed nested user-namespace creation under default seccomp
- **Question:** Can the reduced capability set create a nested user namespace and then a distinct mount namespace under default seccomp?
- **Why new:** Test 21 tested only a nested user namespace. Test 22 added the mount namespace operation and compared the parent/child mount namespace identifiers.
- **Repeat policy:** Do not repeat the namespace creation operation unless the kernel, Podman/crun, seccomp profile, user-namespace policy, image, or capability configuration changes. A corrected assertion-only check may be run if needed, but must not be misrepresented as a new namespace feasibility test.
- **Side-effect boundary:** Disposable container, `--rm`, `--network=none`, `--pull=never`; no host networking, persistent files, services, or configuration changes.

**Exact command executed**

```bash
podman run --rm --pull=never \
  --name waydroid-map-cap-audit-22 \
  --network=none \
  --cap-drop=ALL \
  --cap-add=SETUID \
  --cap-add=SETGID \
  --cap-add=SETFCAP \
  docker.io/library/debian:12-slim \
  sh -c '
    echo "===== CAPABILITIES AND SECURITY ====="
    grep -E "^(CapPrm|CapEff|CapBnd|NoNewPrivs|Seccomp):" /proc/self/status

    echo
    echo "===== NESTED USER NAMESPACE ====="

    unshare --user --map-root-user sh -c "
      echo User namespace created successfully

      echo
      echo UID map:
      cat /proc/self/uid_map

      echo
      echo GID map:
      cat /proc/self/gid_map

      echo
      id

      echo
      echo Parent mount namespace:
      parent_mnt=\$(readlink /proc/self/ns/mnt)
      echo \$parent_mnt
      export parent_mnt

      echo
      echo ===== NESTED MOUNT NAMESPACE =====

      unshare --mount sh -c \"
        child_mnt=\\\$(readlink /proc/self/ns/mnt)

        echo Child mount namespace:
        echo \\\$child_mnt

        echo Parent mount namespace:
        echo \\\$parent_mnt

        if [ \\\\\"\\\$child_mnt\\\\\" = \\\\\"\\\$parent_mnt\\\\\" ]; then
          echo ERROR: Mount namespace did not change
          exit 1
        fi

        echo Mount namespace created successfully
      \"

      result=\$?

      echo
      echo Nested mount namespace exit code: \$result

      exit \$result
    "

    result=$?

    echo
    echo Nested user namespace and mount test exit code: $result

    exit "$result"
  '

PODMAN_EXIT=$?

echo
echo "===== OUTER PODMAN EXIT STATUS ====="
echo "Podman exit code: $PODMAN_EXIT"
```

**Actual output**

```text
===== CAPABILITIES AND SECURITY =====
CapPrm: 00000000800000c0
CapEff: 00000000800000c0
CapBnd: 00000000800000c0
NoNewPrivs:     0
Seccomp:        2

===== NESTED USER NAMESPACE =====
User namespace created successfully

UID map:
         0          0          1

GID map:
         0          0          1

uid=0(root) gid=0(root) groups=0(root)

Parent mount namespace:
mnt:[4026532877]

===== NESTED MOUNT NAMESPACE =====
Child mount namespace:
mnt:[4026532992]
Parent mount namespace:
mnt:[4026532877]
Mount namespace created successfully
sh: 10: [: missing ]

Nested mount namespace exit code: 0

Nested user namespace and mount test exit code: 0

===== OUTER PODMAN EXIT STATUS =====
Podman exit code: 0
```

**Observed result**

- `CapPrm`, `CapEff`, and `CapBnd` were `00000000800000c0`, matching `SETUID + SETGID + SETFCAP`; `SETPCAP` was absent.
- `Seccomp: 2` confirms seccomp filter mode; seccomp was not disabled.
- The nested user namespace and UID/GID mappings succeeded.
- Parent mount namespace ID was `mnt:[4026532877]`; child mount namespace ID was `mnt:[4026532992]`. The different IDs are direct evidence that the child entered a distinct mount namespace.
- `unshare --mount` returned success; the nested and outer reported exit codes were both `0`.
- **Command defect:** The shell emitted `sh: 10: [: missing ]`. The explicit `[ child = parent ]` guard was malformed by nested quoting and did not execute as intended. Because the IDs were printed independently and differ, this defect does not negate the namespace-creation evidence. However, the script's zero exit status does not validate that malformed guard.

**Interpretation**

- **What this proves:** With `SETUID + SETGID + SETFCAP`, `--cap-drop=ALL`, and Podman's default seccomp profile, the tested process successfully created a nested user namespace and entered a distinct mount namespace in this disposable Debian 12 Slim / rootless Podman / SteamOS configuration.
- **What this does not prove:** It does not prove that filesystem mounts, bind mounts, propagation settings, LXC mount setup, cgroup operations, Binder, or Waydroid work. No mount syscall was attempted inside the new mount namespace.
- **Evidence qualification:** Namespace creation is confirmed by the successful `unshare --mount` operation and distinct namespace IDs. The shell comparison guard is defective and must not be cited as a successful assertion.
- **Security note:** No additional capability was needed for this mount-namespace creation test. This does not establish the capability requirements for actual mount operations.

**Decision / next step**

- Keep the three-capability set and default seccomp for the next namespace test.
- Proceed to Test 23: nested PID namespace creation and a minimal child-process lifecycle check. Preserve exact exit statuses. Do not add capabilities or disable seccomp speculatively.
- Test 22 created no persistent container, host configuration, service, or network state.

---

#### Test 23 — completed: nested PID namespace and child lifecycle

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **CONFIRMED**
- **Environment:** Steam Deck host launching a disposable rootless Podman container
- **Image/runtime:** `docker.io/library/debian:12-slim`; rootless Podman; Podman's default seccomp profile
- **Prerequisite:** Test 21 / CAP-11 (nested user namespace under default seccomp) and Test 22 (distinct mount namespace creation)
- **Question:** Can the reduced capability set create a nested user namespace and PID namespace under default seccomp, start a child process, and wait for it successfully?
- **Why new:** Tests 21–22 established user and mount namespace creation. Test 23 adds a PID namespace and validates PID 1 identity plus a basic child-process lifecycle.
- **Repeat policy:** Do not repeat unless the kernel, Podman/crun, seccomp profile, user-namespace policy, image, or capability configuration changes.
- **Side-effect boundary:** Disposable container, `--rm`, `--network=none`, `--pull=never`; no host networking, persistent files, services, or configuration changes.

**Harness correction:** The first Test 23 invocation omitted `-i` while feeding a here-document to `sh -s`. It produced no container output and only `Podman exit code: 0`; this was **not executed**, not a pass or failure. The corrected invocation added `-i` and exported the parent PID namespace identifier for the nested shell. Only the corrected run below counts as Test 23.

**Exact successful command**

```bash
podman run -i --rm --pull=never \
  --name waydroid-map-cap-audit-23 \
  --network=none \
  --cap-drop=ALL \
  --cap-add=SETUID \
  --cap-add=SETGID \
  --cap-add=SETFCAP \
  docker.io/library/debian:12-slim \
  sh -s <<'CONTAINER_SCRIPT'
echo "===== CAPABILITIES AND SECURITY ====="
grep -E "^(CapPrm|CapEff|CapBnd|NoNewPrivs|Seccomp):" /proc/self/status

echo
echo "===== PARENT PID NAMESPACE ====="
parent_pid_ns=$(readlink /proc/self/ns/pid)
echo "$parent_pid_ns"
export parent_pid_ns

echo
echo "===== NESTED USER + PID NAMESPACE ====="

unshare --user --map-root-user --pid --fork sh -c '
  echo "Nested namespace created"

  echo
  echo "Child PID namespace:"
  child_pid_ns=$(readlink /proc/self/ns/pid)
  echo "$child_pid_ns"

  echo
  echo "Parent PID namespace:"
  echo "$parent_pid_ns"

  if [ "$child_pid_ns" = "$parent_pid_ns" ]; then
    echo "ERROR: PID namespace did not change"
    exit 1
  fi

  echo
  echo "Current process PID:"
  echo "$"

  if [ "$" -ne 1 ]; then
    echo "ERROR: Namespace init process is not PID 1"
    exit 1
  fi

  echo
  echo "PID namespace status:"
  grep "^NSpid:" /proc/self/status

  echo
  echo "===== CHILD PROCESS LIFECYCLE ====="

  sleep 2 &
  child_pid=$!

  echo "Started child PID: $child_pid"

  if kill -0 "$child_pid" 2>/dev/null; then
    echo "Child process is running"
  else
    echo "ERROR: Child process was not running"
    exit 1
  fi

  wait "$child_pid"
  child_result=$?

  echo "Child wait exit code: $child_result"
  exit "$child_result"
'

result=$?

echo
echo "Nested user/PID namespace exit code: $result"

exit "$result"
CONTAINER_SCRIPT

PODMAN_EXIT=$?

echo
echo "===== OUTER PODMAN EXIT STATUS ====="
echo "Podman exit code: $PODMAN_EXIT"
```

**Actual output**

```text
===== CAPABILITIES AND SECURITY =====
CapPrm: 00000000800000c0
CapEff: 00000000800000c0
CapBnd: 00000000800000c0
NoNewPrivs:     0
Seccomp:        2

===== PARENT PID NAMESPACE =====
pid:[4026532880]

===== NESTED USER + PID NAMESPACE =====
Nested namespace created

Child PID namespace:
pid:[4026532992]

Parent PID namespace:
pid:[4026532880]

Current process PID:
1

PID namespace status:
NSpid:  7       3

===== CHILD PROCESS LIFECYCLE =====
Started child PID: 4
Child process is running
Child wait exit code: 0

Nested user/PID namespace exit code: 0

===== OUTER PODMAN EXIT STATUS =====
Podman exit code: 0
```

**Observed result**

- Capability permitted/effective/bounding masks were all `00000000800000c0`, matching the retained `SETUID + SETGID + SETFCAP` set.
- `Seccomp: 2`: the default seccomp filter remained active.
- Parent PID namespace: `pid:[4026532880]`.
- Child PID namespace: `pid:[4026532992]`; the identifiers differ.
- The process launched by `unshare --pid --fork` reported PID `1` inside the new PID namespace.
- `NSpid: 7 3` was reported by `/proc/self/status`; this is the kernel's namespace PID mapping for that process as exposed by this procfs view. It is not a contradiction of the shell's `$ = 1` output: `$` identifies the shell's PID in its active namespace, while `NSpid` lists IDs across the visible PID namespace hierarchy for the process represented by `/proc/self/status`.
- Child process PID `4` was started, `kill -0` confirmed it was running, and `wait` returned `0`.
- Nested user/PID namespace command exit status: `0`; outer Podman exit status: `0`.

**Interpretation**

- **What this proves:** In this exact SteamOS / rootless Podman / Debian 12 Slim configuration, the reduced capability set and default seccomp profile permitted creation of the nested user and PID namespaces, PID 1 operation for the namespace's init process, and a simple child-process start/check/wait lifecycle.
- **What this does not prove:** It does not establish LXC startup, Android init/service supervision, PID namespace signal/reaping edge cases, cgroup delegation, mount setup, Binder transactions, Waydroid startup, or GUI/GPU integration.
- **Security note:** No additional capability was needed for this tested namespace and process lifecycle operation. This is not a recommendation to grant more capabilities to a future container.

**Decision / next step**

- Mark Test 23 / PID namespace gate **CONFIRMED** for the limited operation tested.
- The next high-value blocker is cgroup behavior/delegation as seen from the disposable container. Investigate read-only first; do not alter host cgroup settings or enable delegation.
- Test 23 created no persistent container, host configuration, service, or network state.

---

#### Test 24 — completed: read-only cgroup v2 visibility and access audit

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **CONFIRMED — restricted/read-only cgroup view**
- **Environment:** Steam Deck host launching a disposable rootless Podman container
- **Image/runtime:** `docker.io/library/debian:12-slim`; rootless Podman; `--cap-drop=ALL`; `--network=none`; default seccomp
- **Prerequisites:** Host cgroup v2 baseline; earlier observation that a disposable container exposed a read-only cgroup2 mount; Tests 21–23 confirming nested user, mount and PID namespace operations under default seccomp.
- **Question:** What cgroup hierarchy, controllers and access are visible inside a minimal rootless Podman container, without attempting any write?
- **Why new:** This expands the prior brief observation into a read-only inventory of the cgroup namespace, membership, mount options, filesystem type, controller files, access checks and visible subdirectories.
- **Repeat policy:** Do not repeat unless Podman configuration, cgroup namespace/mount arrangement, host cgroup configuration, kernel or runtime changes.
- **Side-effect boundary:** Disposable container, `--rm`, `--network=none`, `--pull=never`, all capabilities dropped; inspection only. No cgroup writes, host configuration edits, delegation changes or service changes.

**Exact command executed**

```bash
podman run --rm --pull=never \
  --name waydroid-cgroup-audit-24 \
  --network=none \
  --cap-drop=ALL \
  docker.io/library/debian:12-slim \
  sh -c '
    echo "===== CONTAINER IDENTITY ====="
    id

    echo
    echo "===== CGROUP NAMESPACE ====="
    readlink /proc/self/ns/cgroup

    echo
    echo "===== PROCESS CGROUP MEMBERSHIP ====="
    cat /proc/self/cgroup

    echo
    echo "===== CGROUP MOUNT INFORMATION ====="
    grep -E " - cgroup2? " /proc/self/mountinfo || true

    echo
    echo "===== CGROUP FILESYSTEM TYPE ====="
    stat -f -c "Filesystem type: %T" /sys/fs/cgroup 2>&1

    echo
    echo "===== CGROUP ROOT DIRECTORY ====="
    ls -la /sys/fs/cgroup

    echo
    echo "===== CGROUP CONTROLLER FILES ====="

    for f in \
      /sys/fs/cgroup/cgroup.controllers \
      /sys/fs/cgroup/cgroup.subtree_control \
      /sys/fs/cgroup/cgroup.procs \
      /sys/fs/cgroup/cgroup.type \
      /sys/fs/cgroup/cgroup.events
    do
      echo
      echo "--- $f ---"

      if [ -e "$f" ]; then
        if [ -r "$f" ]; then
          echo "Readable: yes"
          cat "$f"
        else
          echo "Readable: no"
        fi

        if [ -w "$f" ]; then
          echo "Access check says writable: yes"
        else
          echo "Access check says writable: no"
        fi
      else
        echo "Not present"
      fi
    done

    echo
    echo "===== AVAILABLE CONTROLLER SUBDIRECTORIES ====="
    for d in /sys/fs/cgroup/*; do
      if [ -d "$d" ]; then
        echo "$d"
      fi
    done

    echo
    echo "===== CGROUP INSPECTION COMPLETE ====="
  '

PODMAN_EXIT=$?

echo
echo "===== OUTER PODMAN EXIT STATUS ====="
echo "Podman exit code: $PODMAN_EXIT"
```

**Actual output**

```text
===== CONTAINER IDENTITY =====
uid=0(root) gid=0(root) groups=0(root)

===== CGROUP NAMESPACE =====
cgroup:[4026532990]

===== PROCESS CGROUP MEMBERSHIP =====
0::/

===== CGROUP MOUNT INFORMATION =====
1696 1693 0:34 / /sys/fs/cgroup ro,nosuid,nodev,noexec,relatime,nosymfollow - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting

===== CGROUP FILESYSTEM TYPE =====
Filesystem type: cgroup2fs

===== CGROUP ROOT DIRECTORY =====
total 0
drwxr-xr-x  2 root   root    0 Nov  6 19:01 .
drwxr-xr-x 11 nobody nogroup 0 Nov  6 19:01 ..
-r--r--r--  1 root   root    0 Nov  6 19:01 cgroup.controllers
-r--r--r--  1 root   root    0 Nov  6 19:01 cgroup.events
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.freeze
--w-------  1 root   root    0 Nov  6 19:01 cgroup.kill
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.max.depth
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.max.descendants
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.pressure
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.procs
-r--r--r--  1 root   root    0 Nov  6 19:01 cgroup.stat
-r--r--r--  1 root   root    0 Nov  6 19:01 cgroup.stat.local
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.subtree_control
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.threads
-rw-r--r--  1 root   root    0 Nov  6 19:01 cgroup.type
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.idle
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.max
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.max.burst
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.pressure
-r--r--r--  1 root   root    0 Nov  6 19:01 cpu.stat
-r--r--r--  1 root   root    0 Nov  6 19:01 cpu.stat.local
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.uclamp.max
-rw-r--r--  1 root   root    0 Nov  6 19:01 cpu.uclamp.min
-rw-r--r--  1 root   root    0 Nov  6 19:01 io.pressure
-rw-r--r--  1 root   root    0 Nov  6 19:01 irq.pressure
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.current
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.events
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.events.local
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.high
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.low
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.max
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.min
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.numa_stat
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.oom.group
--w-------  1 root   root    0 Nov  6 19:01 memory.reclaim
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.swap.current
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.swap.events
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.swap.high
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.swap.max
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.swap.peak
-r--r--r--  1 root   root    0 Nov  6 19:01 memory.zswap.current
-rw-r--r--  1 root   root    0 Nov  6 19:01 memory.zswap.max
-r--r--r--  1 root   root    0 Nov  6 19:01 pids.current
-r--r--r--  1 root   root    0 Nov  6 19:01 pids.events
-r--r--r--  1 root   root    0 Nov  6 19:01 pids.events.local
-rw-r--r--  1 root   root    0 Nov  6 19:01 pids.max
-r--r--r--  1 root   root    0 Nov  6 19:01 pids.peak

===== CGROUP CONTROLLER FILES =====

--- /sys/fs/cgroup/cgroup.controllers ---
Readable: yes
cpu memory pids
Access check says writable: no

--- /sys/fs/cgroup/cgroup.subtree_control ---
Readable: yes
Access check says writable: no

--- /sys/fs/cgroup/cgroup.procs ---
Readable: yes
1
10
Access check says writable: no

--- /sys/fs/cgroup/cgroup.type ---
Readable: yes
domain
Access check says writable: no

--- /sys/fs/cgroup/cgroup.events ---
Readable: yes
populated 1
frozen 0
Access check says writable: no

===== AVAILABLE CONTROLLER SUBDIRECTORIES =====

===== CGROUP INSPECTION COMPLETE =====

===== OUTER PODMAN EXIT STATUS =====
Podman exit code: 0
```

**Observed result**

- Container process identity was `uid=0(root) gid=0(root)`; this is container namespace identity, not host root.
- Cgroup namespace was `cgroup:[4026532990]`.
- Process membership was `0::/`, so the process appears at the root of the cgroup namespace's visible hierarchy.
- Filesystem type was `cgroup2fs`, confirming unified cgroup v2.
- Mountinfo showed mount options `ro,nosuid,nodev,noexec,relatime,nosymfollow` before the separator and superblock options `rw,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting` after it. The mount itself is **read-only**; the `rw` superblock option does not override the mount-level `ro`.
- `cgroup.controllers` listed `cpu memory pids`.
- `cgroup.subtree_control` was readable and empty.
- `cgroup.procs` listed PIDs `1` and `10`; `cgroup.type` was `domain`; `cgroup.events` reported `populated 1` and `frozen 0`.
- The five inspected files were readable; the shell `-w` access checks all returned false.
- No controller subdirectories were visible.
- Podman exited with status `0`.

**Interpretation**

- **What this proves:** The disposable rootless container sees a cgroup v2 filesystem and a cgroup namespace, with CPU, memory and PID controller interfaces visible. The exposed cgroup mount is read-only from this container; the process sees itself at namespace-root membership, and no child cgroup directories are exposed.
- **Important mountinfo distinction:** The mount's per-mount options include `ro`; the superblock options include `rw`. Treat the mount as read-only for this container. Do not infer writable cgroup delegation from the superblock's `rw` token.
- **What this does not prove:** It does not establish whether the host's delegated cgroup parent could create a child cgroup, whether a different Podman configuration can expose a writable delegated subtree, whether LXC can manage its own cgroups, or whether Android's cgroup requirements can be met safely. No cgroup write was attempted.
- **Security note:** No cgroup mutation, host setting change, delegation enablement, or service change was attempted.

**Decision / next step**

- Mark Test 24 **CONFIRMED — read-only cgroup visibility**.
- Do not try to remount the exposed hierarchy or write to cgroup files from this container.
- Next, perform Test 25 as a read-only host-side inspection of the existing user/systemd cgroup delegation state and the exact cgroup path assigned to the rootless Podman process/container. Do not modify host cgroups or systemd properties.
- This is the fifth completed test since Test 20 (Tests 21–25). After Test 25 is documented, run the scheduled documentation consistency review and preserve an unchanged archive snapshot of the updated canonical audit.

---

#### Test 25 — completed: host cgroup delegation and Podman path inspection

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **PARTIALLY CONFIRMED — host path and unit properties observed; Podman info template query invalid; temporary-container cleanup must be verified**
- **Environment:** Steam Deck SteamOS host; rootless Podman; systemd user manager
- **Question:** Which host cgroup path contains the rootless Podman container, and which relevant systemd units report delegation?
- **Why new:** Test 24 showed a read-only cgroup2 mount inside the disposable container. Test 25 correlates that view with the host's writable cgroup2 mount, systemd unit properties and the actual container host PID/cgroup path.
- **Side-effect boundary:** Host inspection is read-only. A temporary inert container named `waydroid-cgroup-audit-25` was launched with `--rm`, `--network=none`, and `--cap-drop=ALL`. No cgroup or systemd setting was modified.
- **Repeat policy:** Do not repeat the host path/unit inspection unless systemd, Podman, cgroup layout or runtime configuration changes. The failed Podman info format query may be corrected separately if the manager/version value remains necessary.

**Exact command executed**

```bash
echo "===== HOST CGROUP BASELINE ====="
echo "UID: $(id -u)"
echo "User cgroup membership:"
cat /proc/self/cgroup

echo
echo "===== HOST CGROUP MOUNT ====="
findmnt -T /sys/fs/cgroup -o TARGET,FSTYPE,OPTIONS

echo
echo "===== PODMAN CGROUP CONFIGURATION ====="
podman info --format 'Cgroup version: {{.Host.CgroupVersion}}
Cgroup manager: {{.Host.CgroupManager}}'

echo
echo "===== SYSTEMD USER SLICE ====="
UID_NUM=$(id -u)

systemctl show "user.slice" \
  -p ActiveState \
  -p ControlGroup \
  -p Delegate

systemctl show "user-${UID_NUM}.slice" \
  -p ActiveState \
  -p ControlGroup \
  -p Delegate

systemctl show "user@${UID_NUM}.service" \
  -p ActiveState \
  -p ControlGroup \
  -p Delegate

echo
echo "===== START TEMPORARY PODMAN INSPECTION CONTAINER ====="

CONTAINER_NAME="waydroid-cgroup-audit-25"

cleanup() {
  echo
  echo "===== TEMPORARY CONTAINER CLEANUP ====="
  podman stop "$CONTAINER_NAME" 2>&1 || true
}

trap cleanup EXIT

podman run -d --rm \
  --pull=never \
  --name "$CONTAINER_NAME" \
  --network=none \
  --cap-drop=ALL \
  docker.io/library/debian:12-slim \
  sleep 180

RUN_RESULT=$?

if [ "$RUN_RESULT" -ne 0 ]; then
  echo "ERROR: Temporary container failed to start"
  exit "$RUN_RESULT"
fi

echo
echo "===== PODMAN CONTAINER INSPECTION ====="

CONTAINER_PID=$(podman inspect --format '{{.State.Pid}}' "$CONTAINER_NAME")
echo "Host PID: $CONTAINER_PID"

echo
echo "===== CONTAINER HOST CGROUP MEMBERSHIP ====="
cat "/proc/${CONTAINER_PID}/cgroup"

echo
echo "===== CONTAINER CGROUP NAMESPACE ====="
readlink "/proc/${CONTAINER_PID}/ns/cgroup"

echo
echo "===== CONTAINER HOST MOUNT NAMESPACE ====="
readlink "/proc/${CONTAINER_PID}/ns/mnt"

echo
echo "===== CONTAINER SYSTEMD UNIT / SCOPE ====="
systemd-cgls --no-pager 2>&1 | grep -E -C 3 \
  "libpod|podman|${CONTAINER_PID}" || true

echo
echo "===== HOST CGROUP INSPECTION COMPLETE ====="
```

**Actual output**

```text
===== HOST CGROUP BASELINE =====
UID: 1000
User cgroup membership:
0::/user.slice/user-1000.slice/session-10.scope

===== HOST CGROUP MOUNT =====
TARGET         FSTYPE  OPTIONS
/sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting

===== PODMAN CGROUP CONFIGURATION =====
Cgroup version: Error: template: info:1:23: executing "info" at <.Host.CgroupVersion>: can't evaluate field CgroupVersion in type *define.HostInfo

===== SYSTEMD USER SLICE =====
ActiveState=active
ControlGroup=/user.slice
Delegate=no
ActiveState=active
ControlGroup=/user.slice/user-1000.slice
Delegate=no
ActiveState=active
ControlGroup=/user.slice/user-1000.slice/user@1000.service
Delegate=yes

===== START TEMPORARY PODMAN INSPECTION CONTAINER =====
9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997

===== PODMAN CONTAINER INSPECTION =====
Host PID: 299655

===== CONTAINER HOST CGROUP MEMBERSHIP =====
0::/user.slice/user-1000.slice/user@1000.service/user.slice/libpod-9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997.scope/container

===== CONTAINER CGROUP NAMESPACE =====
cgroup:[4026532990]

===== CONTAINER HOST MOUNT NAMESPACE =====
mnt:[4026532877]

===== CONTAINER SYSTEMD UNIT / SCOPE =====
│   │ ├─264539 sshd-session: deck@pts/0
│   │ ├─264541 -bash
│   │ ├─299764 systemd-cgls --no-pager
│   │ └─299765 grep --color=auto -E -C 3 libpod|podman|299655
│   ├─user@1000.service …
│   │ ├─session.slice
--
│   │ │ └─kde-baloo.service
│   │ │   └─18905 /usr/lib/kf6/baloo_file
│   │ ├─user.slice
│   │ │ ├─podman-pause-0cd3be5c.scope
│   │ │ │ └─1948 catatonit -P
│   │ │ ├─libpod-9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997.scope
│   │ │ │ └─container
│   │ │ │   └─299655 sleep 180
│   │ │ ├─libpod-dd33930cdcdd76eee0cb53e58be38495d2f1a7d08d85b1c633d00ccd727d6105.scope
│   │ │ │ └─container
│   │ │ │   ├─1985 /bin/bash /usr/bin/start.sh
│   │ │ │   ├─2045 /bin/bash /usr/bin/start.sh
│   │ │ │   ├─2086 /bin/bash -c /usr/bin/pihole-FTL no-daemon >/dev/null
│   │ │ │   ├─2090 /usr/bin/pihole-FTL no-daemon
│   │ │ │   └─2554 tail -F -c +1414 -- /var/log/pihole/FTL.log
│   │ │ ├─podman-299631.scope
│   │ │ │ └─299647 /usr/bin/fuse-overlayfs -o lowerdir=/home/deck/.local/share/…
│   │ │ └─libpod-conmon-9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997.scope
│   │ │   └─299651 /usr/bin/conmon --api-version 1 -c 9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997.scope
│   ├─app.slice
│   │ ├─speech-dispatcher.service

===== HOST CGROUP INSPECTION COMPLETE =====
```

**Observed result and interpretation**

- Host UID was `1000`; interactive shell membership was `/user.slice/user-1000.slice/session-10.scope`.
- Host `/sys/fs/cgroup` was cgroup2 and mounted `rw`.
- The Podman info template failed because this Podman build's `.Host` structure does not expose the requested `CgroupVersion` field. The command therefore did **not** establish the Podman cgroup version/manager. This is a query/template error, not a Podman runtime failure.
- `user.slice` and `user-1000.slice` reported `Delegate=no`; `user@1000.service` reported `Delegate=yes`.
- Temporary container host PID was `299655`. Its host cgroup membership was:
  `/user.slice/user-1000.slice/user@1000.service/user.slice/libpod-9e0a1b11bcfa2ebfe7773ff55229141ae32c7150343e7c55c78936a1d11a6997.scope/container`.
- This places the container under the user manager's delegated service subtree, nested below its own `user.slice` and a Podman-created `libpod-….scope`.
- Container cgroup namespace was `cgroup:[4026532990]`; mount namespace was `mnt:[4026532877]`. These inode values can be reused after namespace teardown and should not be treated as stable identifiers.
- `systemd-cgls` showed the temporary container scope and the existing Pi-hole scope. The command was observational; no Pi-hole process was targeted or modified.
- The command defined `trap cleanup EXIT`, but because it was pasted into an already-running interactive shell, the shell itself did not exit at the end of the command list. The output does **not** show the cleanup trap running. Therefore the temporary `sleep 180` container may still be present; verify and stop it explicitly before proceeding.
- The systemd unit's `Delegate=yes` does not negate Test 24's read-only mount inside the container. It indicates delegation at the user service boundary, not that the particular Podman container has a writable cgroup mount or usable child delegation.
- No cgroup writes or systemd changes were attempted.

**Decision / next step**

- Mark Test 25 **PARTIALLY CONFIRMED**: host cgroup path and unit delegation properties were observed; the Podman info template field query was invalid; temporary-container cleanup remains unverified.
- First verify and clean up the temporary container named `waydroid-cgroup-audit-25`.
- Then, if the Podman cgroup version/manager remains useful, obtain it with a supported read-only `podman info` output format (e.g. inspect JSON keys rather than assuming template fields). This can be a small supplemental query, not a repeat of the host path test.
- After cleanup and documentation verification, the five-test checkpoint (Tests 21–25) requires a consistency review and an unchanged archive snapshot of the updated canonical audit. Do not alter host cgroup or systemd settings.


**Test 25 cleanup follow-up — completed**

- **Verification result:** The temporary container `waydroid-cgroup-audit-25` was still present when checked.
- **Action:** `podman stop waydroid-cgroup-audit-25` was issued. Podman reported that SIGTERM did not stop it within 10 seconds and escalated to SIGKILL.
- **Final verification:** The subsequent `podman ps -a --filter name=^waydroid-cgroup-audit-25$` returned no rows. The named temporary container is therefore absent.
- **Impact:** Cleanup is confirmed. This is not a new feasibility test and does not change the Test 25 cgroup-path findings. The forced SIGKILL is limited to the disposable test container; no Pi-hole container or host service was targeted.
- **Operational note:** The earlier interactive-shell `EXIT` trap did not run; explicit cleanup was necessary. Future pasted interactive-shell blocks must not assume an `EXIT` trap will execute at the end of a compound command list.


---

### 5.6 Networking

| Test ID | Environment / procedure | Actual result | Status |
|---|---|---|---|
| NET-01 | Host network tools inventory (`ip`, `iptables`, `nft`, `pasta`, `dnsmasq`, `netavark`) | Most tools present; host dnsmasq absent | HISTORICAL |
| NET-02 | Host `sysctl net.ipv4.ip_forward` | `0` | HISTORICAL |
| NET-03 | Private host user/network namespace; bridge | Passed | CONFIRMED |
| NET-04 | Same private namespace; `ip_forward=1`, bridge, NAT chain/rule and cleanup | Passed | CONFIRMED |
| NET-05 | Disposable Debian container on Podman network; outbound/DNS test | Passed | CONFIRMED |
| NET-06 | Podman container with `NET_ADMIN`; set `net.ipv4.ip_forward=1` | Permission denied | CONFIRMED FAILURE |
| NET-07 | Bridge/NAT after failed sysctl | Not reached | UNTESTED |
| NET-08 | Host forwarding after test | Remained `0` | CONFIRMED |
| NET-09 | Full Waydroid Android network | Not tested | UNTESTED |

**Do not repeat NET-03/04 or broad host network inventory.** If networking is revisited, target NET-07 in a disposable boundary and establish whether the test is meaningful without changing host forwarding or Pi-hole. Preserve before/after checks and cleanup evidence.

### 5.7 Outer container security inspection

Historical inspection included:

- Effective UID/GID maps.
- `CapInh`, `CapPrm`, `CapEff`, `CapBnd`.
- `NoNewPrivs`, `Seccomp`, seccomp filter count.
- `/proc/self/attr/current` where available.
- Mount list and namespace identities.
- Podman runtime and security configuration.
- Existing Distrobox privilege, host namespace and mount settings.

Findings:

- Existing Distroboxes were highly permissive and are not a template.
- Rootless Podman alone is not a sufficient security guarantee if the container receives broad host mounts or host namespaces.
- Nested namespace creation is possible with a capability set, but capability minimization remains incomplete.
- Disabling seccomp alone or changing `no_new_privs` alone did not resolve the earlier UID mapping failure.

**Repeat policy:** do not re-audit existing Distroboxes. For a future candidate Waydroid container, inspect the exact effective config before launch and after every material change.

---

### 5.6 Five-test consistency review — Tests 21–25

**Review date:** 2026-11-06  
**Scope:** Documentation cross-check after the fifth completed test since Test 20. This review does not rerun any host/container experiment.

| Test | Cross-check | Review conclusion |
|---|---|---|
| Test 21 | Default seccomp is evidenced by `Seccomp: 2`; retained capability mask is `00000000800000c0`; inner and outer exit statuses are zero. | **CONSISTENT** — confirms only the tested nested user-namespace operation. |
| Test 22 | Parent/child mount namespace IDs differ; `unshare --mount` returned success. The shell comparison guard emitted `[: missing ]`. | **CONSISTENT WITH QUALIFICATION** — namespace creation is supported by IDs and operation result; the malformed guard is not valid evidence. |
| Test 23 | Parent/child PID namespace IDs differ; nested process reported PID 1; child process was observed and waited for; both reported exit statuses are zero. | **CONSISTENT** — confirms the limited namespace and child-lifecycle operation, not LXC. |
| Test 24 | Mountinfo shows per-mount `ro`; cgroup v2 controllers `cpu memory pids` are visible; subtree control is empty; no child cgroup directories are exposed. | **CONSISTENT** — read-only cgroup visibility is established; writable delegation is not. |
| Test 25 | Host cgroup mount and systemd unit/path observations are recorded; unsupported `.Host.CgroupVersion` template query did not identify manager/version. A separate cleanup follow-up confirms SIGTERM timeout, SIGKILL escalation, and an empty filtered container listing. | **PARTIAL TEST / CONFIRMED CLEANUP** — no runtime failure is implied by the unsupported query; cleanup is verified. |

**Cross-test interpretation**

- Tests 21–23 establish specific nested namespace primitives under the tested capability set and default seccomp profile; they do not establish LXC compatibility.
- Test 24 establishes that the cgroup mount exposed to the disposable container is read-only. The superblock's `rw` token does not override the mount's per-mount `ro` option.
- Test 25 establishes the observed host path and systemd properties only. `Delegate=yes` on `user@1000.service` does not prove the nested container has a writable delegated cgroup subtree.
- No test authorizes host cgroup/systemd changes, privileged mode, broad host mounts, or changes to protected projects.
- The Test 25 cleanup follow-up is a separate confirmed result; it does not upgrade the unsupported Podman info query to a pass.

**Documentation corrections made in v1.8**

1. Updated the executive remaining-gate list so Tests 21–23 are not presented as still pending.
2. Renumbered the dependency table contiguously and corrected downstream gate references.
3. Replaced the stale “five-test review/archive pending” handoff with the current read-only Podman JSON query as the next action.
4. Preserved the pre-edit v1.7 canonical document unchanged at `archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.7.md`.

**Next action:** Run the supplemental read-only Podman JSON query. It addresses Gate 3 and must not repeat the completed host cgroup/path inspection. Do not modify host cgroup or systemd settings.


### 5.8 Supplemental Gate 3 — read-only Podman JSON configuration query

- **Date:** 2026-11-06 (user-reported execution date)
- **Status:** **CONFIRMED — query and JSON inspection succeeded**
- **Environment:** Steam Deck host (`deck@Laco`), not inside Distrobox or a Podman container
- **Prerequisites:** Test 25; Gate 3 supplemental query
- **Question:** What cgroup manager/version and OCI runtime does the active Podman installation report?
- **Why new:** Test 25's Go-template expression used an unsupported field (`.Host.CgroupVersion`). This query reads the supported JSON representation and does not repeat the host cgroup path or container mount inspection.
- **Side-effect boundary:** Read-only `podman info --format json` plus local Python JSON parsing. No container was started or stopped; no cgroup, systemd, service, mount, or persistent configuration was changed.
- **Repeat policy:** Do not repeat unless Podman, crun, SteamOS, or the cgroup configuration changes.

**Exact command executed**

```bash
echo "===== PODMAN INFO JSON — READ-ONLY AUDIT ====="

PODMAN_JSON=$(podman info --format json)
PODMAN_STATUS=$?

echo
echo "===== PODMAN COMMAND STATUS ====="
echo "Exit code: $PODMAN_STATUS"

if [ "$PODMAN_STATUS" -ne 0 ]; then
    echo
    echo "ERROR: Podman info query failed."
    echo "Preserve the error output; do not change Podman configuration."
    exit "$PODMAN_STATUS"
fi

echo
echo "===== RELEVANT PODMAN JSON FIELDS ====="

printf '%s\\n' "$PODMAN_JSON" | python -c '
import json, sys

data = json.load(sys.stdin)

def inspect(obj, prefix=""):
    if isinstance(obj, dict):
        for key, value in obj.items():
            path = f"{prefix}.{key}" if prefix else key

            if any(term in key.lower() for term in
                   ("cgroup", "runtime", "version")):
                print(f"{path} = {value}")

            if isinstance(value, (dict, list)):
                inspect(value, path)

    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            inspect(value, f"{prefix}[{index}]")

print("Top-level keys:", sorted(data.keys()))
print()
inspect(data)
'

PYTHON_STATUS=$?

echo
echo "===== JSON INSPECTION STATUS ====="
echo "Python exit code: $PYTHON_STATUS"

echo
echo "===== INSPECTION COMPLETE ====="
```

**Actual relevant output**

```text
===== PODMAN COMMAND STATUS =====
Exit code: 0

===== RELEVANT PODMAN JSON FIELDS =====
Top-level keys: ['host', 'plugins', 'registries', 'store', 'version']

host.cgroupManager = systemd
host.cgroupVersion = v2
host.cgroupControllers = ['cpu', 'memory', 'pids', 'dmem']
host.ociRuntime = {'name': 'crun', 'package': 'crun-1.28-1', 'path': '/usr/bin/crun', 'version': 'crun version 1.28-dirty
commit: 54f16ffbefcd022bf032af768b5c5ce075c18bfc
rundir: /run/user/1000/crun
spec: 1.0.0
+SYSTEMD +SELINUX +APPARMOR +CAP +SECCOMP +EBPF +CRIU +LIBKRUN +JSON_C'}
version.APIVersion = 6.0.2
version.Version = 6.0.2
version.GoVersion = go1.26.5-X:nodwarf5

===== JSON INSPECTION STATUS =====
Python exit code: 0
```

**Observed result**

- Podman reports version `6.0.2` and API version `6.0.2`.
- `host.cgroupManager` is `systemd`.
- `host.cgroupVersion` is `v2`.
- Host-reported cgroup controllers are `cpu`, `memory`, `pids`, and `dmem`.
- OCI runtime is `crun 1.28-dirty`, package `crun-1.28-1`, path `/usr/bin/crun`.
- Podman command exit status: `0`; Python JSON inspection exit status: `0`.

**Interpretation**

- **What this proves:** the active Podman installation reports the manager, cgroup version, controller list, engine version, and OCI runtime shown above.
- **What this does not prove:** that those controllers are delegated to a rootless container, that the cgroup mount inside that container is writable, or that LXC can create/manage nested cgroups.
- The controller list is host-level Podman information. It must not be treated as proof that every controller is available inside the container.
- Combined with Test 24, the decisive observed boundary remains the container's cgroup2 mount with per-mount `ro`, empty `cgroup.subtree_control`, no visible child cgroups, and no writable controller files.
- Combined with Test 25, `user@1000.service` reporting `Delegate=yes` and Podman using systemd do not prove writable delegation to the nested container.

**Decision**

- Gate 3 is complete.
- Gate 2 remains blocked under the observed configuration.
- A disposable LXC experiment is **not justified at this stage**: the required cgroup boundary has not been demonstrated, and trying to overcome it would risk widening permissions or changing host cgroup/systemd configuration. No LXC package was installed, no LXC container was created, and no host setting was changed.
- Reopen only if a relevant runtime/SteamOS change or reliable version-matched technical evidence establishes a secure rootless LXC path that does not require host changes or broader privileges.

### 5.9 LXC package metadata and file-manifest audit

#### LXC-PKG-01 — completed: Deck-local package candidate and transaction audit

- **Date:** 2026-11-07 (reported in the preceding ChatGPT session)
- **Status:** **CONFIRMED AS REPORTED — package candidate and print-only transaction**
- **Environment:** Steam Deck SteamOS host (deck@Laco)
- **Question:** Is an LXC package available from the Deck's configured SteamOS repositories, and what would the package manager install?
- **Why new:** Phase 1.5 source review established that an isolated LXC runtime test might be a separate audit instrument. This check evaluates the Deck's own configured package metadata rather than inferring from upstream Arch metadata.
- **Side-effect boundary:** Package metadata query and print-only transaction only. No package installation, upgrade, removal, service activation or configuration change.
- **Evidence provenance:** The user supplied the preceding assistant's summarized result, not the complete raw PKG-01 command/output. Preserve the values below as reported; do not represent the raw transcript as independently rechecked in this continuation.
- **Repeat policy:** Repeat only if SteamOS build/branch or configured repositories change, or if the package candidate/transaction needs revalidation immediately before an explicitly approved installation.

**Reported result**

| Item | Result |
|---|---|
| Candidate | lxc |
| Version | 1:7.0.0-1 |
| Repository | extra-3.9 |
| Download size | 832.72 KiB |
| Installed size | 2,827.64 KiB |
| Proposed transaction | lxc only |
| Required dependencies | All seven listed dependencies already installed |
| Optional dnsmasq | Not installed; optional for lxc-net.service, not required for the LXC package itself |

**Interpretation**

- The reported sync-database query found an LXC candidate in the Deck's configured extra-3.9 repository.
- The reported print-only transaction proposed only lxc; no dependency installation or upgrade was proposed.
- This is package metadata evidence only. It does not establish that LXC will run, that a delegated cgroup is available, or that Waydroid can be deployed securely.
- The optional dnsmasq package and lxc-net.service are outside this audit. Do not install dnsmasq, enable LXC network helpers, or start LXC services.
- Installation remains **NOT APPROVED**. Any future installation requires a separate bounded plan and explicit user approval.

#### LXC-PKG-02 — attempted: package file manifest unavailable locally

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **PARTIAL / BLOCKED — local file-list databases absent; package contents not inspected**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** LXC-PKG-01 reported candidate and one-package print-only transaction
- **Question:** Which executables, systemd units, hooks, configuration files and network helpers are supplied by this exact SteamOS LXC package?
- **Why new:** The package candidate and transaction do not reveal the package's installed file manifest or host-integration surface.
- **Side-effect boundary:** The attempted commands were package metadata/list queries. No install, file-list database refresh, service action or configuration edit was performed.
- **Repeat policy:** Do not repeat pacman -Fl until the relevant repository file-list database has been made available. Do not use pacman -Fy without first explaining that it downloads and writes package file-list metadata into the local pacman cache.

**Exact command executed**

~~~bash
echo "===== LXC-PKG-02: PACKAGE CONTENTS AUDIT ====="

echo
echo "===== 1. PACKAGE FILE MANIFEST ====="
pacman -Fl lxc

echo
echo "===== 2. SERVICE AND SOCKET FILES ====="
pacman -Fl lxc | grep -Ei \
  'systemd|\.service$|\.socket$|\.timer$|preset|tmpfiles|sysusers'

echo
echo "===== 3. NETWORK AND FIREWALL COMPONENTS ====="
pacman -Fl lxc | grep -Ei \
  'lxc-net|dnsmasq|iptables|nftables|network'

echo
echo "===== 4. EXECUTABLES ====="
pacman -Fl lxc | grep -E '/(bin|sbin)/'

echo
echo "===== 5. PACKAGE INSTALL SCRIPT METADATA ====="
pacman -Si lxc | grep -Ei \
  '^(Name|Version|Depends On|Optional Deps|Install Script)'

echo
echo "===== END LXC-PKG-02 ====="
~~~

**Actual output**

~~~text
===== LXC-PKG-02: PACKAGE CONTENTS AUDIT =====

===== 1. PACKAGE FILE MANIFEST =====
warning: database file for 'jupiter-3.9' does not exist (use '-Fy' to download)
warning: database file for 'holo-3.9' does not exist (use '-Fy' to download)
warning: database file for 'core-3.9' does not exist (use '-Fy' to download)
warning: database file for 'extra-3.9' does not exist (use '-Fy' to download)
warning: database file for 'multilib-3.9' does not exist (use '-Fy' to download)
error: package 'lxc' was not found
Connection to deck closed.
PS C:\Users\Laco>
~~~

**Observed result**

- The configured repository file-list databases were absent locally for jupiter-3.9, holo-3.9, core-3.9, extra-3.9 and multilib-3.9.
- pacman -Fl lxc therefore could not find the package in the local file-list metadata and returned the package-not-found error.
- The warning explains the missing prerequisite and identifies pacman -Fy as the mechanism to download file-list metadata.
- This does **not** establish that the LXC package is absent from the sync databases; it does not contradict LXC-PKG-01's reported pacman -Si candidate and print-only transaction.
- The transcript ends with the SSH connection closing. No evidence was supplied that the Deck rebooted, crashed, installed a package or changed configuration. Do not infer a causal relationship between the metadata query and the connection closure.
- The supplied transcript shows only the first manifest invocation's output before the connection closed. Do not infer unseen output from later pipelines.
- No file-list database refresh was attempted; no package contents were retrieved.

**Interpretation**

- **What this proves:** the local pacman file-list databases needed by pacman -Fl were not present at the time of the command.
- **What this does not prove:** that the package candidate disappeared, that the sync databases are invalid, that the package cannot be downloaded, or that any LXC executable/service/hook is installed.
- Keep package sync metadata and package file-list metadata conceptually separate: the former supported the reported -Si / -Sp result; the latter was unavailable to -Fl.
- No install, service activation, network helper, cgroup change or persistent host configuration change occurred.

**Decision / next step**

- Preserve LXC-PKG-01 as a favourable package-candidate/transaction result, with its raw-output provenance limitation.
- Mark LXC-PKG-02 **PARTIAL / BLOCKED**; package contents remain unknown.
- Do not install LXC, dnsmasq or any Waydroid package.
- The next possible step is a narrowly scoped file-list metadata refresh for extra-3.9 using pacman -Fy extra-3.9, followed by pacman -Fl lxc and targeted manifest filtering. This is **not a strictly read-only operation**: it downloads and writes repository file-list metadata to the local pacman cache, but does not install or upgrade packages. Obtain the user's approval for this metadata-only cache change before running it. If the user does not approve, stop here and retain the manifest as uninspected.
- After a successful manifest retrieval, inspect the package's exact service/unit, network/firewall, executable, configuration and install-script footprint. Only then decide whether a bounded LXC-only installation proposal is warranted. No installation is authorized by this result.


#### LXC-PKG-03 — attempted: metadata refresh blocked by pacman database lock

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **PARTIAL / BLOCKED — rootless invocation rejected; privileged invocation could not acquire the pacman database lock**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** User explicitly approved only the metadata-only operation `pacman -Fy extra-3.9`; no package installation or upgrade was included.
- **Question:** Can the missing `extra-3.9` file-list metadata be downloaded so that the LXC package manifest can be inspected?
- **Why new:** LXC-PKG-02 established that the file-list databases were missing. This attempt tested the narrowly approved metadata-refresh prerequisite; it did not repeat the package-candidate query.
- **Side-effect boundary:** The first invocation was rejected before performing the operation because it lacked root privileges. The sudo invocation began the synchronization stage but failed to acquire the pacman database lock. No successful refresh is evidenced. No package installation, upgrade, service action or configuration edit was requested or performed.
- **Repeat policy:** Do not retry `pacman -Fy` until the lock state and any active package-management process have been checked read-only. Never remove a lock file merely to force progress.

**Exact commands executed**

~~~bash
echo "===== LXC-PKG-03: FILE-LIST DATABASE REFRESH ====="

pacman -Fy extra-3.9

echo
echo "===== END LXC-PKG-03 ====="
~~~

The user then separately ran:

~~~bash
sudo pacman -Fy extra-3.9
~~~

**Actual output**

~~~text
===== LXC-PKG-03: FILE-LIST DATABASE REFRESH =====
error: you cannot perform this operation unless you are root.

===== END LXC-PKG-03 =====
(deck@Laco ~)$ sudo pacman -Fy extra-3.9
[sudo] password for deck:
:: Synchronizing package databases...
error: failed to synchronize all databases (unable to lock database)
(deck@Laco ~)$
~~~

**Observed result**

- The unprivileged invocation was rejected because the operation requires root.
- The privileged invocation passed the privilege check and reached repository synchronization, but pacman reported that it could not lock the database.
- The output does not identify why the lock could not be acquired. An existing pacman lock file or another package-management process are possibilities, not confirmed causes.
- Because the lock could not be acquired, the requested file-list refresh did not complete. Do not assume that any repository file-list database was updated.
- The output contains no evidence of an LXC installation, package upgrade, service activation, or host configuration change.
- No lock file was removed and no competing process was stopped.

**Interpretation**

- **What this proves:** the first command lacked required privileges; the sudo invocation could not acquire the pacman database lock.
- **What this does not prove:** that the lock file is stale, that another package manager is running, that repository metadata is corrupt, or that the LXC candidate is unavailable.
- The approval for this test remains limited to `pacman -Fy extra-3.9`. It does not authorize deleting a lock, terminating a package process, refreshing all repositories, upgrading packages, or installing LXC.

**Decision / next step**

- Keep LXC-PKG-02 **PARTIAL / BLOCKED**; the manifest remains uninspected.
- Record LXC-PKG-03 as **PARTIAL / BLOCKED**; the approved metadata refresh did not complete.
- Before any retry, perform a read-only inspection of pacman-related processes and the lock path `/var/lib/pacman/db.lck`. Do not remove the lock or stop any process.
- Only if the read-only evidence establishes that no package-management operation is active and the lock condition is safely resolved should a retry be proposed. Any lock removal would require separate explicit approval.
- After a successful metadata refresh, run the manifest inspection as a new test ID. No installation is authorized by this result.


#### LXC-PKG-04 — read-only pacman process and lock-path diagnosis

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED — no matching package-management process and no pacman lock file at the queried path; original lock failure remains unexplained**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** LXC-PKG-03's privileged `pacman -Fy extra-3.9` invocation failed with `unable to lock database`.
- **Question:** Was a matching package-management process visible, and did the standard pacman database lock path exist at the time of inspection?
- **Why new:** This is the requested read-only diagnosis after LXC-PKG-03; it does not repeat the failed refresh or package-candidate query.
- **Side-effect boundary:** Process listing and filesystem metadata query only. No lock file was created or removed; no process was stopped; no package operation was attempted.

**Exact command executed**

~~~bash
echo "===== LXC-PKG-04: PACMAN LOCK DIAGNOSIS ====="

echo
echo "===== 1. PACKAGE-MANAGEMENT PROCESSES ====="
ps -eo pid,ppid,stat,etime,args \
  | grep -Ei '[p]acman|[p]ackagekit|[p]amac' \
  || echo "No matching package-management process found."

echo
echo "===== 2. PACMAN DATABASE LOCK ====="
sudo stat -c \
  'Path=%n Type=%F Owner=%U Group=%G Mode=%a Size=%s Modified=%y' \
  /var/lib/pacman/db.lck \
  2>&1

echo
echo "===== END LXC-PKG-04 ====="
~~~

**Actual output**

~~~text
===== LXC-PKG-04: PACMAN LOCK DIAGNOSIS =====

===== 1. PACKAGE-MANAGEMENT PROCESSES =====
No matching package-management process found.

===== 2. PACMAN DATABASE LOCK =====
stat: cannot statx '/var/lib/pacman/db.lck': No such file or directory

===== END LXC-PKG-04 =====
(deck@Laco ~)$
~~~

**Observed result**

- The process query found no matching `pacman`, `packagekit` or `pamac` process at the time of inspection.
- `/var/lib/pacman/db.lck` did not exist at the time of the `stat` query.
- The result is a point-in-time observation. It does not prove that no process was active when LXC-PKG-03 ran, nor does it establish why pacman reported that it could not lock the database.
- The missing lock file is not itself an error and must not be created or deleted manually.
- No package database refresh or installation was performed during LXC-PKG-04.

**Interpretation**

- **What this proves:** no matching process was visible and no lock file existed at the queried standard path during this inspection.
- **What this does not prove:** that the prior lock failure was caused by a stale lock, a live process, filesystem permissions, a read-only mount, a nonstandard pacman DBPath, or any other specific cause.
- The failed refresh remains incomplete; the local file-list metadata must still be treated as unavailable until a successful refresh is evidenced.

**Decision / next step**

- Mark LXC-PKG-04 **COMPLETED** as a read-only diagnostic test.
- Keep LXC-PKG-02 and LXC-PKG-03 **PARTIAL / BLOCKED**; the LXC manifest remains uninspected.
- Next perform a second, strictly read-only diagnostic of the configured pacman DBPath, its parent-directory permissions and the filesystem mount options. Do not create test files, remove locks, remount filesystems, change permissions, terminate processes or retry `pacman -Fy` yet.
- If the next diagnostic still does not explain the failure, stop and reassess rather than forcing the package database operation.


### LXC-PKG-05 — read-only configured pacman DBPath and filesystem diagnostic

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED — configured DBPath identified; queried /var/lib/pacman path was not the configured database directory; actual database-directory permissions and mount options remain uninspected**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** LXC-PKG-04 found no matching package-management process and no lock file at the assumed /var/lib/pacman/db.lck path after LXC-PKG-03's unable to lock database error.
- **Question:** What database path does pacman actually use, and what do the directory and mount diagnostics show?
- **Why new:** LXC-PKG-04 checked a conventional Arch path without first confirming SteamOS's configured DBPath. This test reads pacman's effective configuration and checks the previously assumed path; it does not repeat the earlier process query.
- **Side-effect boundary:** Read-only configuration, directory, metadata and mount queries. No file was created or removed; no permissions or mount state were changed; no package operation was attempted.
- **Repeat policy:** Do not repeat unless the SteamOS build/configuration changes or a later diagnostic needs to verify a changed DBPath.

**Exact command executed**

~~~bash
echo "===== LXC-PKG-05: PACMAN DATABASE PATH DIAGNOSTIC ====="

echo
echo "===== 1. CONFIGURED PACMAN DBPATH ====="
pacman-conf DBPath

echo
echo "===== 2. DIRECTORY PERMISSIONS ====="
ls -ld /var /var/lib /var/lib/pacman
namei -l /var/lib/pacman

echo
echo "===== 3. DATABASE DIRECTORY METADATA ====="
sudo stat -c \
  'Path=%n Type=%F Owner=%U Group=%G Mode=%a' \
  /var/lib/pacman

echo
echo "===== 4. FILESYSTEM MOUNT OPTIONS ====="
findmnt -T /var/lib/pacman -o TARGET,FSTYPE,OPTIONS

echo
echo "===== END LXC-PKG-05 ====="
~~~

**Actual output**

~~~text
===== LXC-PKG-05: PACMAN DATABASE PATH DIAGNOSTIC =====

===== 1. CONFIGURED PACMAN DBPATH =====
/usr/lib/holo/pacmandb

===== 2. DIRECTORY PERMISSIONS =====
ls: cannot access '/var/lib/pacman': No such file or directory
drwxr-xr-x 14 root root 1024 Oct 24 01:35 /var
drwxr-xr-x 42 root root 1024 Oct 24 01:35 /var/lib
f: /var/lib/pacman
dr-xr-xr-x root root /
drwxr-xr-x root root var
drwxr-xr-x root root lib
                      pacman - No such file or directory

===== 3. DATABASE DIRECTORY METADATA =====
stat: cannot statx '/var/lib/pacman': No such file or directory

===== 4. FILESYSTEM MOUNT OPTIONS =====

===== END LXC-PKG-05 =====
(deck@Laco ~)$
~~~

**Observed result**

- pacman-conf DBPath returned /usr/lib/holo/pacmandb.
- The queried /var/lib/pacman directory does not exist. ls, namei and stat consistently reported that the path was absent.
- Because findmnt -T was also given the nonexistent /var/lib/pacman path, it returned no mount row. No mount options for the configured database directory were collected.
- The command did not inspect /usr/lib/holo/pacmandb, its parent-directory permissions, or a lock file beneath the configured DBPath.
- No package database refresh or installation was performed.

**Interpretation**

- **What this proves:** the effective pacman database path is /usr/lib/holo/pacmandb; the earlier LXC-PKG-04 check of /var/lib/pacman/db.lck was aimed at a nonexistent, non-configured location and therefore did not inspect the actual pacman lock path.
- **What this does not prove:** whether a lock file exists under the configured DBPath; whether the configured path or its parents are writable; whether the relevant filesystem is mounted read-only; or why LXC-PKG-03 failed to acquire the database lock.
- Correct the interpretation of LXC-PKG-04: its process-list result remains valid as a point-in-time observation, but its lock-path observation is **SUPERSEDED as a diagnostic of pacman's active database**, because it queried the wrong path.
- The original lock failure remains **INCONCLUSIVE**. Do not infer a stale lock, permission fault or read-only mount from this test.

**Decision / next step**

- Mark LXC-PKG-05 **COMPLETED** as a read-only configuration/path diagnostic.
- Keep LXC-PKG-02 and LXC-PKG-03 **PARTIAL / BLOCKED**; the package manifest remains uninspected.
- Next perform a narrowly scoped read-only inspection of /usr/lib/holo/pacmandb, its parent path, the mount containing it, and the candidate lock path derived from the configured DBPath. Do not create/remove files, change permissions, remount, terminate processes or retry pacman -Fy.
- The user's prior approval remains limited to the metadata-only pacman -Fy extra-3.9 operation. A retry is not yet justified until the actual configured database path and its access/mount state are understood.

### LXC-PKG-06 — read-only inspection of the configured pacman database directory

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED — configured DBPath exists, is root-owned mode 755, resides on a read-write Btrfs mount, and has no db.lck at inspection time; cause of the earlier lock failure remains unresolved**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** LXC-PKG-05 established the effective pacman DBPath as `/usr/lib/holo/pacmandb` and showed that `/var/lib/pacman` does not exist. This test follows the configured path rather than repeating the incorrect conventional-path query.
- **Question:** Does the configured database directory exist, what are its path permissions and ownership, what filesystem contains it, and is a lock file present there?
- **Why new:** This is the first inspection of the actual configured DBPath and its candidate lock file. It resolves the missing evidence left by LXC-PKG-05 without repeating its checks against `/var/lib/pacman`.
- **Side-effect boundary:** Read-only path, metadata, mount and lock-file queries. No files were created or removed; no permissions or mount state were changed; no package operation was attempted.
- **Repeat policy:** Do not repeat unless the configured DBPath, SteamOS build or mount state changes, or a later event requires a fresh point-in-time lock check.

**Exact command executed**

~~~bash
echo "===== LXC-PKG-06: CONFIGURED PACMAN DBPATH INSPECTION ====="

DBPATH="$(pacman-conf DBPath)"

echo
echo "===== 1. EFFECTIVE DATABASE PATH ====="
printf 'DBPATH=%s\n' "$DBPATH"

echo
echo "===== 2. PATH COMPONENTS AND PERMISSIONS ====="
namei -l "$DBPATH"

echo
echo "===== 3. DATABASE DIRECTORY METADATA ====="
ls -ld /usr /usr/lib /usr/lib/holo "$DBPATH" 2>&1

echo
echo "===== 4. DATABASE DIRECTORY OWNERSHIP ====="
sudo stat -c \
  'Path=%n Type=%F Owner=%U Group=%G Mode=%a' \
  "$DBPATH" 2>&1

echo
echo "===== 5. DATABASE FILESYSTEM MOUNT ====="
findmnt -T "$DBPATH" -o TARGET,FSTYPE,OPTIONS

echo
echo "===== 6. LOCK FILE AT CONFIGURED DBPATH ====="
sudo stat -c \
  'Path=%n Type=%F Owner=%U Group=%G Mode=%a Size=%s Modified=%y' \
  "$DBPATH/db.lck" 2>&1

echo
echo "===== END LXC-PKG-06 ====="
~~~

**Actual output**

~~~text
===== LXC-PKG-06: CONFIGURED PACMAN DBPATH INSPECTION =====

===== 1. EFFECTIVE DATABASE PATH =====
DBPATH=/usr/lib/holo/pacmandb

===== 2. PATH COMPONENTS AND PERMISSIONS =====
f: /usr/lib/holo/pacmandb
dr-xr-xr-x root root /
drwxr-xr-x root root usr
drwxr-xr-x root root lib
drwxr-xr-x root root holo
drwxr-xr-x root root pacmandb

===== 3. DATABASE DIRECTORY METADATA =====
drwxr-xr-x 1 root root     66 Oct 23 23:10 /usr
drwxr-xr-x 1 root root 186830 Oct 23 23:10 /usr/lib
drwxr-xr-x 1 root root    634 Oct 23 23:10 /usr/lib/holo
drwxr-xr-x 1 root root     18 Oct 23 23:10 /usr/lib/holo/pacmandb

===== 4. DATABASE DIRECTORY OWNERSHIP =====
[sudo] password for deck:
Path=/usr/lib/holo/pacmandb Type=directory Owner=root Group=root Mode=755

===== 5. DATABASE FILESYSTEM MOUNT =====
TARGET FSTYPE OPTIONS
/      btrfs  rw,relatime,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/

===== 6. LOCK FILE AT CONFIGURED DBPATH =====
stat: cannot statx '/usr/lib/holo/pacmandb/db.lck': No such file or directory

===== END LXC-PKG-06 =====
(deck@Laco ~)$
~~~

**Observed result**

- The effective DBPath is `/usr/lib/holo/pacmandb`.
- The directory and all listed path components exist. `namei` showed root-owned path components; `ls -ld` and `stat` showed `/usr/lib/holo/pacmandb` as `root:root`, mode `755`.
- `findmnt -T` resolved the directory to the root (`/`) Btrfs filesystem. The reported mount options include `rw`.
- No `/usr/lib/holo/pacmandb/db.lck` file existed at the time of the `stat` query.
- No package database refresh or installation was performed.

**Interpretation**

- **What this proves:** the configured database directory exists; it is owned by root with mode 755; the containing Btrfs root filesystem is reported mounted read-write; and the expected `db.lck` path was absent at inspection time.
- **What this does not prove:** that a pacman process can successfully create the lock; that there was no transient competing process during LXC-PKG-03; that no other lock mechanism or error condition occurred; or why the earlier `unable to lock database` error happened.
- Mode 755 means ordinary non-root users do not have directory write permission, while root does. This is consistent with a privileged package-manager operation, but it does not by itself establish that the failed sudo invocation had effective access at the relevant moment.
- The earlier LXC-PKG-04 lock observation remains superseded because it queried `/var/lib/pacman/db.lck`, not this configured path. LXC-PKG-06 is the valid point-in-time lock-path observation.
- The original lock failure remains **INCONCLUSIVE**. Do not infer a stale lock or permission/mount fault from the evidence collected so far.

**Decision / next step**

- Mark LXC-PKG-06 **COMPLETED** as a read-only inspection of the actual configured database directory.
- Keep LXC-PKG-02 and LXC-PKG-03 **PARTIAL / BLOCKED**; the package manifest remains uninspected and the metadata refresh remains incomplete.
- Next step: reassess the original pacman error and gather only further read-only evidence if it can distinguish a concrete cause. Do not create a test lock, remove files, alter permissions, remount, terminate processes or retry `pacman -Fy` merely because the expected lock file is currently absent.
- The user's prior authorization remains limited to the metadata-only `pacman -Fy extra-3.9` operation. Any retry must be proposed with its exact scope and rationale before execution; no LXC installation or Waydroid setup is approved by this result.
---


### LXC-PKG-07 — read-only inspection of DBPath contents, attributes, ACL and root write check

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED — root write-access check returned NO despite root ownership and mode 755; cause remains unresolved**
- **Environment:** Steam Deck SteamOS host (deck@Laco), command issued over SSH from Windows PowerShell
- **Prerequisite:** LXC-PKG-05 identified `/usr/lib/holo/pacmandb` as the effective DBPath; LXC-PKG-06 inspected its ownership, mode, containing mount and lock-file presence.
- **Question:** Do the effective pacman RootDir/DBPath, directory entries, filesystem attributes, ACL and a non-mutating root write-access check explain the earlier database-lock failure?
- **Why new:** Unlike PKG-06, this test inspects the contents and ACL/attributes of the actual DBPath and performs a write-access predicate check without creating a file. It does not repeat the incorrect `/var/lib/pacman` check.
- **Side-effect boundary:** Read-only configuration, listing, attribute, ACL and access checks. No file creation, lock operation, permission change, mount change or package operation.
- **Repeat policy:** Do not repeat unless RootDir/DBPath, SteamOS build, filesystem state or relevant execution context changes, or a specific later diagnostic requires a fresh access check.

**Exact command executed**

~~~bash
echo "===== LXC-PKG-07: PACMAN DBPATH PERMISSIONS AND ATTRIBUTES ====="

echo
echo "===== 1. EFFECTIVE PACMAN ROOTDIR ====="
pacman-conf RootDir

echo
echo "===== 2. EFFECTIVE PACMAN DBPATH ====="
DBPATH="$(pacman-conf DBPath)"
printf 'DBPATH=%s\n' "$DBPATH"

echo
echo "===== 3. DATABASE DIRECTORY CONTENTS ====="
sudo ls -la "$DBPATH"

echo
echo "===== 4. DATABASE DIRECTORY FILESYSTEM ATTRIBUTES ====="
if command -v lsattr >/dev/null 2>&1; then
    sudo lsattr -d "$DBPATH"
else
    echo "lsattr is not installed; attribute inspection unavailable."
fi

echo
echo "===== 5. DATABASE DIRECTORY ACL ====="
if command -v getfacl >/dev/null 2>&1; then
    sudo getfacl -cp "$DBPATH"
else
    echo "getfacl is not installed; ACL inspection unavailable."
fi

echo
echo "===== 6. EFFECTIVE ROOT WRITE-ACCESS CHECK ====="
if sudo test -w "$DBPATH"; then
    echo "Root write-access check: YES"
else
    echo "Root write-access check: NO"
fi

echo
echo "===== END LXC-PKG-07 ====="
~~~

**Actual output**

~~~text
===== LXC-PKG-07: PACMAN DBPATH PERMISSIONS AND ATTRIBUTES =====

===== 1. EFFECTIVE PACMAN ROOTDIR =====
/

===== 2. EFFECTIVE PACMAN DBPATH =====
DBPATH=/usr/lib/holo/pacmandb

===== 3. DATABASE DIRECTORY CONTENTS =====
[sudo] password for deck:
total 0
drwxr-xr-x 1 root root    18 Oct 23 23:10 .
drwxr-xr-x 1 root root   634 Oct 23 23:10 ..
drwxr-xr-x 1 root root 49006 Oct 23 23:10 local
drwxr-xr-x 1 root root   126 Oct 23 23:08 sync

===== 4. DATABASE DIRECTORY FILESYSTEM ATTRIBUTES =====
--------c------------- /usr/lib/holo/pacmandb

===== 5. DATABASE DIRECTORY ACL =====
user::rwx
group::r-x
other::r-x


===== 6. EFFECTIVE ROOT WRITE-ACCESS CHECK =====
Root write-access check: NO

===== END LXC-PKG-07 =====
(deck@Laco ~)$
~~~

**Observed result**

- `pacman-conf RootDir` printed `/`.
- Effective DBPath remains `/usr/lib/holo/pacmandb`.
- The directory contains `local` and `sync` subdirectories; no `db.lck` was shown in the listing.
- `lsattr -d` reported `--------c-------------`. The `c` attribute is the Btrfs no-copy-on-write attribute; neither immutable (`i`) nor append-only (`a`) is shown.
- ACL output is the basic access ACL: owner `rwx`, group `r-x`, other `r-x`; no additional named user/group ACL entries or restrictive ACL mask were displayed.
- `sudo test -w "$DBPATH"` returned false and printed **Root write-access check: NO**.
- No write attempt, lock creation, package operation or filesystem modification occurred.

**Interpretation**

- **What this proves:** the effective RootDir is `/`; the configured DBPath contains the expected `local` and `sync` directories; the displayed ACL grants directory write permission only to the owner; the displayed Btrfs `c` attribute is not an immutable/append-only flag; and the specific `sudo test -w` access predicate returned false in this execution.
- **What this does not prove:** that root cannot create a file there, that pacman itself cannot acquire its lock, or that this result reproduces the execution context of LXC-PKG-03. The access predicate is not a write attempt and does not establish the cause of the original lock error.
- The false root write-access result is unexpected alongside root ownership, mode 755, the basic ACL and the earlier root Btrfs mount reported `rw`. The available evidence does not identify why the predicate returned false. Do not attribute it to the `c` attribute; that flag is not immutable or append-only.
- No permission, ACL, attribute or mount change is justified. Do not test by creating a file or lock.
- The original LXC-PKG-03 database-lock failure remains **INCONCLUSIVE**. The manifest refresh remains blocked/incomplete; no LXC package was installed.

**Decision / next step**

- Mark LXC-PKG-07 **COMPLETED** as a read-only diagnostic.
- Stop the current lock investigation here unless a specific, non-mutating diagnostic can explain the discrepancy without repeating prior checks. Do not attempt a test write, create/remove a lock, alter permissions/ACL/attributes, remount, terminate processes or retry `pacman -Fy` on the basis of this result.
- Any future metadata refresh retry must first be presented with its exact scope and rationale and receive explicit user approval. The earlier approval was for the single metadata-only refresh attempt; it is not blanket approval for troubleshooting changes.
---

### 5.10 Direct host-level temporary systemd delegated-scope feasibility

#### LXC-SCOPE-01 — attempted; rejected before scope creation

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **BLOCKED — systemd-run rejected mutually incompatible command-line options; diagnostic payload did not execute**
- **Environment:** Steam Deck SteamOS host (deck@Laco), invoked over SSH
- **Question:** Can a temporary user systemd scope with Delegate=yes expose a writable delegated cgroup subtree to a direct host-level user process?
- **Gate addressed:** Phase 1.5, remaining gate 3 in §1.3. This tests direct host-level user-systemd delegation, not Podman's nested cgroup boundary.
- **Prior evidence relied upon:** Tests 24–25 and §5.8 establish the Podman cgroup v2 boundary and host unit properties, but do not establish direct scope delegation.
- **Why new:** It attempts a direct temporary systemd scope rather than inferring behavior from a Podman container or from Delegate=yes on user@1000.service.
- **Side-effect boundary:** The requested command was rejected during option validation. No diagnostic process or scope was started; no cgroup files were read or written by the payload; no persistent systemd configuration was changed.
- **Repeat policy:** Do not repeat this exact invocation. A corrected invocation may omit --wait and --collect while retaining --user --scope --property=Delegate=yes. It must remain a short-lived diagnostic only.

**Exact command form executed**

~~~bash
systemd-run \
  --user \
  --scope \
  --property=Delegate=yes \
  --wait \
  --collect \
  /usr/bin/bash -c '...'
~~~

The payload was the full read-only cgroup diagnostic supplied in this conversation: it would have printed /proc/self/cgroup, the scope cgroup directory metadata and mount, available/enabled controllers, and write-access predicates for the scope directory, cgroup.procs and cgroup.subtree_control.

**Actual output**

~~~text
systemd 261 (261.2-1.2-arch)
--wait may not be combined with --scope.
Exit code: 1
logout
Connection to deck closed.
~~~

**Observed result**

- SteamOS host reports systemd 261 (261.2-1.2-arch).
- systemd-run rejected the option combination --wait and --scope.
- Overall shell exit status was 1.
- The SSH session closed after the command sequence.
- The command did not reach the diagnostic payload; no cgroup membership, mount, controller or access result was obtained.

**Interpretation**

- **What this proves:** this installed systemd-run does not accept --wait together with --scope; the attempted invocation failed before launching the requested process.
- **What this does not prove:** it says nothing about whether a temporary delegated user scope can be created, whether its cgroup subtree is writable, or whether LXC can use it.
- No persistent configuration or host cgroup setting was changed. No LXC package or container was involved.

**Decision / next step**

- Record LXC-SCOPE-01 as **BLOCKED / NOT EXECUTED**, not as a delegation failure.
- LXC-SCOPE-02 created a transient scope but inspected the wrong cgroup directory due to premature variable expansion. LXC-SCOPE-03 corrected the path and confirmed positive write-access predicates on the actual scope. See both test records below.
- Do not use --service, create a persistent unit, enable a service, alter cgroup/systemd configuration, or run LXC. The corrected scope must be transient and must not change existing Podman/Pi-hole workloads.
- Do not advance the LXC installation decision until a direct host-level delegation result is obtained and interpreted.
---

#### LXC-SCOPE-02 — transient scope created; cgroup path inspection misdirected

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **PARTIAL / INCONCLUSIVE — scope creation and process membership confirmed; delegated cgroup directory and write permissions not inspected**
- **Environment:** Steam Deck SteamOS host (deck@Laco), invoked over SSH
- **Systemd:** `systemd 261 (261.2-1.2-arch)`
- **Question:** Can a transient user scope with `Delegate=yes` be created, and what cgroup directory and permissions does it expose to the process?
- **Gate addressed:** Phase 1.5, direct host-level unprivileged LXC feasibility. This is distinct from the rootless Podman cgroup boundary in Tests 24–25.
- **Prior evidence relied upon:** LXC-SCOPE-01 established only that `--wait` cannot be combined with `--scope`; it did not start a scope. LXC-SCOPE-02 removes the incompatible options and attempts the same bounded read-only diagnostic.
- **Why new:** This is the first invocation that actually started a transient `--user --scope` unit with `Delegate=yes`.
- **Side-effect boundary:** A transient scope named `run-p504174-i508745.scope` was created for the diagnostic process. No persistent unit/service was installed or enabled; no cgroup controller or cgroup file was written; no LXC package/container was involved. The SSH connection closed after the command completed.
- **Repeat policy:** Do not repeat the same malformed path expression. A narrowly corrected LXC-SCOPE-03 may rerun the read-only payload with only the cgroup-directory assignment changed to avoid systemd-run's `${VAR}` environment expansion.

**Invocation and relevant payload**

The invocation used the corrected option set:

~~~bash
systemd-run \
  --user \
  --scope \
  --property=Delegate=yes \
  /usr/bin/bash -c '...'
~~~

The diagnostic read `/proc/self/cgroup`, derived the unified cgroup path, then attempted to inspect:

~~~bash
CGROUP_DIR="/sys/fs/cgroup${CGROUP_REL}"
~~~

The remainder queried directory metadata, the cgroup2 mount, controller files, and read/write access predicates. It did not intentionally write to any cgroup file.

**Actual output (complete relevant transcript)**

~~~text
===== 1. SYSTEMD VERSION =====
systemd 261 (261.2-1.2-arch)

===== 2. CREATE TEMPORARY DELEGATED USER SCOPE =====
Running as unit: run-p504174-i508745.scope; invocation ID: 114fd95c021b4cd9bd3912d0d9b3a12c
Referenced but unset environment variable evaluates to an empty string: CGROUP_REL

===== PROCESS CGROUP MEMBERSHIP =====
0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-p504174-i508745.scope

===== DELEGATED CGROUP PATH =====
Relative path: /user.slice/user-1000.slice/user@1000.service/app.slice/run-p504174-i508745.scope
Directory: /sys/fs/cgroup

===== CGROUP DIRECTORY METADATA =====
Owner=root Group=root Mode=555 Type=directory

===== CGROUP MOUNT =====
TARGET         FSTYPE  OPTIONS
/sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting

===== AVAILABLE CONTROLLERS =====
cpuset cpu io memory hugetlb pids rdma misc dmem

===== ENABLED CHILD CONTROLLERS =====
cpu memory pids dmem

===== READ/WRITE ACCESS PREDICATES =====
WRITE NO:  /sys/fs/cgroup
WRITE NO:  /sys/fs/cgroup/cgroup.procs
WRITE NO:  /sys/fs/cgroup/cgroup.subtree_control

===== SCOPE DIAGNOSTIC COMPLETE =====

===== SYSTEMD-RUN EXIT STATUS =====
Exit code: 0
===== END LXC-SCOPE-02 =====
logout
Connection to deck closed.
~~~

**Observed facts**

1. systemd-run successfully created the transient scope `run-p504174-i508745.scope`; it printed the unit name and invocation ID.
2. The diagnostic process reported unified cgroup membership at `/user.slice/user-1000.slice/user@1000.service/app.slice/run-p504174-i508745.scope`.
3. The cgroup path derivation itself succeeded: `CGROUP_REL` printed that full absolute cgroup path.
4. The next assignment used the braced expression `${CGROUP_REL}`. systemd-run emitted the explicit warning `Referenced but unset environment variable evaluates to an empty string: CGROUP_REL` before the payload's later output.
5. Consequently, `CGROUP_DIR` became `/sys/fs/cgroup`, not the scope directory `/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p504174-i508745.scope`.
6. The `stat`, `findmnt`, controller and write-predicate results therefore describe the cgroup mount root. In particular, `WRITE NO` for the root directory and its files says nothing about write permissions on the delegated scope directory.
7. The diagnostic and systemd-run both returned exit status 0. That status confirms the script completed its checks; it does not validate that the intended target directory was inspected.

**Interpretation**

- **CONFIRMED:** A transient user scope with `Delegate=yes` was created successfully under systemd 261.
- **CONFIRMED:** The diagnostic process entered the scope; its unified cgroup membership contains the transient scope path.
- **CONFIRMED:** systemd-run performed environment expansion on the braced `${CGROUP_REL}` reference in the command payload, where that variable was unset in the caller's environment. The warning and resulting `Directory: /sys/fs/cgroup` demonstrate this.
- **NOT ESTABLISHED:** Ownership/mode of the delegated scope directory; writable access to that directory, `cgroup.procs`, or `cgroup.subtree_control`; which controllers are available/enabled specifically at the scope; whether the scope's delegated subtree is sufficient for LXC.
- **Do not interpret** the three `WRITE NO` lines as evidence that delegation failed. They tested the cgroup mount root, not the delegated scope.
- No cgroup controller activation, cgroup file write, persistent systemd configuration change, LXC installation or LXC runtime test occurred.

**Decision / next step — LXC-SCOPE-03**

The only required correction is the shell variable reference used to construct the cgroup directory. Replace:

~~~bash
CGROUP_DIR="/sys/fs/cgroup${CGROUP_REL}"
~~~

with:

~~~bash
CGROUP_DIR="/sys/fs/cgroup$CGROUP_REL"
~~~

The unbraced reference avoids systemd-run's observed `${VAR}` expansion while allowing the child Bash process to expand its own `$CGROUP_REL`. Keep the rest of the diagnostic read-only and unchanged. Confirm that the printed directory ends with `run-...scope` and is not merely `/sys/fs/cgroup` before interpreting any metadata or access results.

Do not install LXC, run LXC, change controller state, write cgroup files, create persistent units, or alter host configuration. The package-lock investigation remains parked and separate. The transient scope result is useful but does not yet justify an LXC package installation.

#### LXC-SCOPE-03 — actual delegated scope inspected; write-access predicates positive

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED — transient delegated scope and process membership confirmed; scope directory and requested cgroup control paths passed write-access predicates; controller activation and actual cgroup writes not tested**
- **Environment:** Steam Deck SteamOS host (deck@Laco), invoked over SSH
- **Systemd:** `systemd 261 (261.2-1.2-arch)`
- **Transient scope:** `run-p505279-i516648.scope`
- **Invocation ID:** `ca41ab6372574a30a64bc1277ad93bc7`
- **Gate:** Phase 1.5 direct host-level unprivileged LXC feasibility; this tests the systemd delegation prerequisite, not LXC execution.
- **Prior evidence:** LXC-SCOPE-01 was rejected before execution. LXC-SCOPE-02 created a transient scope and confirmed membership but its path expansion defect caused inspection of `/sys/fs/cgroup`. LXC-SCOPE-03 changed the directory expression to the unbraced `$CGROUP_REL` form and validated the target.
- **Why new:** First valid inspection of the actual transient scope directory and its cgroup access predicates.
- **Side-effect boundary:** Transient user scope only. Payload read process membership, metadata, mount and controller files, and shell access predicates. No cgroup files were written, no controllers activated, no persistent unit/service installed or enabled, no package operation, and no LXC/Waydroid runtime involved.
- **Repeat policy:** Do not repeat this diagnostic merely to reconfirm the same predicates. Do not treat `[ -w ]` as an actual write test.

**Corrected path expression**

~~~bash
CGROUP_DIR="/sys/fs/cgroup$CGROUP_REL"
~~~

The script confirmed that the target existed and was distinct from `/sys/fs/cgroup`.

**Actual output (user-provided)**

~~~text
===== 1. SYSTEMD VERSION =====
systemd 261 (261.2-1.2-arch)

===== 2. CREATE TRANSIENT DELEGATED USER SCOPE =====
Running as unit: run-p505279-i516648.scope; invocation ID: ca41ab6372574a30a64bc1277ad93bc7

===== PROCESS CGROUP MEMBERSHIP =====
0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope

===== DELEGATED CGROUP PATH =====
Relative path: /user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope
Directory: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope

===== TARGET DIRECTORY SANITY CHECK =====
PASS: Target is a distinct existing directory.

===== CGROUP DIRECTORY METADATA =====
Owner=deck Group=deck Mode=755 Type=directory

===== CGROUP MOUNT =====
TARGET         FSTYPE  OPTIONS
/sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot

===== AVAILABLE CHILD CONTROLLERS =====
cpu memory pids dmem

===== ENABLED CHILD CONTROLLERS =====

===== READ/WRITE ACCESS PREDICATES =====
WRITE YES: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope
WRITE YES: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope/cgroup.procs
WRITE YES: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope/cgroup.subtree_control

===== SCOPE DIAGNOSTIC COMPLETE =====

===== SYSTEMD-RUN EXIT STATUS =====
Exit code: 0
===== END LXC-SCOPE-03 =====
logout
Connection to deck closed.
~~~

**Observed facts**

1. systemd-run created transient scope `run-p505279-i516648.scope`, invocation ID `ca41ab6372574a30a64bc1277ad93bc7`.
2. Process membership is `/user.slice/user-1000.slice/user@1000.service/app.slice/run-p505279-i516648.scope`.
3. The corrected directory resolves to the full scope path, exists, and passes the explicit sanity check.
4. The scope directory is owned by `deck:deck`, mode `755`.
5. The cgroup2 mount is reported as `rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot`.
6. Available child controllers: `cpu memory pids dmem`.
7. `cgroup.subtree_control` is empty: no child controllers are currently enabled at this scope.
8. Shell `[ -w ]` predicates return YES for the scope directory, `cgroup.procs`, and `cgroup.subtree_control`.
9. The diagnostic and systemd-run returned exit status 0.

**Interpretation and limits**

- **CONFIRMED:** A normal user invocation using `systemd-run --user --scope --property=Delegate=yes` created a transient scope and the diagnostic process ran inside it.
- **CONFIRMED:** The scope directory is owned by `deck:deck`, mode `755`.
- **CONFIRMED AS ACCESS PREDICATES:** The invoking process passed shell write-access checks for the scope directory, `cgroup.procs`, and `cgroup.subtree_control`. These predicates do not prove an actual cgroup write succeeded.
- **CONFIRMED:** Child controllers `cpu`, `memory`, `pids`, and `dmem` are available at this scope.
- **CONFIRMED:** No child controller is currently enabled.
- **NOT TESTED:** Actual child-cgroup creation, process movement via `cgroup.procs`, controller activation/configuration, LXC's exact cgroup-v2 requirements, or LXC runtime behavior.
- This is materially stronger than LXC-SCOPE-02, whose access checks targeted the mount root. It does not alone prove LXC will run correctly.
- No cgroup file was written, no controller activated, and no persistent host configuration changed.

**Decision / next gate**

The direct host-level systemd delegation prerequisite is **promising and materially demonstrated at the permission-predicate level**. It resolves the narrow delegation-directory inspection question, not full LXC feasibility.

Next, reconcile the still-blocked package manifest with LXC's precise cgroup-v2 requirements. The package-lock investigation remains parked; do not retry pacman or create test files/locks without a separately justified and explicitly approved plan.

No actual cgroup write/controller activation is authorized by this result. Do not install LXC, launch LXC, install Waydroid, create persistent units, alter host cgroups, or modify Podman/Pi-hole on this evidence alone. Present any further test as a separate bounded proposal and obtain approval before cgroupfs writes or package-state changes.



## 5.9 Phase 1.5 — read-only reconciliation of LXC cgroup-v2 requirements

- **Date:** 2026-11-07
- **Status:** **COMPLETED — source-level requirements reconciled; runtime operation remains untested**
- **Scope:** Public upstream documentation/source review only. No Steam Deck command was run for this investigation.
- **Question:** Given LXC-SCOPE-03, what does upstream LXC require from cgroup v2, what does an empty `cgroup.subtree_control` mean, and is the evidence sufficient to claim LXC compatibility?
- **Why new:** LXC-SCOPE-03 corrected the scope-path error and established positive shell access predicates. This investigation interprets those observations against upstream requirements without repeating the host test or writing to cgroup files.
- **Side-effect boundary:** Read-only web/source review. No host files, packages, cgroups, services, containers, permissions, or package-manager state were changed.
- **Repeat policy:** Do not repeat unless LXC/systemd/kernel behavior materially changes or a relevant upstream source changes.

### Upstream findings

1. **LXC requires a delegated cgroup subtree for an unprivileged user on cgroup v2.** The upstream LXC “Getting started” documentation says the user must be allocated an empty delegated cgroup and documents wrapping LXC commands with a transient `systemd-run --user --scope -p Delegate=yes` scope. It identifies the cgroup-v2 leaf-node/delegation model as the reason. Source: https://linuxcontainers.org/lxc/getting-started/
2. **Systemd delegation and controller activation are distinct.** Systemd's cgroup interface documentation says `Delegate=yes` allows a scope/service to manage its own subtree and gives the unprivileged unit's user access to its delegated cgroup directory and relevant files. It also states that controllers are made available but are not automatically enabled in `cgroup.subtree_control`. Source: https://systemd.io/CONTROL_GROUP_INTERFACE/ and https://github.com/systemd/systemd/blob/main/docs/CGROUP_DELEGATION.md
3. **An empty `cgroup.subtree_control` is normal initial state.** The Linux kernel cgroup-v2 documentation says the file starts empty; controllers must be available in `cgroup.controllers` and can be enabled only subject to hierarchy and no-internal-process constraints. The empty value alone is not evidence of a failure. Source: https://docs.kernel.org/admin-guide/cgroup-v2.html
4. **LXC's start path does perform cgroup operations.** Current upstream LXC source shows creation/delegation/entry of its monitor cgroup, setting up limits, and activating cgroup-v2 device rules during container startup. This source-level observation does not prove every operation is required in the exact Deck configuration, nor that the current candidate package matches the inspected upstream branch. Source: https://github.com/lxc/lxc/blob/main/src/lxc/start.c
5. **The controller set is promising but not a compatibility proof.** LXC-SCOPE-03 observed `cpu memory pids dmem` in the scope's available child controllers. Whether the intended minimal LXC configuration needs any particular controller depends on the actual config and startup path. No controller was enabled in the test, and no controller file was written.

### Evidence matrix

| Requirement / observation | Evidence | Interpretation |
|---|---|---|
| LXC command runs inside a dedicated transient delegated scope | LXC-SCOPE-03 | **CONFIRMED** |
| Correct scope cgroup path exists and is distinct from cgroup root | LXC-SCOPE-03 | **CONFIRMED** |
| Scope directory, `cgroup.procs`, and `cgroup.subtree_control` pass shell `[ -w ]` predicates | LXC-SCOPE-03 | **PROMISING, NOT A WRITE TEST** |
| Available child controllers are `cpu memory pids dmem` | LXC-SCOPE-03 | **CONFIRMED AS OBSERVED** |
| `cgroup.subtree_control` starts empty | LXC-SCOPE-03; kernel documentation | **NORMAL INITIAL STATE; NOT ITSELF A BLOCKER** |
| Actual child cgroup creation and process movement succeed | Not tested | **UNTESTED** |
| Controller activation/device-controller behavior works for LXC | Not tested | **UNTESTED** |
| Candidate Deck package matches the current upstream source reviewed | Package version is reported as LXC 7.0.0-1; source review uses upstream main | **NOT FULLY RECONCILED** |
| Exact Deck-local package file manifest | Repository file-list databases unavailable | **BLOCKED** |

### Decision after this investigation

- The direct-host delegated-scope approach is **technically plausible**, and is a distinct path from the blocked nested-rootless-Podman cgroup mount.
- The evidence is **not sufficient to claim unprivileged LXC compatibility**. The positive `[ -w ]` checks do not establish that a child cgroup can be created, that a process can be moved, or that LXC's cgroup setup will succeed.
- A bounded, real cgroup operation inside a fresh transient delegated scope would close an important prerequisite before installing LXC, but that would mutate a temporary cgroup hierarchy. It is **outside this read-only investigation** and requires separate explicit approval and a predeclared cleanup/verification plan.
- The exact package manifest remains blocked. Do not retry pacman, refresh file-list databases, install LXC, launch LXC, or change any persistent configuration on the basis of this source review.
- The rootless Podman cgroup limitation remains unchanged. A successful direct-host test would not establish that LXC can run nested inside the existing Podman boundary.



## 5.10 LXC-CGROUP-01 — actual delegated child-cgroup creation and removal

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **PASS — actual empty child-cgroup creation, inspection and removal confirmed**
- **Environment:** SteamOS host, `deck@Laco`; transient systemd user scope, not Distrobox or Podman
- **Transient scope:** `run-p511103-i506154.scope`
- **Invocation ID:** `289996943a4344d5af5657d9853f3220`
- **Question:** Can the unprivileged process create and remove an empty child cgroup inside its transient `Delegate=yes` scope?
- **Prerequisites:** LXC-SCOPE-03 and source reconciliation §5.9.
- **Why new:** LXC-SCOPE-03 established only shell write-access predicates. This test performed a real `mkdir` and `rmdir` against a child of the actual delegated scope.
- **Side-effect boundary:** One temporary empty cgroup directory was created and removed inside the transient scope. No controller was activated; no process was moved; no package, service, host configuration or persistent cgroup setting was changed.
- **Repeat policy:** Do not repeat unless the kernel, systemd, SteamOS build, cgroup hierarchy or test boundary changes.

### Exact command executed

The user executed the approved LXC-CGROUP-01 command as supplied in the preceding conversation. It launched a transient user scope with `Delegate=yes`, verified scope membership and the cgroup2 mount, read controller state, created one empty child cgroup, inspected its process and event files, removed it, and re-read the parent controller state.

### Actual user-reported output

```text
===== LXC-CGROUP-01: DELEGATED CHILD-CGROUP CREATE / REMOVE =====
Running as unit: run-p511103-i506154.scope; invocation ID: 289996943a4344d5af5657d9853f3220

===== 1. PROCESS CGROUP MEMBERSHIP =====
Relative path: /user.slice/user-1000.slice/user@1000.service/app.slice/run-p511103-i506154.scope
PASS: Process is inside a user-slice scope.

===== 2. TARGET DIRECTORY VALIDATION =====
PASS: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p511103-i506154.scope

===== 3. CGROUP2 MOUNT VALIDATION =====
cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting
PASS: Mount reports rw.

===== 4. CURRENT CONTROLLER STATE (READ-ONLY) =====
Available:
cpu memory pids dmem
Enabled for children:

===== 5. CREATE ONE EMPTY CHILD CGROUP =====
PASS: Child cgroup created.
Path: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p511103-i506154.scope/lxc-audit-probe-$

===== 6. INSPECT CHILD CGROUP =====
Child controllers:
Child processes (expected empty):
Child events:
populated 0
frozen 0

===== 7. REMOVE CHILD CGROUP =====
PASS: Child cgroup removed.

===== 8. FINAL PARENT STATE (READ-ONLY) =====
Available controllers:
cpu memory pids dmem
Enabled child controllers:

===== LXC-CGROUP-01 COMPLETE =====
No controller activation or process movement performed.
```

**Output limitation:** No separately printed `systemd-run` exit status was included. The final completion marker and successful removal are present; no independent exit code is inferred.

**Path-name note:** The reported child path ends with the literal-looking suffix `lxc-audit-probe-$`, rather than a visible numeric PID suffix. Preserve it as reported; do not infer that the suffix was PID-derived. The operation succeeded and the path was removed.

### Result and interpretation

| Check | Observed result | Assessment |
|---|---|---|
| Transient delegated scope | `run-p511103-i506154.scope` | **CONFIRMED** |
| Scope membership and distinct cgroup2 target | Expected path; validated | **PASS** |
| cgroup2 mount | `rw` | **CONFIRMED** |
| Parent available controllers | `cpu memory pids dmem` | **CONFIRMED** |
| Parent enabled child controllers | Empty | **UNCHANGED** |
| Actual child cgroup creation | `mkdir` succeeded | **PASS — REAL OPERATION** |
| Child process list | Empty | **PASS** |
| Child event state | `populated 0`, `frozen 0` | **PASS** |
| Child cgroup removal | `rmdir` succeeded | **PASS — CLEANUP CONFIRMED** |
| Controller activation | Not attempted | **UNTESTED** |
| Process movement through `cgroup.procs` | Not attempted | **UNTESTED** |
| LXC startup or compatibility | Not attempted | **UNTESTED** |

### Decision after LXC-CGROUP-01

- Direct host-level transient systemd delegation now has stronger evidence than the previous access-predicate-only result: an unprivileged process **actually created, inspected and removed an empty child cgroup**.
- This is a meaningful prerequisite for LXC's cgroup-v2 hierarchy management, but it is **not an LXC runtime test**.
- The empty child reported no controllers in `cgroup.controllers`, consistent with the parent having no controllers enabled in `cgroup.subtree_control`. No controller activation was needed for this directory-only test.
- The next distinct cgroup prerequisite to consider is a tightly scoped process-placement test: create a short-lived child process, move only that child into a temporary delegated child cgroup, verify membership, and let it exit before removing the empty child cgroup. This is another real cgroup mutation and requires separate approval. Do not run it automatically.
- The package-manifest blocker remains unresolved. No pacman retry, file-list refresh, LXC installation, or Waydroid installation is authorized by this result.
- The rootless Podman cgroup mount remains read-only; this direct-host result does not establish nested LXC inside Podman.




#### LXC-CGROUP-02 — delegated child-cgroup process placement and cleanup

- **Date:** 2026-11-07 (user-reported execution date)
- **Status:** **COMPLETED / PASSED — one temporary process was moved from the transient delegated parent scope into a child cgroup, membership was independently verified, the process was terminated/reaped, and the empty child cgroup was removed**
- **Environment:** Steam Deck SteamOS host (deck@Laco), invoked over SSH
- **Transient scope:** run-p515138-i514057.scope
- **Invocation ID:** 9218bdeda0de49adb37bcf0b374413d2
- **Test process PID:** 515140
- **Question:** Can a process owned by a transient user systemd scope with Delegate=yes be moved into a child cgroup and then cleanly terminated, reaped, and removed?
- **Gate addressed:** Phase 1.5 direct host-level delegated cgroup feasibility, Gate 4 in §9. This is a real process-placement operation, distinct from LXC-CGROUP-01's empty child-cgroup creation/removal.
- **Prior evidence relied upon:** LXC-SCOPE-03 confirmed the actual transient scope path, cgroup2 rw mount and positive write-access predicates. LXC-CGROUP-01 then confirmed actual creation, inspection and removal of one empty child cgroup. Neither prior test moved a process.
- **Why new:** This test exercises the actual cgroup.procs process-placement operation and verifies the resulting membership through both /proc/PID/cgroup and the child cgroup's process list.
- **Side-effect boundary:** One short-lived transient user scope, one child cgroup named lxc-audit-probe-process, and one /usr/bin/sleep 60 process. The process was terminated and reaped; the child cgroup was confirmed empty and removed. No controller was activated, no resource limit was set, no persistent systemd configuration changed, and no Podman, Pi-hole, Odysseus, LXC or Waydroid workload was modified.
- **Repeat policy:** Do not repeat merely to reconfirm process placement. A future test must address a distinct LXC requirement and receive its own approval. This result is not authorization to activate controllers, install or launch LXC, or modify the Podman cgroup boundary.

**Exact command executed**

The exact command consisted of the following systemd-run invocation and the Python payload shown below:

~~~bash
systemd-run \
  --user \
  --scope \
  --property=Delegate=yes \
  /usr/bin/python -c '
import pathlib
import subprocess
import sys

proc = None
child = None
scope = None

def process_cgroup(pid):
    lines = pathlib.Path("/proc/{}/cgroup".format(pid)).read_text().splitlines()
    return next(line for line in lines if line.startswith("0::"))

try:
    print("\n===== 1. PROCESS CGROUP MEMBERSHIP =====")

    own_line = process_cgroup("self")
    scope_rel = own_line[3:]

    print("Relative path:", scope_rel)

    if not scope_rel.startswith("/user.slice/"):
        raise RuntimeError("Unexpected cgroup path; stopping.")

    scope = pathlib.Path("/sys/fs/cgroup") / scope_rel.lstrip("/")

    if not scope.is_dir() or scope == pathlib.Path("/sys/fs/cgroup"):
        raise RuntimeError("Expected distinct scope directory is absent.")

    print("PASS: Delegated scope directory:", scope)

    print("\n===== 2. CGROUP2 MOUNT VALIDATION =====")

    mount = subprocess.run(
        ["findmnt", "-n", "-o", "FSTYPE,OPTIONS", "-T", str(scope)],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip()

    print(mount)

    fields = mount.split(None, 1)
    if len(fields) != 2 or fields[0] != "cgroup2":
        raise RuntimeError("Target is not on cgroup2.")

    if "rw" not in fields[1].split(","):
        raise RuntimeError("Target cgroup2 mount does not report rw.")

    print("PASS: cgroup2 mount is read-write.")

    print("\n===== 3. PARENT CONTROLLER STATE =====")

    print("Available:", (scope / "cgroup.controllers").read_text().strip())
    print("Enabled:", (scope / "cgroup.subtree_control").read_text().strip())

    print("\n===== 4. CREATE ONE EMPTY CHILD CGROUP =====")

    child = scope / "lxc-audit-probe-process"

    if child.exists():
        raise RuntimeError("Probe child already exists; refusing to reuse it.")

    child.mkdir()
    print("PASS: Child cgroup created.")
    print("Path:", child)

    print("\n===== 5. START ONE TEMPORARY PROCESS =====")

    proc = subprocess.Popen(
        ["/usr/bin/sleep", "60"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    print("Test process PID:", proc.pid)

    initial_membership = process_cgroup(proc.pid)
    print("Initial membership:", initial_membership)

    if initial_membership != "0::" + scope_rel:
        raise RuntimeError("Test process did not start in the expected parent scope.")

    print("PASS: Test process initially belongs to the parent scope.")

    print("\n===== 6. MOVE ONLY THE TEST PROCESS =====")

    with (child / "cgroup.procs").open("w") as handle:
        handle.write(str(proc.pid) + "\n")

    print("PASS: PID written to child cgroup.procs.")

    print("\n===== 7. VERIFY ACTUAL PROCESS PLACEMENT =====")

    expected_membership = "0::" + scope_rel + "/lxc-audit-probe-process"
    actual_membership = process_cgroup(proc.pid)

    print("Expected:", expected_membership)
    print("Actual:  ", actual_membership)

    if actual_membership != expected_membership:
        raise RuntimeError("Process membership does not match the child cgroup.")

    child_processes = (child / "cgroup.procs").read_text().split()

    print("Child cgroup.procs:", child_processes)

    if child_processes != [str(proc.pid)]:
        raise RuntimeError("Child cgroup process list does not contain exactly the test PID.")

    print("PASS: Only the intended test process is in the child cgroup.")

    print("\n===== 8. TERMINATE AND REAP TEST PROCESS =====")

    proc.terminate()
    proc.wait(timeout=5)

    print("PASS: Test process exited.")
    print("Exit status:", proc.returncode)

    if proc.returncode != -15:
        print("NOTE: Process exit status differs from the expected SIGTERM status.")

    remaining = (child / "cgroup.procs").read_text().split()

    print("Remaining child processes:", remaining)

    if remaining:
        raise RuntimeError("Child cgroup is not empty after process exit.")

    print("PASS: Child cgroup is empty.")

    print("\n===== 9. REMOVE CHILD CGROUP =====")

    child.rmdir()
    child = None

    print("PASS: Child cgroup removed.")

    print("\n===== 10. FINAL PARENT CONTROLLER STATE =====")

    print("Available:", (scope / "cgroup.controllers").read_text().strip())
    print("Enabled:", (scope / "cgroup.subtree_control").read_text().strip())

    print("\n===== LXC-CGROUP-02 COMPLETE =====")
    print("One test process was moved and then terminated.")
    print("No controller activation performed.")

except Exception as error:
    print("\nFAIL:", str(error))
    raise

finally:
    print("\n===== SAFETY CLEANUP =====")

    if proc is not None and proc.poll() is None:
        print("Terminating remaining test process:", proc.pid)
        proc.terminate()

        try:
            proc.wait(timeout=5)
            print("PASS: Test process reaped.")
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            print("WARNING: Test process required SIGKILL.")

    if child is not None and child.exists():
        try:
            remaining = (child / "cgroup.procs").read_text().split()

            if remaining:
                print("STOP: Child still contains processes:", remaining)
                print("Temporary child path:", child)
            else:
                child.rmdir()
                print("PASS: Remaining empty child cgroup removed.")

        except Exception as cleanup_error:
            print("WARNING: Child cleanup failed:", str(cleanup_error))
            print("Temporary child path:", child)
'
~~~

**Actual user-reported output**

~~~text
===== LXC-CGROUP-02: DELEGATED PROCESS PLACEMENT =====
Running as unit: run-p515138-i514057.scope; invocation ID: 9218bdeda0de49adb37bcf0b374413d2

===== 1. PROCESS CGROUP MEMBERSHIP =====
Relative path: /user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope
PASS: Delegated scope directory: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope

===== 2. CGROUP2 MOUNT VALIDATION =====
cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting
PASS: cgroup2 mount is read-write.

===== 3. PARENT CONTROLLER STATE =====
Available: cpu memory pids dmem
Enabled:

===== 4. CREATE ONE EMPTY CHILD CGROUP =====
PASS: Child cgroup created.
Path: /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope/lxc-audit-probe-process

===== 5. START ONE TEMPORARY PROCESS =====
Test process PID: 515140
Initial membership: 0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope
PASS: Test process initially belongs to the parent scope.

===== 6. MOVE ONLY THE TEST PROCESS =====
PASS: PID written to child cgroup.procs.

===== 7. VERIFY ACTUAL PROCESS PLACEMENT =====
Expected: 0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope/lxc-audit-probe-process
Actual:   0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-p515138-i514057.scope/lxc-audit-probe-process
Child cgroup.procs: ['515140']
PASS: Only the intended test process is in the child cgroup.

===== 8. TERMINATE AND REAP TEST PROCESS =====
PASS: Test process exited.
Exit status: -15
Remaining child processes: []
PASS: Child cgroup is empty.

===== 9. REMOVE CHILD CGROUP =====
PASS: Child cgroup removed.

===== 10. FINAL PARENT CONTROLLER STATE =====
Available: cpu memory pids dmem
Enabled:

===== LXC-CGROUP-02 COMPLETE =====
One test process was moved and then terminated.
No controller activation performed.

===== SAFETY CLEANUP =====
~~~

**Observed facts**

1. systemd-run created transient scope run-p515138-i514057.scope, invocation ID 9218bdeda0de49adb37bcf0b374413d2.
2. The Python diagnostic ran in the expected unified hierarchy path under /user.slice/user-1000.slice/user@1000.service/app.slice/.
3. The scope resolved to a distinct existing directory on a cgroup2 mount reported rw.
4. Parent cgroup.controllers reported cpu memory pids dmem; parent cgroup.subtree_control was empty before and after the test.
5. The child cgroup was created at .../run-p515138-i514057.scope/lxc-audit-probe-process.
6. The temporary sleep 60 process (PID 515140) initially belonged to the parent scope, as independently read from /proc/515140/cgroup.
7. Writing PID 515140 to the child's cgroup.procs succeeded.
8. After the write, /proc/515140/cgroup reported the exact expected child path, and the child's cgroup.procs contained exactly 515140.
9. terminate() followed by wait(timeout=5) completed; Python reported return code -15, consistent with termination by SIGTERM.
10. The child's process list was empty after process exit; rmdir succeeded.
11. The finally cleanup section ran and printed its heading. No fallback cleanup was needed because the normal path had already removed the child and reaped the process.
12. No separate overall shell exit-status line was included in the user transcript. The explicit completion marker and all stage-level PASS checks are present; do not invent an overall exit code.

**Interpretation**

- **CONFIRMED:** The host permitted a process already inside the transient delegated parent scope to be moved into a child cgroup by writing its PID to that child's cgroup.procs.
- **CONFIRMED:** The move was independently observed in the process's unified cgroup membership and in the child process list.
- **CONFIRMED:** The process could be terminated/reaped, the child became empty, and the child cgroup could be removed.
- **CONFIRMED:** The parent's available controller list remained cpu memory pids dmem; cgroup.subtree_control remained empty. No controller activation occurred.
- **NOT ESTABLISHED:** Enabling any controller; LXC's complete cgroup setup, monitor/limit/device-rule operations; LXC startup or teardown; Waydroid startup; or writable delegated cgroup operation from inside the existing rootless Podman container.
- This direct-host primitive test does not overturn the earlier Podman finding: the nested Podman cgroup2 mount was observed read-only. It demonstrates a direct-host systemd delegated-scope capability, not a writable nested cgroup subtree inside Podman.
- The transcript does not separately print systemd-run's overall exit status; record the successful stage outputs without claiming a separately observed overall exit code.

**Decision / next step after LXC-CGROUP-02**

- Direct host-level delegated child-cgroup creation/removal and process placement are now CONFIRMED by LXC-CGROUP-01 and LXC-CGROUP-02.
- The next question is no longer whether a single process can be placed in a delegated child cgroup. It is whether the exact cgroup controller/device operations required by the installed LXC version can be performed safely, and whether the Waydroid launcher can invoke LXC within an appropriate transient delegated scope without broadening host/container privileges.
- Controller activation and LXC runtime testing remain separate gates and require explicit approval. Do not enable controllers or run LXC automatically.
- The package file-manifest inspection remains blocked; the original pacman database-lock failure remains unexplained. Do not retry pacman, refresh file lists, install LXC, or install Waydroid on the basis of this result.
- Do not change the read-only nested Podman cgroup mount, systemd configuration, host cgroup configuration, firewall, forwarding, services, or existing project containers.



#### LXC-INT-01 — version-matched cgroup-v2 and Waydroid launch-path source reconciliation

- **Date:** 2026-11-07
- **Status:** **COMPLETED / SOURCE RECONCILIATION — no host command, package operation, cgroup write, installation or runtime launch performed**
- **Deck package evidence:** LXC candidate 1:7.0.0-1 from extra-3.9, reported by LXC-PKG-01; package is not installed and its file manifest remains blocked.
- **Version-matched upstream source:** LXC tag v7.0.0, release commit e4415af07e3ec291205bc828e2b4e8141f91a499 (signed tag verification reported valid by GitHub).
- **Waydroid source snapshot:** main commit db7294c4c2bd43157bab94cf8a3015e22d9f1ad8 (2026-10-16).
- **Question:** Which concrete cgroup-v2 operations does LXC 7.0.0 perform, which have the host tests actually demonstrated, and does stock Waydroid launch the LXC process in the non-root systemd user context required by LXC's built-in delegated-scope path?
- **Why new:** LXC-CGROUP-01/02 proved child creation/removal and one process move, but did not reconcile these primitives against the exact candidate release or Waydroid's actual D-Bus/systemd execution identity and process-launch path.
- **Side-effect boundary:** Public source and project-document inspection only. No Steam Deck command was run. No package metadata/cache was refreshed; no cgroup file was written; no process was moved; no controller was activated; no service, configuration, package or container was changed.
- **Repeat policy:** Do not repeat unless the Deck candidate version, LXC package build/patch set, Waydroid source commit, or relevant SteamOS/systemd behavior changes. This is not a runtime test.

**Version and provenance qualification**

The Deck's reported candidate is 1:7.0.0-1. The inspected upstream source is the corresponding v7.0.0 release tag. The exact SteamOS package build/patch set could not be compared because LXC-PKG-02's file manifest remains unavailable and the package has not been installed. Findings below are therefore version-matched upstream source findings, not proof of the exact Deck binary's build flags or downstream patches.

**LXC 7.0.0 cgroup-v2 lifecycle observed in source**

1. **Unprivileged systemd scope creation is conditional.** The source checks that systemd is running, that the hierarchy is pure unified cgroup v2, and that the effective UID is not root. If the process is root, LXC returns SYSTEMD_SCOPE_UNSUPP and does not use this unprivileged user-scope path.
2. **The scope is created by LXC itself.** LXC calls systemd's user manager over the user D-Bus, creates a transient scope named lxc-<container>-<index>.scope, assigns its own PID to the scope, sets Delegate=yes, and uses CollectMode=inactive-or-failed. The source falls back to /run/user/1000/bus when DBUS_SESSION_BUS_ADDRESS is absent.
3. **LXC prepares the delegated parent.** It creates an init child cgroup, reads the parent cgroup.procs, moves those listed processes into init/cgroup.procs, reads cgroup.controllers, constructs a +controller entry for every available controller, and writes that list to the parent cgroup.subtree_control.
4. **LXC creates separate monitor and payload/container cgroups.** The cgroup backend uses mkdirat/openat operations to create the monitor cgroup and container cgroup (and optional limit/leaf hierarchy where configured).
5. **LXC moves processes.** It writes the monitor PID and, where applicable, a transient launcher PID to the monitor cgroup's cgroup.procs; it then writes the container PID to the payload cgroup's cgroup.procs. A separate systemd-scope path may ask systemd to attach the payload PID to its scope.
6. **LXC tears down cgroups.** It can move the monitor into a pivot child before pruning the monitor tree. Payload teardown detaches any attached cgroup2 device BPF program and removes the container cgroup tree.
7. **Device policy is a separate conditional operation.** LXC 7.0.0's cgroup2 device implementation loads a BPF program with BPF_PROG_LOAD and attaches/detaches it using BPF_PROG_ATTACH/BPF_PROG_DETACH. LXC's userns template explicitly notes that CAP_SYS_ADMIN in the initial user namespace is required for cgroup.devices. Waydroid's inspected config_base does not itself contain lxc.cgroup2.devices.allow/deny entries; the effective package defaults and full generated configuration are not established, so do not assume this BPF path is necessarily invoked by Waydroid.

**Comparison with completed host evidence**

| LXC operation | Host evidence | Result / limitation |
|---|---|---|
| Create a delegated child cgroup | LXC-CGROUP-01 and 02 created a child below a transient Delegate=yes scope | **CONFIRMED primitive** |
| Move a process via child cgroup.procs | LXC-CGROUP-02 moved one sleep PID from parent to child and verified both /proc/PID/cgroup and child cgroup.procs | **CONFIRMED primitive** |
| Remove an empty child cgroup | LXC-CGROUP-01 and 02 removed the child after confirming it was empty | **CONFIRMED primitive** |
| Create LXC's init child and move all parent-scope PIDs into it | Not tested; prior test moved one deliberately selected process only | **UNTESTED** |
| Read cgroup.controllers | LXC-SCOPE-03 / CGROUP-01 / CGROUP-02 observed cpu memory pids dmem | **READ CONFIRMED** |
| Enable every available controller by writing +cpu +memory +pids +dmem to cgroup.subtree_control | No test wrote to subtree_control; it remained empty in all completed tests | **UNTESTED / MUTATING GATE** |
| Create LXC monitor and payload cgroups and run the monitor/payload lifecycle | No LXC process/container was launched | **UNTESTED** |
| Move monitor, transient launcher and container payload processes through LXC's complete lifecycle | Only one standalone sleep process was moved | **UNTESTED as an LXC lifecycle** |
| Attach/detach cgroup-v2 device BPF policy | No BPF operation was attempted; Waydroid's effective device rules are not fully known | **CONDITIONAL / UNTESTED** |
| LXC cgroup teardown and failure recovery | Only an empty test child was removed | **UNTESTED as an LXC lifecycle** |

**Waydroid's actual launch identity and process path**

- The Waydroid D-Bus activation file declares User=root and starts /usr/bin/waydroid container start; the systemd unit is a system service and runs that command without a User= override.
- The Waydroid container manager's D-Bus object receives Start requests on the system bus. Its do_start path performs host preparation and then calls helpers.lxc.start.
- helpers.lxc.start invokes lxc-start -P <lxc-path> -F -n waydroid -- /init with output="background". The helper creates a subprocess with Popen; it does not change UID or request a user systemd scope.
- The manager's status, stop, freeze, unfreeze and attach/shell paths also invoke lxc-info, lxc-stop, lxc-freeze, lxc-unfreeze and lxc-attach directly.
- Consequently, stock Waydroid's actual lxc-start process is launched by its root D-Bus/systemd service. LXC 7.0.0's unprivileged systemd-scope routine explicitly skips when effective UID is root.
- Wrapping a user-side Waydroid CLI request in systemd-run --user --scope --property=Delegate=yes does not change the identity or cgroup of the separate root D-Bus-activated service and its lxc-start child. It is not a valid integration fix by itself.
- A non-root direct LXC invocation could use LXC 7.0.0's own systemd user-scope integration, but Waydroid's current manager performs privileged host preparation (device permission changes, mounts, networking and service interactions). Splitting that work from an unprivileged LXC process would be a new architecture requiring separate design and security review; it is not a simple wrapper and is not approved here.
- Waydroid's network helper and host-permission operations remain independent blockers under the project's no-host-network-change and least-privilege constraints. A cgroup scope does not neutralize those side effects.

**Decision**

- The direct-host primitive tests are useful and valid, but they do not demonstrate that stock Waydroid can use the unprivileged LXC systemd-scope path.
- The exact unresolved cgroup mutation in LXC 7.0.0 is controller activation: it writes all names exposed by cgroup.controllers into cgroup.subtree_control. The Deck scope reported cpu memory pids dmem, so the source routine would attempt to enable those available controllers. Do not emulate this write or activate controllers without a separate explicit approval.
- Do not use a root-side systemd scope wrapper as a presumed fix; LXC's source explicitly skips its unprivileged user-scope path for euid 0.
- Do not change Waydroid's D-Bus service identity, systemd unit, helper code, device permissions, network helper, Podman cgroup mount or host configuration.
- Do not install LXC yet: the package manifest remains blocked, and exact SteamOS package files/install hooks/service footprint have not been reviewed. Do not retry pacman or refresh file-list metadata without a separately approved and justified plan.
- A future path must first choose and review a privilege architecture: (A) a redesigned split between narrowly privileged Waydroid host preparation and a deck-user-owned LXC process, or (B) stop the container-only Waydroid project if that split cannot meet the security constraints. Neither option is established as working by this source review.

**Primary source links**

- [LXC v7.0.0 cgroup backend](https://github.com/lxc/lxc/blob/v7.0.0/src/lxc/cgroups/cgfsng.c)
- [LXC v7.0.0 cgroup2 device BPF implementation](https://github.com/lxc/lxc/blob/v7.0.0/src/lxc/cgroups/cgroup2_devices.c)
- [LXC v7.0.0 user-namespace configuration template](https://github.com/lxc/lxc/blob/v7.0.0/config/templates/userns.conf.in)
- [LXC v7.0.0 cgroup2 device-rule documentation](https://github.com/lxc/lxc/blob/v7.0.0/doc/lxc.container.conf.sgml.in)
- [Waydroid lxc.py](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/tools/helpers/lxc.py)
- [Waydroid run.py](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/tools/helpers/run.py)
- [Waydroid run_core.py](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/tools/helpers/run_core.py)
- [Waydroid container_manager.py](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/tools/actions/container_manager.py)
- [Waydroid D-Bus activation service](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/dbus/id.waydro.Container.service)
- [Waydroid systemd container unit](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/systemd/waydroid-container.service)
- [Waydroid base LXC configuration](https://github.com/waydroid/waydroid/blob/db7294c4c2bd43157bab94cf8a3015e22d9f1ad8/data/configs/config_base)
- [LXC Getting Started — unprivileged cgroup-v2 procedure](https://linuxcontainers.org/lxc/getting-started/)

**Next action**

No further generic cgroup primitive test is justified. The source review is complete. The next decision is whether to investigate a split-privilege Waydroid architecture (root-only preparation plus a deck-user LXC lifecycle) at design level. Package-manifest recovery remains a separate blocked prerequisite. Controller activation, LXC installation/launch and any Waydroid service/launcher modification require separate approval.


#### SPLIT-ARCH-01 — design-only review of split-privilege Waydroid architecture

- **Date:** 2026-11-07
- **Status:** **COMPLETED / DESIGN REVIEW — no host command, package operation, cgroup write, installation, service change or runtime launch performed**
- **Evidence base:** LXC-INT-01; LXC-SCOPE-03; LXC-CGROUP-01/02; upstream Waydroid service, D-Bus activation, container-manager and LXC launch-path source reviewed there.
- **Question:** Can Waydroid's privileged host preparation be separated from a deck-user-owned LXC lifecycle without broad host privileges, persistent host changes, or host networking changes?
- **Why new:** LXC-INT-01 established that stock Waydroid launches lxc-start from a root-owned D-Bus/systemd service, bypassing LXC 7.0.0's non-root user-scope path. This review evaluates whether a deliberate architecture split could remove that mismatch.
- **Side-effect boundary:** Design analysis only. No Steam Deck command was run and no external source state or host state was changed.
- **Repeat policy:** Revisit only if the user's security constraints change, Waydroid materially changes its service/manager architecture, or a documented upstream unprivileged launch mode becomes available.

**A. Responsibility map**

| Responsibility | Stock Waydroid behavior / likely privilege | Can it safely be delegated to the Deck user? | Design assessment |
|---|---|---|---|
| Control plane and lifecycle | Root system D-Bus service owns start/stop/freeze/unfreeze/status and spawns lxc-start | The user can own a replacement manual launcher and LXC lifecycle, but stock manager cannot simply be wrapped; it must not remain the owner of the root LXC process | **Requires manager/launcher adaptation** |
| LXC cgroup delegation | LXC 7.0.0's built-in systemd user-scope path is selected only for non-root execution | Yes in principle: direct LXC execution by deck can request a transient user scope with Delegate=yes | **Plausible, not runtime-proven**; controller activation and full LXC lifecycle remain untested |
| Rootfs/data preparation | Waydroid manager prepares/mounts rootfs and data paths before LXC start | Some directory preparation can be done once with carefully assigned ownership; mount/image setup may require privileged operations and namespace coordination | **Unresolved**; ownership, idmapping, mount propagation and recovery must be designed |
| Binder access | Manager probes Binder and performs host-side node/permission preparation | Only if the required Binder nodes already exist and can be exposed with narrow, temporary access; do not assume userns ownership mapping or BPF device policy works | **Unresolved**; no broad /dev mount or persistent permission changes |
| GPU access | Container needs selected DRM render device(s) and matching group access | Potentially via a narrowly mapped render node and group ID, if host permissions already permit it | **Conditional**; no broad /dev/dri access and no GPU workload evidence |
| Kernel modules / host device setup | Manager can perform optional driver/module and host-device preparation | Not safely delegated to arbitrary user code; any privileged action would need a fixed, audited broker interface | **High-risk helper boundary**; not justified for this project |
| Android networking | Default Waydroid network helper creates a bridge, configures forwarding, starts dnsmasq and modifies firewall rules | Not under the current no-host-network-change constraint. User-mode networking would require a supported Waydroid/LXC adaptation and is not established by the reviewed source | **Current hard blocker** |
| Session integration | Manager generates session-specific config and coordinates mounts/runtime integration | A manual user launcher could pass only selected session values and sockets | **Possible in principle**, but do not expose the whole host runtime directory or broad D-Bus access |
| Stop/freeze/attach/status | Stock manager invokes LXC lifecycle commands as root | A replacement deck-owned controller could invoke these as the same unprivileged owner as lxc-start | **Requires one consistent owner**; root and user lifecycle managers must not race |
| Failure cleanup | Root manager currently owns host prep and LXC lifecycle | Split ownership creates orphan-mount, stale ACL, stale network, and partially-started-container recovery problems | **Unresolved operational risk**; cleanup must be idempotent and bounded |

**B. Candidate architecture**

The only concept worth evaluating further is a custom, manual-only split with three sharply separated parts:

1. **Deck-user controller (long-lived only while requested):** runs as deck; owns the Waydroid control state and all LXC lifecycle commands; starts LXC directly so LXC can use its non-root systemd user-scope path. No root D-Bus service may spawn or supervise the LXC process.
2. **Optional privileged preparation broker (short-lived, fixed API):** if absolutely unavoidable, performs only a small, statically enumerated set of preparation/cleanup operations. It must not accept shell strings, arbitrary executable paths, arbitrary mount sources/targets, arbitrary device paths, arbitrary network commands, or user-supplied LXC configuration. No wildcard sudoers rule, setuid wrapper, general root shell, or root-owned long-running Waydroid manager.
3. **Unprivileged LXC payload:** runs as deck in a delegated transient user scope. Its rootfs/data, device mappings, cgroup tree, process ownership and teardown must be demonstrably compatible with the user's namespace and filesystem boundaries.

This is an architectural sketch, **not a recommendation to implement a privileged broker**. A broker would itself become security-critical code and would need a separate threat model, fixed request schema, caller authentication, path/device allowlists, concurrency control, crash recovery, audit logging without secrets, and explicit user approval.

**C. Why the split is not presently acceptable**

- The split removes only the root-vs-user LXC launch mismatch. It does not solve Waydroid's host preparation requirements.
- Rootfs/data mount and ownership semantics are not established for a deck-owned LXC process. A root-prepared mount visible in the correct mount namespace is not automatic; neither is safe writable access to Android data.
- Binder and GPU device handoff remain untested. A permission broker could widen access or leave stale permissions after a crash.
- Stock Waydroid's default network helper conflicts directly with the no-host-network-change rule. No compatible user-mode network backend has been demonstrated.
- Replacing the manager means reimplementing or adapting lifecycle/config/session behavior. A thin lxc-start wrapper is not equivalent to Waydroid's manager.
- LXC's source path attempts to enable every available controller in the delegated subtree. The Deck's available list was observed as cpu, memory, pids and dmem, but no controller activation was attempted. Writable access predicates and successful movement of one process do not prove this activation sequence or full LXC startup will work.
- The package file manifest remains unavailable; the exact SteamOS LXC package build/patch set is not verified. This is an independent blocker, not solved by architecture design.

**D. Required conditions before this design could be reconsidered**

| Gate | Minimum evidence / constraint | Current state |
|---|---|---|
| D1 — supported launch ownership | Waydroid manager/launcher can run all LXC lifecycle commands as deck; no root service spawns lxc-start | **NOT MET** |
| D2 — cgroup lifecycle | Approved direct-host LXC test proves controller activation, monitor/payload placement and clean teardown in a transient user scope | **UNTESTED / NOT AUTHORIZED** |
| D3 — rootfs/data | Exact mount, ownership, idmap, persistence and crash-recovery design works without broad host mounts | **UNRESOLVED** |
| D4 — Binder/GPU | Narrow device access works without privileged container mode, broad /dev access or persistent host permission changes | **UNTESTED** |
| D5 — network | Android networking works without host forwarding/firewall/bridge changes or impact to Pi-hole | **NOT MET** |
| D6 — privileged broker (if needed) | Fixed allowlisted operations, no arbitrary command interface, auditable cleanup and explicit approval | **NOT DESIGNED / NOT AUTHORIZED** |
| D7 — package provenance | Exact SteamOS LXC package manifest/build is inspected and install/rollback implications are understood | **BLOCKED** |

**E. Alternatives and verdict**

| Architecture | Assessment |
|---|---|
| Stock Waydroid root service + LXC 7.0.0 | **Rejected for this target:** actual LXC process runs as root and bypasses the non-root user-scope path; also retains stock privileged network/host preparation behavior |
| Rootless Podman + nested LXC | **Blocked:** the observed nested cgroup2 mount is read-only; no approved basis to change it |
| Custom split-privilege manager + deck-owned LXC | **Technically conceivable, not presently acceptable:** requires custom manager work, unresolved mounts/devices, and a network solution that respects the user's hard constraints |
| Stop container-only Waydroid effort | **Valid and currently recommended default** unless the user explicitly relaxes a constraint or a supported upstream design resolves the blockers |

**Conclusion:** The split-privilege idea is not a small integration fix. It would be a custom Waydroid manager/launcher architecture with a potentially security-critical privileged preparation broker. Under the current requirements—container-only, manual lifecycle, no broad privilege, no broad host mounts, no persistent host changes, no host network/firewall changes, and protection of Pi-hole and other projects—it does **not** currently meet the acceptance criteria. Recommend **HOLD / do not implement**. The user may either close the Waydroid feasibility effort as blocked by the current security/network constraints, or explicitly reconsider one named constraint before any new design work. This review does not authorize installation, controller activation, helper creation, service changes, or host modifications.


#### DECISION-WD-01 — close current Waydroid feasibility effort; preserve audit

- **Date:** 2026-11-07
- **Decision owner:** User
- **Status:** **ACCEPTED**
- **Decision:** Close the current Waydroid feasibility effort as blocked under the existing security and operational constraints. Preserve this living audit as the technical record. Do not proceed with a Waydroid installation, Android boot, split-privilege implementation, or host changes.
- **Reason:** SPLIT-ARCH-01 found that the custom split-privilege design does not meet the current acceptance criteria; in particular, stock networking conflicts with the no-host-network-change boundary, while rootfs/data, Binder/GPU access, lifecycle recovery and the privileged-broker boundary remain unresolved.
- **Evidence:** LXC-INT-01; LXC-SCOPE-03; LXC-CGROUP-01/02; SPLIT-ARCH-01.
- **Consequences:** No Waydroid package, service, container, Android data store, host network helper, privileged broker or persistent host configuration is to be introduced under this project decision. Existing Pi-hole and Odysseus deployments remain outside scope and protected.
- **Revisit condition:** User explicitly reopens the project after a material change in upstream support or requirements, and approves a new bounded plan. A separately scoped temporary LXC-only experiment may be considered as an evidence-gathering activity, but it is not part of this closure decision and is not authorized by it.


#### DECISION-LXC-EXP-01 — close read-only phase; open temporary LXC-only experimental investigation

- **Date:** 2026-11-07
- **Decision owner:** User
- **Status:** **ACCEPTED**
- **Decision:** Close the read-only feasibility phase as complete for its current purpose. Open a separately scoped **LXC-only experimental investigation**. The user accepts that temporary test installations may be necessary to obtain runtime evidence and explicitly requests this new investigation chapter.
- **Scope:** LXC package and runtime only. No Waydroid package, service, manager, Android rootfs, Android boot, network helper, bridge, firewall rule, forwarding change, persistent host service, privileged broker, or automatic startup is included.
- **Approval boundary:** The user has approved proceeding with the experimental investigation and temporary-test-installation approach in principle. This is **not** blanket approval to bypass the unresolved pacman database-lock problem, refresh package metadata again, install an unverified package build, alter SteamOS permissions/attributes/mounts, activate controllers, or make persistent configuration changes. Before the first package mutation, present the exact candidate, manifest, transaction, host paths, expected changes, backup/recovery method, uninstall/rollback plan and cleanup verification for explicit confirmation.
- **Reason:** Source inspection and primitive cgroup tests cannot establish whether the actual SteamOS LXC package can run its complete runtime lifecycle in a transient non-root delegated scope. A bounded LXC-only runtime experiment is the next evidence-producing step.
- **Preserved closure:** DECISION-WD-01 remains valid: the Waydroid feasibility effort is closed under the current constraints. This new LXC-only investigation is an independent foundational experiment and does not reopen Waydroid implementation.
- **Protected systems:** Pi-hole, Odysseus, other containers, SSH, host networking and the desktop session must remain unaffected.
- **Revisit condition:** Stop if safe package installation/rollback cannot be established, if LXC requires broad privileges or persistent host changes, or if the test risks protected services.

#### LXC-EXP-00 — experimental investigation charter and safety gates

- **Date:** 2026-11-07
- **Status:** **OPEN / PLAN ONLY — no package operation or host change performed**
- **Environment:** SteamOS host, direct LXC CLI/runtime (not nested in Podman for the first runtime experiment).
- **Prerequisites:** LXC-PKG-01 through LXC-PKG-07; LXC-SCOPE-03; LXC-CGROUP-01/02; LXC-INT-01; DECISION-WD-01; DECISION-LXC-EXP-01.
- **Question:** Can the exact SteamOS LXC package be safely introduced temporarily, then run a minimal non-root LXC lifecycle inside a transient systemd user scope with delegated cgroup v2, and be completely cleaned up?
- **Why this is new:** Existing host tests exercised cgroup primitives, not the LXC binary, package files, LXC monitor, payload, namespace setup, storage backend or teardown. Source reconciliation does not prove the packaged executable behaves identically.
- **Repeat policy:** One controlled run per package build/kernel/systemd combination. Repeat only after a material version/configuration change or a documented inconclusive result.
- **Side-effect boundary:** Package installation is a host package-database and filesystem mutation even when described as temporary. No install command is to be proposed until the package-manager lock issue and package manifest/provenance are resolved and an exact transaction/rollback plan is approved.
- **Approval required:** Explicit confirmation of the exact install transaction and later of any test that writes cgroup controller files or creates cgroups/mounts/devices. The user's general approval for temporary LXC experiments does not waive these staged approvals.

**Experimental phases and stop gates**

| Phase | ID | Activity | Required evidence | Current state |
|---|---|---|---|---|
| 0 | EXP-00A | Freeze read-only phase and establish baseline references | Preserve all prior test IDs; no generic inventory repetition | **COMPLETE by decision** |
| 1 | EXP-01 | Resolve package provenance and installation safety without changing package state | Exact sync candidate, package signature/source, file manifest, dependency/transaction preview, pacman DBPath/lock cause safely understood | **BLOCKED** — manifest unavailable; prior pacman lock error unexplained |
| 2 | EXP-02 | Prepare explicit temporary installation and rollback plan | Exact package files/paths, transaction list, SteamOS overlay/update implications, backup/recovery and removal plan | **PENDING** |
| 3 | EXP-03 | Install only LXC package after separate exact approval | Actual package transaction output, package version/build, installed file list, no unrelated packages | **NOT AUTHORIZED YET** |
| 4 | EXP-04 | Read-only post-install identity and binary audit | LXC version/build, executable/library paths, package ownership, config paths, available backends | **PENDING** |
| 5 | EXP-05 | Minimal non-root LXC smoke test in transient delegated user scope | LXC's own scope creation, cgroup controller activation result, exact process/cgroup membership | **PENDING / MUTATING TEST — separate command approval** |
| 6 | EXP-06 | Minimal disposable container lifecycle | Start, inspect, stop, monitor/payload cgroup placement and clean teardown; no Waydroid payload | **PENDING / requires EXP-05 success** |
| 7 | EXP-07 | Failure-path and cleanup verification | No remaining test processes, cgroups, mounts, namespaces, network objects or persistent services | **PENDING** |
| 8 | EXP-08 | Package removal and host-state comparison | LXC package removed if approved; package DB and file state reconciled; no collateral changes | **PENDING / removal separately reviewed** |
| 9 | EXP-09 | Final evidence review and decision | LXC feasibility verdict; explicit separation from Waydroid feasibility | **PENDING** |

**Phase 1 prerequisite — package-manager safety**

The previous pacman metadata refresh attempt failed to acquire the database lock. Subsequent read-only checks identified DBPath=/usr/lib/holo/pacmandb, no db.lck at inspection time, root:root mode 755, root Btrfs mount reported rw, and a negative `sudo test -w` predicate. These observations do not explain the original lock failure. The repository file-list database was unavailable, so the exact LXC package manifest remains unknown.

Do not:
- retry `pacman -Fy` or any package operation merely to see whether the lock problem disappeared;
- create a test lock/file, remove a lock, alter DBPath permissions/ACL/attributes, remount, or terminate package processes;
- refresh repository databases or file lists without a new justified plan and explicit approval;
- infer the package manifest from upstream Arch metadata or the upstream source tag;
- install LXC until the exact SteamOS candidate and package contents are known and a safe transaction/rollback plan is approved.

A safe next diagnostic must be narrowly justified, read-only, and demonstrably different from LXC-PKG-04 through LXC-PKG-07. If no such diagnostic can explain the pacman failure, stop and report that the installation prerequisite remains blocked rather than bypassing it.

**Runtime experiment design constraints**

- Use a dedicated test rootfs created only for this experiment; never point at Waydroid data or an existing project directory.
- No `--privileged`, host network/PID/IPC namespace sharing, broad host filesystem mounts, host runtime-directory mount, or broad `/dev` passthrough.
- No LXC network helper/service, bridge, NAT, dnsmasq, firewall or forwarding changes.
- No boot enablement, linger changes, persistent systemd units, daemon autostart or persistent delegation configuration.
- Begin with the narrowest possible LXC configuration. Do not assume a successful LXC run requires all controllers; inspect actual LXC behavior and distinguish default/config-driven controller activation from optional features.
- Any write to `cgroup.subtree_control`, creation of a cgroup tree, mount, device node, or namespace is an experiment with explicit scope and cleanup. Controller activation is not covered by the prior child-cgroup/process-placement approvals.
- Preserve exact stdout, stderr, exit statuses, process IDs, scope names, cgroup paths, mount records and cleanup results.
- If the package or runtime requires broad capabilities, persistent host configuration, network changes, or interference with Pi-hole/Odysseus, stop. A negative result is acceptable.

**Success criteria**

LXC-only feasibility is established only if the exact SteamOS package can be installed and removed safely, a non-root LXC process creates/uses its delegated transient user scope, a minimal disposable payload starts and stops, cgroup/monitor/payload teardown is clean, and no protected service or persistent host configuration is changed. This does not establish Waydroid compatibility, Binder/GPU support, Android networking, or Android boot.


## 6. Upstream and project documentation review

### 6.1 Waydroid source inspected

The historical source review covered:

- [drivers.py](https://github.com/waydroid/waydroid/blob/main/tools/helpers/drivers.py)
- [lxc.py](https://github.com/waydroid/waydroid/blob/main/tools/helpers/lxc.py)
- [net.py](https://github.com/waydroid/waydroid/blob/main/tools/helpers/net.py)
- [waydroid-net.sh](https://github.com/waydroid/waydroid/blob/main/data/scripts/waydroid-net.sh)
- [session_manager.py](https://github.com/waydroid/waydroid/blob/main/tools/actions/session_manager.py)
- [container_manager.py](https://github.com/waydroid/waydroid/blob/main/tools/actions/container_manager.py)

These files were inspected for Binder discovery, LXC setup, networking side effects and graphical session lifecycle. If upstream changes, record the commit SHA/date before treating current behavior as identical.

### 6.2 Remote display / ADB references

- [Waydroid ADB FAQ](https://github.com/waydroid/docs/blob/master/faq/using-adb-with-waydroid.md)
- [scrcpy SSH tunnel documentation](https://github.com/Genymobile/scrcpy/blob/master/doc/tunnels.md)

These support the candidate architecture, not a proven end-to-end deployment. Keep ADB localhost-bound and tunnel it through SSH; do not expose unauthenticated ADB on the LAN.

### 6.3 Relevant issue references

- [Waydroid issue #2411](https://github.com/waydroid/waydroid/issues/2411) — Binder regression investigation.
- [Waydroid issue #2422](https://github.com/waydroid/waydroid/issues/2422) — Rust Binder large-transaction failure reports.
- [SteamOS issue #2848](https://github.com/ValveSoftware/SteamOS/issues/2848) — SteamOS Binder/kernel context.

These issues are contextual risk references, not proof that the same failure will occur on the current machine. Check issue status and current upstream fixes only when reaching realistic Binder workload testing.

### 6.4 Project-owned references

- [Pi-hole architecture and operations](https://github.com/laconic-lab/projects/blob/main/pi-hole/docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Historical Waydroid Cage launcher](https://github.com/laconic-lab/projects/blob/main/waydroid/ryan.scripts/Android_Waydroid_Cage.sh)

Pi-hole demonstrates a working rootless Podman service and SSH-accessible project environment, but not Waydroid's nested LXC, Binder or network requirements. The historical Cage launcher is reference material only; it belongs to the rejected native-install path.

### 6.5 Source access limitations

The original export contains links to additional historical files/directories, including a former `_1.1_` export, a text export, and a Waydroid docs directory. At the refresh that produced this record, the current `waydroid/1.audit` directory contained the original exported Markdown and the consolidated audit Markdown. Some historical paths were unavailable at their referenced locations. Do not claim those unavailable files were reviewed. The two prior audit documents are preserved under the archive directory; this living record replaces them as the current continuation entry point.

---



### 6.6 Version-matched LXC 7.0.0 and current Waydroid launch-path reconciliation

The source review was pinned to the Deck-reported LXC candidate's upstream version and a specific Waydroid main commit:

- LXC release tag: [v7.0.0](https://github.com/lxc/lxc/tree/v7.0.0), commit e4415af07e3ec291205bc828e2b4e8141f91a499 (tag verification reported valid).
- Waydroid main snapshot: commit db7294c4c2bd43157bab94cf8a3015e22d9f1ad8, dated 2026-10-16.
- Exact SteamOS package build/patch equivalence remains unverified because the candidate is not installed and its package file manifest could not be retrieved.

The version-matched LXC source implements its own unprivileged systemd-scope creation. It only takes this path when systemd is running, the hierarchy is pure unified cgroup v2, and the LXC process is not root. It starts a transient user scope with Delegate=yes, moves the LXC launcher into an init child, enables all controllers listed by cgroup.controllers in cgroup.subtree_control, then manages monitor and payload cgroups. It performs cgroup.procs moves during startup and can detach device BPF policy and prune cgroup trees during teardown. The complete comparison and observed/unobserved operation matrix are in §5.11.

Waydroid's current system D-Bus activation service declares User=root and is backed by a systemd system unit. Its root container manager calls lxc-start directly through a background subprocess. Therefore, the stock launcher does not run LXC as the deck user; LXC 7.0.0's unprivileged user-scope creation path is explicitly skipped for this root process. Wrapping the user CLI request with systemd-run --user does not move the separately activated root service or its child process into that scope. A split-privilege redesign would be required to make the LXC process non-root while retaining the privileged host preparation Waydroid currently performs; no such redesign has been implemented or approved.

The Waydroid base config reviewed here does not explicitly set lxc.cgroup2.devices.allow/deny. LXC's cgroup-v2 device BPF implementation and userns template were inspected, but whether the exact package's effective configuration triggers BPF attach/detach remains unknown until package defaults and generated configuration are resolved. Do not infer a BPF runtime requirement from source presence alone.

## 7. Decisions, rejected approaches and corrections

| Item | Disposition | Reason / correction |
|---|---|---|
| Native Ryan Rudolf Waydroid install as target | REJECTED | Historical native setup only; current project is container-only |
| Docker as engine | SUPERSEDED | Podman was identified as the actual engine |
| Copy existing Distrobox config | REJECTED | Privileged mode, host namespaces and broad mounts |
| BinderFS with all capabilities dropped | FAILED | Disposable Podman mount denied |
| Permanently grant `CAP_SYS_ADMIN` | NOT APPROVED | Broad capability; temporary test only |
| First Binder ioctl `EINVAL` as Binder failure | INVALIDATED | Incorrect ioctl request/structure; corrected ioctl passed |
| Host namespace networking success as proof of Podman networking | REJECTED | Different namespace boundary |
| `NET_ADMIN` test as proof bridge/NAT failed | REJECTED | Forwarding sysctl failed first; bridge/NAT not reached |
| Cgroup v2 visible as proof of nested LXC delegation | REJECTED | Container mount read-only, subtree delegation empty |
| Nested user namespaces impossible in Podman | SUPERSEDED | They passed with a specific capability set |
| seccomp-only change as UID-map fix | FAILED | Insufficient |
| `no_new_privs`-only change as UID-map fix | FAILED | Insufficient |
| Install packages on SteamOS for Binder tests | AVOIDED | Existing Perl/Python tools used |
| Change host IP forwarding/firewall to force Waydroid | NOT AUTHORIZED | Would affect host networking and potentially protected services |
| Separate compositor by default | NOT SELECTED | Reuse KDE first if feasible |
| Native and remote modes as separate Android installations | NOT SELECTED | If both modes are later supported, use one runtime/data store with separate launch/control paths |

---

## 8. Security and operational design constraints

### 8.1 Outer container

- Rootless Podman is the baseline, not a blanket security guarantee.
- Do not use `--privileged`.
- Do not share host network, PID or IPC namespaces.
- Do not mount `/`, `/home/deck`, all of `/dev`, all of `/sys`, or the entire runtime directory.
- Add only individual devices, paths, sockets and capabilities that have a demonstrated need.
- Keep seccomp enabled unless a narrowly scoped experiment explicitly tests a particular syscall restriction.
- Do not make `apparmor=unconfined` or disable SELinux labels the default.
- Audit effective OCI configuration, not only the command that was intended to create it.

### 8.2 Binder

- BinderFS mounting used `CAP_SYS_ADMIN` in a disposable container; do not assume this is acceptable permanently.
- Binder nodes were mode 0600 and namespace-local root-owned in the recorded test.
- Upstream permission handling was observed to broaden device permissions; do not copy broad permissions automatically.
- Test the exact device path and ownership boundary required by the inner LXC.

### 8.3 Networking and Pi-hole

Waydroid's upstream network helper was observed to create a bridge, enable IPv4 forwarding, add firewall/NAT rules, start dnsmasq and remove some state during shutdown. The inspected shutdown path did not restore the previous `net.ipv4.ip_forward` value.

Any future network experiment must:

1. Record current host forwarding and firewall state before the test.
2. Run inside a disposable, isolated boundary where possible.
3. Avoid changing host forwarding or firewall state.
4. Avoid collisions with Pi-hole's ports, routes, DNS and firewall configuration.
5. Record every created bridge, interface, rule and process.
6. Verify cleanup and before/after equivalence.
7. Stop and ask before any host-wide or persistent change.

Pi-hole's existing port 53 arrangement is a different problem from Waydroid's Android bridge/NAT requirement. Do not reuse Pi-hole configuration as a Waydroid networking template.

### 8.4 KDE session

- SSH sessions are headless by default.
- Do not assume `WAYLAND_DISPLAY`, `DISPLAY`, `XDG_RUNTIME_DIR` or desktop D-Bus variables are available or valid in SSH.
- Do not mount the entire `/run/user/1000` directory into the container.
- First identify the minimum required socket(s), environment values, UID/GID and permissions.
- Test session connection without creating a new compositor or broadening host access.

### 8.5 GPU

- Host render node presence does not establish container GPU operation.
- Prefer a narrow render-node device mapping over all of `/dev/dri`, if technically sufficient.
- Do not grant broad device access or group membership without evidence and approval.
- Confirm renderer from inside the actual Android workload; a successful `ls` or `stat` is not enough.

### 8.6 Android data, credentials and lifecycle

- Android userdata must be stored separately from the container image and in a dedicated path.
- Container recreation must not silently erase Android data.
- Backup and restore must be tested before relying on it.
- Do not embed secrets in images, scripts, logs or chat.
- Manual lifecycle only; no boot autostart or persistent service without approval.
- No destructive cleanup/reset without explicit approval.

---

## 9. Next work — ordered dependency gates

The read-only feasibility phase is closed. The active workstream is now the LXC-only experimental investigation in §5.13. Do not jump to installation: complete package provenance/safety gates first, then obtain explicit confirmation of the exact transaction. Record each experiment immediately.

| Order | Gate | Prerequisite | What constitutes evidence | Current status |
|---:|---|---|---|---|
| 1 | Namespace primitives | Tests 20–23 | Nested user, mount and PID namespaces plus child-process lifecycle under default seccomp and the reduced capability set | **COMPLETED — TESTS 20–23** |
| 2 | Cgroup/LXC strategy | Tests 24–25 plus Gate 3 JSON evidence | Correlate the read-only container cgroup mount with host delegation and Podman manager/runtime; identify a safe writable nested subtree without host changes | **BLOCKED — no writable nested delegation demonstrated; current container cgroup mount is read-only** |
| 3 | Supported Podman cgroup configuration evidence | Test 25 template query failure | Read-only supported Podman info JSON query; identify manager/version without assumptions | **COMPLETED — Podman 6.0.2, systemd cgroup manager, cgroup v2, crun 1.28-dirty** |
| 4 | LXC-only experimental investigation | LXC-EXP-00 charter; package provenance and pacman safety prerequisite | Safely install exact LXC package temporarily, test non-root delegated-scope LXC lifecycle, then verify cleanup/removal | **OPEN — read-only phase closed; package manifest unavailable and prior pacman lock failure unexplained; no install yet** |
| 5 | Binder handoff into LXC | Gate 4 | Actual Binder device nodes visible with narrow permissions; transactions work | UNTESTED |
| 6 | GPU handoff | Gate 4 | Render node usable by actual workload; renderer confirms AMD hardware acceleration | UNTESTED |
| 7 | Wayland / D-Bus / audio | Container and session design | Minimal socket/env handoff works from SSH launch | UNTESTED |
| 8 | Android network | LXC/Binder runtime | Android networking works without host-wide forwarding/firewall changes or Pi-hole impact | UNTESTED |
| 9 | Actual Waydroid boot | Gates 4–8 | Android services boot and remain stable | UNTESTED |
| 10 | ADB local binding | Waydroid boot | ADB listener is localhost-only; authenticated local client works | UNTESTED |
| 11 | SSH tunnel + scrcpy on Mint | ADB local binding | Remote window and input work over SSH tunnel | UNTESTED |
| 12 | SSH tunnel + scrcpy on Windows | ADB local binding | Same on Windows client | UNTESTED |
| 13 | Android app/window behavior | Remote display | Determine whether desired individual-app window is possible | UNTESTED |
| 14 | Data persistence / recovery | Stable runtime | Tested backup/restore and container recreation | UNTESTED |
| 15 | Manual lifecycle / final security review | All functional gates | Start/stop, no autostart, least privilege, cleanup, no collateral service impact | UNTESTED |

### Stop conditions

Stop and report rather than widen permissions if:

- the only working design requires `--privileged`;
- the only working design requires broad host filesystem mounts or host namespaces;
- Binder requires a persistent host-wide modification not approved by the user;
- networking requires unapproved host forwarding/firewall changes;
- LXC requires unsafe cgroup or device delegation;
- the graphical session can only be reached by exposing the entire host runtime directory;
- the design interferes with Pi-hole or other protected projects.

A secure infeasibility finding is a valid outcome.

---

## 10. Command and experiment documentation schema

Every future audit operation must be recorded using this schema. Do not record only a green “passed” line.

### 10.1 Test record template

```markdown
### TEST-ID — Short objective

- **Date/time:**
- **Status:** CONFIRMED / FAILED / PARTIAL / PENDING / INCONCLUSIVE
- **Environment:** HOST / OUTER CONTAINER / INNER LXC / MINT CLIENT / WINDOWS CLIENT
- **Image/runtime/version:**
- **Prerequisite test IDs:**
- **Question being answered:**
- **Why this test is new:** (What prior tests did not establish)
- **Repeat policy:** (Never / only after kernel update / only after runtime change / etc.)
- **Risk and side-effect boundary:**
- **Approval required:** Yes / No; explain

**Exact command**
```bash
# Paste the exact command that was actually executed.
```

**Actual output**
```text
# Paste relevant unedited output, stderr and exit status.
```

**Observed result**
- What happened:
- Exit code:
- Files/devices/namespaces/processes created:
- Cleanup performed and verified:

**Interpretation**
- What this proves:
- What this does not prove:
- Any uncertainty or conflicting evidence:

**Decision / next step**
- Continue / stop / revise:
- Next test ID:
```

### 10.2 Evidence quality rules

1. Preserve exact command and actual output; do not substitute a proposed command.
2. Mark assistant-proposed but unexecuted commands as **PROPOSED**, not tested.
3. Record whether the command ran on the Deck host, inside Podman, inside LXC, or on a client.
4. Include image digest/tag and runtime version for container tests.
5. Include relevant exit code; a script that prints “success” but exits zero unconditionally may hide a failed inner operation.
6. Preserve stderr and warnings when they affect interpretation.
7. Record cleanup and before/after state for networking, mounts, devices and processes.
8. Separate the operation's result from the broader architectural conclusion.
9. If a test is repeated, explain the changed condition and what new evidence is expected.
10. If output is truncated, record that fact and do not infer missing lines.

### 10.3 Decision record template

```markdown
### DECISION-ID — Decision title

- **Date:**
- **Decision owner:** User / assistant recommendation / jointly accepted
- **Status:** ACCEPTED / REJECTED / PROPOSED / SUPERSEDED
- **Decision:**
- **Reason:**
- **Evidence/test IDs:**
- **Consequences:**
- **Revisit condition:**
```

### 10.4 Environment refresh template

Only refresh values relevant to a changed condition or an upcoming test.

| Field | Value | Collected at | Source/command | Status |
|---|---|---|---|---|
| SteamOS build |  |  |  |  |
| Kernel |  |  |  |  |
| Podman |  |  |  |  |
| OCI runtime |  |  |  |  |
| cgroup manager/version |  |  |  |  |
| Wayland session/socket |  |  |  |  |
| GPU render node/driver |  |  |  |  |
| Binder kernel configuration |  |  |  |  |

---

## 11. Anti-repetition protocol for future ChatGPT sessions

Before proposing any command or inspection:

1. Search this document for the objective and related test IDs.
2. Check whether the same question has already been answered.
3. Check whether the earlier test was conclusive or only partial.
4. Check whether the relevant host/kernel/runtime/session has changed.
5. Explain why a repeat is necessary if the same test is proposed again.
6. Prefer the next unclosed dependency gate in §9.
7. Never rerun a completed audit block merely because a new chat has started.
8. Never ask the user to paste a broad inventory already present here unless there is a concrete change or missing evidence.
9. Never present a historical value as current.
10. After each new test, update this living record before moving to the next test.

### 11.1 Already completed — do not repeat as generic groundwork

- Initial host OS/kernel identification.
- KDE/Wayland session and runtime/socket presence.
- Headless SSH environment comparison.
- GPU vendor/device/driver and render-node presence.
- Kernel Binder config and Rust Binder module presence.
- Existing Distrobox inventory and security posture.
- Podman rootless engine/runtime/network backend baseline.
- Subordinate UID/GID mapping baseline.
- Host nested user namespace test.
- Host private network namespace bridge and NAT test.
- BinderFS mount in host private namespace.
- BinderFS mount in disposable Podman with and without `CAP_SYS_ADMIN`.
- Corrected BinderFS device creation ioctl.
- Binder protocol version query.
- Host cgroup v2/controller/delegation inspection.
- Disposable Podman cgroup read-only/no-subtree inspection.
- Podman outbound network/DNS test.
- Podman `NET_ADMIN` forwarding sysctl failure.
- Capability tests through Test 21, including successful removal of `SETPCAP` and successful nested user-namespace creation under default seccomp.

### 11.2 A repeat may be justified only when

- SteamOS kernel/build changed;
- Podman/crun/Netavark changed;
- host session or GPU driver changed;
- the candidate container configuration changed;
- upstream Waydroid/LXC changed in a relevant way;
- a previous result was explicitly partial and the new test reaches the previously untested operation;
- a new test uses a different security boundary and answers a different question.

Record the changed condition and link the prior test ID.

---

## 12. Historical command families — indexed, not re-run

This index helps identify what the prior audit covered. It is not an instruction to run these commands again.

| Command family / tool | Historical purpose | Where used |
|---|---|---|
| `cat /etc/os-release`, `uname -r` | SteamOS build and kernel | Host baseline |
| `loginctl`, process/session inspection | Identify KDE session and compositor | Host session |
| `ls -la /run/user/1000`, socket checks | Runtime and Wayland socket presence | Host session |
| `lspci`, `/sys/bus/pci`, `/dev/dri`, `id` | GPU and device permissions | GPU baseline |
| `zcat /proc/config.gz`, `/sys/module/rust_binder`, `/proc/filesystems` | Binder kernel configuration | Binder baseline |
| `podman info`, `podman version`, `podman ps`, Distrobox inventory | Runtime and existing workloads | Container baseline |
| `/etc/subuid`, `/etc/subgid`, `/proc/self/uid_map`, `gid_map` | Rootless mappings | Namespace audit |
| `grep Cap*` in `/proc/self/status` | Capability masks | Capability isolation |
| `findmnt`, `stat -fc`, cgroup files | Cgroup mount and delegation | LXC prerequisites |
| `unshare --user --map-root-user` | Nested user namespace | Host and Podman namespace tests |
| `unshare --user --map-root-user --net` | Private network namespace | Host network tests |
| `ip link`, `iptables`, `sysctl` | Bridge/NAT/forwarding | Network tests |
| `mount -t binder`, Binder ioctl | BinderFS and Binder devices | Binder tests |
| `podman run --rm --pull=never` | Disposable capability/network/Binder tests | Rootless Podman boundary |

---

## 13. Source provenance and archive

### 13.1 Primary historical record

The original exported conversation was supplied as:

- `_1.0_ Waydroid SSH Feasibility Audit.md`
- It begins at the exact marker `MARKDOWN : OUR EXPORTED CONVERSATION`; material before that marker is reconstruction instructions, not the original conversation.
- The export contains the chronological discussion, proposed commands, executed commands, outputs, corrections and Test 20 proposal.
- Its last recorded operation is Test 20; no Test 20 result is included.

### 13.2 Prior consolidated record

- `1.0_Waydroid-SSH-Consolidated-Audit.md`
- Used as a cross-check and previous compact technical reconstruction.
- It is superseded as the active continuation document by this living audit.

### 13.3 Archive location

The original source documents are retained unchanged under:

- `waydroid/1.audit/archive/2026-11-06/_1.0_ Waydroid SSH Feasibility Audit.md`
- `waydroid/1.audit/archive/2026-11-06/1.0_Waydroid-SSH-Consolidated-Audit.md`

The canonical living audit snapshots are preserved unchanged as:

- `waydroid/1.audit/archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.0.md` — initial canonical snapshot, before Test 20 was incorporated.
- `waydroid/1.audit/archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.7.md` — snapshot immediately after Test 25 cleanup verification and before the v1.8 consistency-review corrections.
- `waydroid/1.audit/archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.8.md` — unchanged pre-decision snapshot, preserved before the Gate 3 result and cgroup/LXC decision were incorporated into v1.9.

Version 1.9 is the active canonical record. The v1.0, v1.7, and v1.8 snapshots are historical and must not be edited to reflect later results.

### 13.4 Source access and review honesty

The primary export and prior consolidated audit were retrieved from the repository. Relevant chronological sections, test registers and final Test 20 definition were examined. Relevant Waydroid source files, ADB/scrcpy documentation, issues and project references listed in §6 were inspected during the reconstruction. Some historical paths mentioned inside the export were unavailable at their referenced locations; they are not represented as reviewed. This document must be refreshed if a newly available missing reference becomes material to a specific test.

---

## 14. Current continuation handoff

**Project:** Waydroid SSH — closed read-only feasibility record; LXC-only experimental investigation now active.

**Current state:** no Waydroid or LXC installation; no permanent host changes made. The user has accepted closing the read-only phase and opening an LXC-only experimental investigation, including temporary LXC test installations if needed. This approval is in principle only: it does not authorize bypassing the unresolved pacman lock problem, retrying metadata refresh, or installing before the exact package manifest, transaction, host changes and rollback plan are reviewed and separately confirmed. It does not authorize Waydroid installation, Android boot, persistent services, host networking changes or persistent cgroup/systemd changes. Pi-hole, Odysseus and all existing projects remain protected.

**Do not do next:**
- Do not create a permanent `waydroid-box`.
- Do not install Waydroid. LXC installation is a future gated experiment, not an immediate action; do not proceed until EXP-01/02 and exact install confirmation.
- Do not import the old native installer.
- Do not repeat host/session/GPU/BinderFS/cgroup/network baseline checks or Tests 1–25.
- Do not enable host forwarding, change firewall rules, or add persistent services.
- Do not grant privileged mode, broad mounts, host namespaces, or broad device access.
- Do not attempt to make the read-only cgroup mount writable or alter systemd delegation.

**Latest completed evidence:** Gate 3 supplemental read-only Podman JSON query. Result: **CONFIRMED**. Podman reports `6.0.2`, systemd cgroup manager, cgroup v2, host controller list `cpu memory pids dmem`, and OCI runtime `crun 1.28-dirty`. Podman and Python exit statuses were both `0`. See §5.8.

**Combined cgroup conclusion:** Test 24 observed the cgroup2 mount inside the disposable rootless container as read-only, with empty subtree control, no visible child cgroups, and no writable controller files. Test 25 observed `Delegate=yes` on `user@1000.service` and located the Podman container beneath that hierarchy, but did not demonstrate writable delegation to the container. Gate 3 identifies the host Podman manager/runtime; it does not change the container mount result.

**Current decision:** Phase 1 Gate 3 is complete; the original rootless Podman cgroup limitation remains confirmed. Phase 1.5 is active because current upstream Waydroid/LXC source identifies a direct-launcher versus delegated-scope integration question. This does not yet establish a working architecture. No LXC package was installed and no LXC container was created.

**Latest package evidence:** LXC-PKG-01 reports candidate lxc 1:7.0.0-1 from extra-3.9, with a print-only transaction containing only lxc; all seven listed dependencies were already installed. LXC-PKG-02 could not inspect the file manifest because the configured repository file-list databases were absent. LXC-PKG-03 attempted the user-approved metadata-only refresh: the unprivileged invocation was rejected for lack of root privileges, and the sudo invocation failed because pacman could not acquire the database lock. LXC-PKG-04 found no matching package-management process, but its check of /var/lib/pacman/db.lck did not inspect the actual database because that path is not configured on this SteamOS host. LXC-PKG-05 identified the configured DBPath as /usr/lib/holo/pacmandb; LXC-PKG-06 inspected that directory as root:root mode 755 on the root Btrfs filesystem reported rw, with no db.lck at inspection time. LXC-PKG-07 confirmed RootDir=/ and the same DBPath, showed local/sync entries, a basic ACL (owner rwx, group/other r-x), and the Btrfs no-copy-on-write c attribute; unexpectedly, `sudo test -w "$DBPATH"` returned NO. This is an access-predicate result, not a write attempt, and does not prove root cannot create a lock or explain the earlier pacman error. The cause remains INCONCLUSIVE. No lock-creation test or package operation has been attempted. The file-list refresh remains incomplete; no package was installed. **Next action:** stop the lock investigation unless a specific non-mutating diagnostic can explain the discrepancy without repeating prior checks. Do not create a test lock/file, remove files, alter permissions/ACL/attributes, remount, terminate processes or retry pacman -Fy on this evidence. Any future metadata refresh retry must be presented with exact scope and rationale and receive explicit approval; the earlier authorization covered the single metadata-only attempt. After a justified successful refresh, inspect the manifest. The previous Podman cgroup test does not substitute for a direct host-level LXC test. Even a favourable package manifest does not itself justify installation; present the exact package list, source, persistence implications, temporary scope, expected cgroup path, cleanup and rollback before any install approval. Use no privileged mode, broad mounts, host namespace sharing, persistent delegation changes or automatic services. Conditional permission to install LXC does not authorize Waydroid host packages or services.

**Archive provenance:** the unchanged v1.8 pre-decision snapshot is preserved at `archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.8.md`. The prior v1.7 snapshot remains unchanged.

**Latest source-level reconciliation and operations:** §5.9 reviewed upstream LXC/systemd/kernel cgroup-v2 requirements. LXC-CGROUP-01 and LXC-CGROUP-02 confirmed direct-host delegated child-cgroup creation/removal and single-process placement/cleanup. LXC-INT-01 (§5.11) then pinned the Deck-reported LXC candidate 1:7.0.0-1 to upstream LXC v7.0.0 source and reconciled its cgroup lifecycle with current Waydroid source commit db7294c4c2bd43157bab94cf8a3015e22d9f1ad8. LXC 7.0.0's unprivileged systemd integration creates a transient user scope with Delegate=yes, moves its own process into an init child, and writes all available controllers into cgroup.subtree_control; it only does this when effective UID is non-root. Stock Waydroid's D-Bus activation service and systemd container unit run as root, and its container manager directly spawns lxc-start in the background. A user-side systemd-run wrapper around the Waydroid CLI does not wrap the separate root service or its LXC child. This is a concrete privilege-context/integration mismatch, not proof that a redesigned split-privilege architecture is impossible. Device BPF use remains conditional because the exact effective LXC defaults/config are unknown.

**Current decision:** do not install or launch LXC/Waydroid yet. Direct-host cgroup primitives pass, but LXC controller activation, full monitor/payload lifecycle, device BPF behavior and a safe Waydroid split-privilege design remain untested/unresolved. The nested rootless Podman cgroup2 mount remains read-only. Package manifest inspection remains blocked and the original pacman DB lock failure unexplained. Do not retry pacman/file-list refresh, activate controllers, run LXC, alter the Waydroid D-Bus service/systemd unit/launcher, or change Podman/host cgroup configuration. The next step is a design-level review of whether Waydroid's privileged host preparation can be separated from a deck-user-owned LXC process without broadening privileges or changing host networking; this is not authorization to implement it.

**Latest user decisions:** DECISION-WD-01 remains accepted: the Waydroid feasibility effort is closed as blocked under current constraints. DECISION-LXC-EXP-01 now separately authorizes an LXC-only experimental investigation, including temporary LXC-only test installation in principle. It does not reopen Waydroid or authorize a package transaction before package provenance, pacman safety, exact scope and rollback are verified and explicitly confirmed.\n\n**Latest architecture review:** SPLIT-ARCH-01 (§5.12) completed a design-only assessment. Stock root Waydroid service remains unsuitable for LXC's non-root scope path. A custom manual-only split with deck-owned LXC and a narrowly allowlisted preparation broker is technically conceivable, but it does not solve rootfs/data mount ownership, Binder/GPU handoff, crash cleanup, or the default Waydroid network helper's host bridge/forwarding/firewall changes. The current no-host-network-change and least-privilege constraints are not met. Recommendation: **HOLD / do not implement**; closing the effort as blocked is a valid outcome. No command, package operation, cgroup write, installation, service change or host modification was performed for this review. No archive snapshot was due: this was a design review, not a runtime test, and the five-test snapshot threshold was not reached.\n\n**Current decision:** do not install or launch LXC/Waydroid. Direct-host cgroup primitives pass, but LXC controller activation, full monitor/payload lifecycle, device BPF behavior and package manifest remain untested/blocked. The nested rootless Podman cgroup2 mount remains read-only. Do not retry pacman/file-list refresh, activate controllers, run LXC, create a privileged helper, alter the Waydroid D-Bus service/systemd unit/launcher, or change Podman/host cgroup/network configuration. The design-only split-privilege review is complete; further work requires a new user decision about whether to close the project or explicitly relax a named constraint.\n\n**Active next gate:** LXC-EXP-01 — resolve package provenance and installation safety without changing package state. The package manifest is still unavailable and the earlier pacman DB lock failure remains unexplained. Do not retry pacman or mutate DBPath. First determine whether a distinct, read-only diagnostic can explain the lock failure; if not, report the prerequisite blocked. Only after exact package contents and transaction are known should an installation/rollback plan be presented for explicit confirmation. See §5.13 for the complete staged experiment plan.

**Continuation rule:** Before any future command, state which gate it addresses, which prior tests it relies on, and why it is not a repetition. Record any new result in this canonical document before proposing another test.
---

## 15. Change log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-11-06 | Initial canonical living audit reconstructed from the original export and prior consolidated audit. Preserved as `archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.0.md`. |
| 1.1 | 2026-11-06 | Recorded Test 20 as passed with `SETPCAP` removed; captured exact command/output and both exit statuses; corrected exit-status propagation; advanced the next gate to default-seccomp validation; clarified version/archive provenance. |
| 1.2 | 2026-11-06 | Recorded Test 21 as passed under Podman's default seccomp profile with the reduced capability set; captured exact command/output and both exit statuses; advanced the next gate to Test 22; adopted immediate per-test recording, five-test documentation reviews/archive snapshots, and canonical-handoff-first continuity across ChatGPT conversations. |
| 1.3 | 2026-11-06 | Recorded Test 22: nested user and mount namespace creation confirmed under default seccomp with the reduced capability set; documented distinct namespace IDs and the malformed shell comparison guard; advanced handoff to Test 23. |
| 1.4 | 2026-11-06 | Recorded the initial Test 23 stdin-harness failure as not executed, then recorded the corrected successful nested PID namespace and child-process lifecycle test under default seccomp; advanced handoff to read-only cgroup inspection (Test 24). |
| 1.5 | 2026-11-06 | Recorded Test 24's read-only cgroup v2 inspection: per-mount `ro`, visible `cpu memory pids` controllers, empty subtree control, no writable access or child cgroup directories; advanced handoff to read-only host delegation/path inspection (Test 25). |
| 1.6 | 2026-11-06 | Recorded Test 25 host cgroup path and systemd delegation observations; qualified the unsupported Podman info template query and missing interactive-shell EXIT cleanup; advanced handoff to explicit temporary-container cleanup and five-test documentation/archive review. |
| 1.7 | 2026-11-06 | Recorded Test 25 cleanup follow-up: the temporary container was present, SIGTERM timed out, Podman escalated to SIGKILL, and the subsequent filtered listing was empty; cleanup is confirmed. |
| 1.8 | 2026-11-06 | Completed the Tests 21–25 consistency review; corrected executive/dependency gate statuses and numbering; updated the continuation handoff; preserved the unchanged v1.7 snapshot; added the proposed read-only Podman JSON query. |
| 1.9 | 2026-11-06 | Recorded the successful supplemental read-only Podman JSON query (Podman 6.0.2, systemd cgroup manager, cgroup v2, crun 1.28-dirty); completed Gate 3; reconciled it with Tests 24–25; determined that a disposable LXC experiment is not justified under the observed read-only cgroup boundary; preserved the unchanged v1.8 pre-decision snapshot and updated the continuation handoff. |
| 2.0 | 2026-11-06 | Preserved the unchanged v1.9 archive snapshot; added an LXC/Waydroid architecture explanation and source-level review of the upstream LXC launcher, base config, container manager and initializer; documented the delegated-scope integration gap, generated device/session mounts, cgroup-v2 distinction, architecture alternatives and conditional permission for a controlled LXC audit installation; reopened Phase 1.5 without authorizing installation or service changes. |
| 2.1 | 2026-11-06 | Preserved the unchanged v2.0 archive snapshot; extended upstream source review to the Waydroid systemd unit, network script and work-directory defaults; documented boot-autostart and host firewall/forwarding side effects as explicit blockers for the user's manual-only, no-host-network-change design. |
| 2.2 | 2026-11-07 | Preserved the unchanged v2.1 archive snapshot; reviewed upstream Debian packaging, Makefile install targets, D-Bus activation, PolicyKit, systemd unit, container-manager lifecycle, Arch LXC package dependency metadata, and Valve/SteamOS update behavior; distinguished LXC-only from Waydroid package scope; concluded LXC installation is not yet justified pending Deck-local read-only package/dependency verification. |
| 2.3 | 2026-11-07 | Recorded LXC-PKG-01's reported Deck-local candidate/version and print-only one-package transaction; recorded LXC-PKG-02's missing repository file-list databases and connection-close transcript without misclassifying it as package absence or a system failure; established that the next manifest step requires approval for a metadata-only pacman file-list cache refresh. |
| 2.4 | 2026-11-07 | Recorded LXC-PKG-03: the unprivileged file-list refresh was rejected for lack of root privileges and the sudo invocation could not acquire the pacman database lock; clarified that the approved refresh remains incomplete and set a read-only lock/process inspection as the next action. |
| 2.5 | 2026-11-07 | Recorded LXC-PKG-04: read-only process inspection found no matching package-management process and no lock file at /var/lib/pacman/db.lck; kept the original pacman lock failure unexplained and advanced to read-only DBPath, directory-permission and mount-option diagnostics. |
| 2.6 | 2026-11-07 | Recorded LXC-PKG-05: identified SteamOS's configured pacman DBPath as /usr/lib/holo/pacmandb and established that /var/lib/pacman does not exist; corrected the interpretation of PKG-04's lock-path check, left the original lock failure inconclusive, advanced to read-only inspection of the actual DBPath, and completed the five-test package-series documentation review. |
| 2.7 | 2026-11-07 | Recorded LXC-PKG-06: inspected the actual configured DBPath; directory exists as root:root mode 755 on the root Btrfs filesystem mounted rw, with no db.lck present at inspection time; kept the original lock failure inconclusive and prohibited an unjustified refresh retry. |
| 2.8 | 2026-11-07 | Recorded LXC-PKG-07: documented RootDir=/, DBPath contents, Btrfs no-copy-on-write attribute and basic ACL; recorded the unexpected negative sudo write-access predicate without claiming it proves a write failure or explains the original pacman lock error; stopped the investigation pending a justified non-mutating diagnostic or explicit approval for any retry. |
| 2.9 | 2026-11-07 | Recorded LXC-SCOPE-01 as blocked before execution: systemd 261 rejected --wait with --scope; documented that no scope or diagnostic payload ran and set the next bounded step to a corrected transient delegated-scope invocation without --wait or --collect. |
| 3.0 | 2026-11-07 | Recorded LXC-SCOPE-02: transient delegated user scope creation and process membership confirmed; identified systemd-run's premature expansion of the braced cgroup-path variable, which caused all directory/access checks to target /sys/fs/cgroup rather than the scope; qualified the WRITE NO results as non-evidence about delegated permissions; advanced the handoff to the narrowly corrected read-only LXC-SCOPE-03. |
| 3.1 | 2026-11-07 | Recorded LXC-SCOPE-03: corrected cgroup path resolved to the actual transient delegated scope; confirmed deck:deck ownership, mode 755, available cpu/memory/pids/dmem child controllers, no enabled child controllers, and positive write-access predicates for the scope directory, cgroup.procs and cgroup.subtree_control; distinguished access predicates from actual writes; advanced the handoff to package-manifest and LXC cgroup-v2 requirement reconciliation without authorizing writes, controller activation or installation. |
| 3.2 | 2026-11-07 | Completed read-only source reconciliation of upstream LXC, systemd and Linux cgroup-v2 requirements; confirmed that an empty subtree_control is normal initial state but actual delegated-subtree operations remain untested; distinguished direct-host scope feasibility from the blocked nested-Podman cgroup boundary; retained the package-manifest blocker and explicitly gated any actual cgroup mutation behind separate approval. |
| 3.3 | 2026-11-07 | Recorded LXC-CGROUP-01: a transient delegated systemd scope successfully created, inspected and removed one empty child cgroup; captured rw cgroup2 mount, available controllers, empty child process list and populated 0 state; noted the reported literal-looking dollar suffix and absent separately captured systemd-run exit status; confirmed no controller activation or process movement; advanced the next possible gate to a separately approved process-placement test while retaining the package-manifest blocker. |
| 3.4 | 2026-11-07 | Recorded LXC-CGROUP-02: confirmed actual process placement into a delegated child cgroup, independently verified membership through /proc/PID/cgroup and child cgroup.procs, terminated/reaped the test process, and removed the empty child; confirmed controller availability unchanged and subtree_control still empty; updated Gate 4 and the continuation handoff while retaining the nested-Podman and package-manifest blockers. |
| 3.5 | 2026-11-07 | Completed LXC-INT-01 source reconciliation against upstream LXC v7.0.0 and pinned Waydroid main commit; documented LXC's non-root systemd-scope/controller activation and monitor/payload cgroup lifecycle; established that stock Waydroid's root D-Bus/systemd service bypasses LXC's unprivileged scope path and that wrapping the user CLI does not wrap the actual root lxc-start process; kept controller activation, LXC runtime, split-privilege design and package manifest blocked; updated executive verdict, Gate 4, source index and continuation handoff. |
| 3.6 | 2026-11-07 | Completed SPLIT-ARCH-01 design-only review of a manual split-privilege Waydroid architecture; mapped manager, LXC, rootfs/data, Binder/GPU, networking, session and cleanup responsibilities; concluded a custom deck-owned LXC launcher plus optional fixed-API privileged broker is technically conceivable but does not meet current no-host-network-change/least-privilege acceptance criteria and is not recommended for implementation; updated executive verdict, Gate 4 and continuation handoff. No runtime test or host change was performed; no archive snapshot was due. |

| 3.7 | 2026-11-07 | Recorded user-accepted DECISION-WD-01: close the current Waydroid feasibility effort as blocked under existing constraints; preserve the audit and prohibit Waydroid installation/host changes under this decision; explicitly distinguish a possible future, separately approved temporary LXC-only experiment from the closure decision; updated document version and continuation handoff. |
| 3.8 | 2026-11-07 | Closed the read-only feasibility phase and opened a separate LXC-only experimental investigation under DECISION-LXC-EXP-01; documented staged package provenance/safety, exact-install approval, temporary non-root LXC runtime, cgroup/monitor/payload lifecycle, cleanup and removal gates; retained the unresolved pacman lock and package-manifest blockers; clarified that temporary LXC testing does not reopen Waydroid or authorize an immediate package transaction; updated executive status, Gate 4 and new-chat handoff. |

---

*End of living audit record.*

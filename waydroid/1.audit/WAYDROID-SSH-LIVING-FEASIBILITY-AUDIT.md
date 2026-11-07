# Waydroid SSH — Living Container Feasibility Audit & Continuation Record

> **Document role:** Canonical, cumulative engineering record for the Waydroid-on-Steam-Deck / remote-client project. This document is deliberately written for future ChatGPT sessions: it preserves the decisions, evidence, test history, exact continuation point, and anti-repetition rules needed to resume the audit without replaying completed groundwork.
>
> **Status:** Phase 1.5 architecture feasibility review in progress — **LXC/Waydroid integration inspected at source level; Deck-local LXC candidate and print-only transaction reported; package file-manifest inspection remains blocked; the original pacman database-lock failure remains unexplained; LXC-SCOPE-01 was rejected before execution; LXC-SCOPE-02 successfully created a transient delegated user scope and confirmed process membership, but its cgroup-directory variable was expanded prematurely by systemd-run, so the diagnostic inspected the cgroup mount root rather than the scope directory; delegated-scope write permissions remain untested; no LXC installation or runtime experiment performed**.
>
> **Document version:** 3.0  
> **Last source refresh:** 2026-11-07  
> **Current branch:** `main`  
> **Scope:** Container-only Waydroid feasibility; no installation or persistent host changes authorized by this document.

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

**Phase 1 cgroup evidence still blocks a justified LXC experiment inside the existing rootless Podman boundary.** Phase 1.5 has inspected current upstream Waydroid LXC integration: its manager generates LXC configuration and directly invokes LXC lifecycle commands. LXC's documented rootless cgroup-v2 procedure instead wraps each relevant lxc-* invocation in a delegated systemd user scope (systemd-run --user --scope -p Delegate=yes). The stock launcher does not show that wrapper. This is an integration gap to investigate, not proof that a wrapper is impossible. Sources: [Waydroid lxc.py](https://github.com/waydroid/waydroid/blob/main/tools/helpers/lxc.py), [LXC Getting Started](https://linuxcontainers.org/lxc/getting-started/). Positive results remain for BinderFS, Binder device creation, Binder protocol identification, ordinary rootless Podman outbound networking, and selected nested namespace primitives. The supplemental Podman JSON query confirms Podman 6.0.2 uses the systemd cgroup manager with cgroup v2 and \`crun 1.28-dirty\`. However, Test 24 directly observed the cgroup filesystem exposed inside the disposable rootless container as read-only, with no child cgroups visible; Test 25 found no evidence of writable nested delegation. The Podman JSON fields identify the host runtime configuration but do not override or explain away that mount boundary.

The source review confirms dynamic device/session mount generation (Binder nodes, DRM render node, Wayland socket, PulseAudio socket and userdata). Waydroid's base LXC config retains powerful capabilities inside the Android container, including SYS_ADMIN, NET_ADMIN and SYS_TIME; this is not equivalent to granting them to an outer container or host, but requires security review. No LXC package has been installed and no LXC container has been created. The user conditionally authorized installing LXC if a runtime test is shown necessary; this is not blanket approval for Waydroid packages, services, persistent host changes or container creation. Android runtime, Binder transactions under load, GPU rendering, session integration, networking, ADB, SSH and scrcpy remain unproven.

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
- A corrected, separately numbered LXC-SCOPE-02 may retry the same read-only diagnostic using systemd-run --user --scope --property=Delegate=yes without --wait or --collect. Keep the command payload bounded and read-only.
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

Do not skip ahead to installation. Complete one gate at a time and update this document after each result.

| Order | Gate | Prerequisite | What constitutes evidence | Current status |
|---:|---|---|---|---|
| 1 | Namespace primitives | Tests 20–23 | Nested user, mount and PID namespaces plus child-process lifecycle under default seccomp and the reduced capability set | **COMPLETED — TESTS 20–23** |
| 2 | Cgroup/LXC strategy | Tests 24–25 plus Gate 3 JSON evidence | Correlate the read-only container cgroup mount with host delegation and Podman manager/runtime; identify a safe writable nested subtree without host changes | **BLOCKED — no writable nested delegation demonstrated; current container cgroup mount is read-only** |
| 3 | Supported Podman cgroup configuration evidence | Test 25 template query failure | Read-only supported Podman info JSON query; identify manager/version without assumptions | **COMPLETED — Podman 6.0.2, systemd cgroup manager, cgroup v2, crun 1.28-dirty** |
| 4 | LXC runtime strategy and controlled experiment | Phase 1.5 source review + cgroup boundary assessment | Decide whether direct host-level unprivileged LXC can be tested safely; if needed, use a temporary delegated scope and bounded reversible package plan | **REOPENED FOR PHASE 1.5 REVIEW; no installation or LXC container yet** |
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

**Project:** Waydroid SSH — container-only feasibility audit.

**Current state:** no Waydroid or LXC installation; no permanent host changes made. The user has conditionally authorized installing LXC if the audit demonstrates a runtime test is necessary. This does not authorize installing Waydroid, enabling services, creating a persistent container, or changing host cgroups/systemd. Existing projects, especially Pi-hole, remain protected.

**Do not do next:**
- Do not create a permanent `waydroid-box`.
- Do not install Waydroid or LXC under the current cgroup evidence.
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

**Current direct-scope handoff:** LXC-SCOPE-01 was rejected before execution because systemd 261 disallows --wait with --scope. LXC-SCOPE-02 successfully created transient scope run-p504174-i508745.scope and confirmed process membership at /user.slice/user-1000.slice/user@1000.service/app.slice/run-p504174-i508745.scope. However, systemd-run expanded the braced ${CGROUP_REL} reference before the child shell ran, leaving CGROUP_DIR as /sys/fs/cgroup. All directory metadata, controller and WRITE NO results therefore describe the cgroup mount root, not the delegated scope. Delegated-scope permissions remain UNTESTED. The next bounded step is LXC-SCOPE-03: repeat the read-only payload with only CGROUP_DIR assignment corrected to CGROUP_DIR="/sys/fs/cgroup$CGROUP_REL"; verify the printed path ends in the transient scope name before interpreting results. No persistent unit/service, cgroup write/controller change, LXC launch, or package installation is authorized. The package-lock investigation remains parked; do not create test files/locks or retry pacman without a separately approved rationale.\\n\\n**Continuation rule:** Before any future command, state which gate it addresses, which prior tests it relies on, and why it is not a repetition. Record any new result in this canonical document before proposing another test.
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

---

*End of living audit record.*

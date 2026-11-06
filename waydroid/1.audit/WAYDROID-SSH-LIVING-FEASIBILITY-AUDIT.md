# Waydroid SSH — Living Container Feasibility Audit & Continuation Record

> **Document role:** Canonical, cumulative engineering record for the Waydroid-on-Steam-Deck / remote-client project. This document is deliberately written for future ChatGPT sessions: it preserves the decisions, evidence, test history, exact continuation point, and anti-repetition rules needed to resume the audit without replaying completed groundwork.
>
> **Status:** Feasibility audit in progress — **conditionally promising, not proven**.
>
> > **Document version:** 1.1  
> **Last source refresh:** 2026-11-06  
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
- When a new test is performed, append its exact command, complete relevant output, exit status, scope, interpretation, limitations, and repeat policy to this document.

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

**Conditionally promising, not yet proven.** There are credible positive results for BinderFS, Binder device creation, Binder protocol identification, rootless Podman networking in ordinary outbound use, and nested user namespaces under a particular capability set. However, the actual Android runtime has not been launched. Nested LXC, usable cgroup delegation, Binder transactions under Android load, GPU rendering from the proposed container, KDE session integration, Android networking, ADB, SSH tunnelling, and scrcpy end-to-end remain unproven.

### 1.2 Positive evidence

- KDE Plasma / KWin Wayland session and its runtime socket were present during the historical audit.
- AMD Van Gogh GPU and `/dev/dri/renderD128` were identified on the host.
- Rust Binder is built into the recorded SteamOS kernel; BinderFS is registered.
- BinderFS mounted in a disposable rootless Podman container when `CAP_SYS_ADMIN` was explicitly granted.
- The three Binder nodes (`binder`, `vndbinder`, `hwbinder`) were created in that disposable BinderFS instance.
- The Binder device opened and returned protocol version 8 through `BINDER_VERSION`.
- Host nested user namespace creation succeeded.
- Nested user namespace creation inside rootless Podman succeeded with `SETUID + SETGID + SETPCAP + SETFCAP` in Test 19.
- Test 20 then removed `SETPCAP`; nested user namespace creation still succeeded with `SETUID + SETGID + SETFCAP`, with both inner and outer exit codes `0`. This remains a seccomp-unconfined result; default seccomp is still untested.
- Host-side private user/network namespace bridge, forwarding, and NAT operations succeeded without changing the host's persistent forwarding state.
- Ordinary outbound networking/DNS from a disposable Podman container succeeded.

### 1.3 Major unresolved gates

1. Test the smallest successful capability set with Podman's **default seccomp** profile.
2. Test nested mount and PID namespaces with that reduced capability set.
4. Resolve the cgroup boundary: read-only cgroup mount and no delegated subtree controllers were observed inside the disposable container.
5. Only after the prerequisites are understood, test an actual nested LXC runtime in a disposable environment.
6. Test Binder device handoff through the outer container and LXC boundary.
7. Test the minimum AMD render-node access required; no GPU workload has been run inside the target boundary.
8. Test Wayland, D-Bus, audio, and session handoff from a headless SSH-launched process without broad host runtime mounts.
9. Resolve Android networking inside rootless Podman; the attempted `NET_ADMIN` test failed at the forwarding sysctl before bridge/NAT operations were reached.
10. Test localhost-only ADB plus SSH forwarding and scrcpy from both Mint and Windows.
11. Assess Rust Binder stability under real Android workloads, including the upstream large-transaction concern.

**No permanent Waydroid container, package installation, host kernel modification, Binder service, firewall change, or persistent Android data store is justified yet.**

---

## 2. Target architecture and acceptance criteria

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
| CAP-10 | `SETUID + SETGID + SETFCAP` (remove `SETPCAP`; Test 20) | Passed; capability mask `00000000800000c0`; inner and outer exit codes `0` | **CONFIRMED** |

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
| 1 | Default seccomp with smallest successful set | Test 20 | Nested user namespace succeeds under Podman's default seccomp profile | **NEXT** |
| 2 | Nested mount namespace | Gate 1 | Mount namespace operation succeeds with same least-privilege set | PENDING |
| 3 | Nested PID namespace | Gate 1/2 | PID namespace created and process lifecycle observed | PENDING |
| 4 | Cgroup/LXC strategy | Namespace results and exact LXC version | Demonstrate LXC can work with available cgroup boundary or identify unavoidable delegation requirement | BLOCKED |
| 6 | Disposable LXC runtime | Gates 2–5 | Inner LXC starts/stops cleanly with no privileged outer container | UNTESTED |
| 7 | Binder handoff into LXC | Gate 6 | Actual Binder device nodes visible with narrow permissions; transactions work | UNTESTED |
| 8 | GPU handoff | Gate 6 | Render node usable by actual workload; renderer confirms AMD hardware acceleration | UNTESTED |
| 9 | Wayland / D-Bus / audio | Container and session design | Minimal socket/env handoff works from SSH launch | UNTESTED |
| 10 | Android network | LXC/Binder runtime | Android networking works without host-wide forwarding/firewall changes or Pi-hole impact | UNTESTED |
| 11 | Actual Waydroid boot | Gates 6–10 | Android services boot and remain stable | UNTESTED |
| 12 | ADB local binding | Waydroid boot | ADB listener is localhost-only; authenticated local client works | UNTESTED |
| 13 | SSH tunnel + scrcpy on Mint | ADB local binding | Remote window and input work over SSH tunnel | UNTESTED |
| 14 | SSH tunnel + scrcpy on Windows | ADB local binding | Same on Windows client | UNTESTED |
| 15 | Android app/window behavior | Remote display | Determine whether desired individual-app window is possible | UNTESTED |
| 16 | Data persistence / recovery | Stable runtime | Tested backup/restore and container recreation | UNTESTED |
| 17 | Manual lifecycle / final security review | All functional gates | Start/stop, no autostart, least privilege, cleanup, no collateral service impact | UNTESTED |

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
- Capability tests through Test 20, including successful removal of `SETPCAP`.

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

The initial canonical living audit (version 1.0, before Test 20 was incorporated) is also preserved unchanged as:

- `waydroid/1.audit/archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.0.md`

Version 1.1 is the active canonical record. Archive snapshots are historical and must not be edited to reflect later results.

### 13.4 Source access and review honesty

The primary export and prior consolidated audit were retrieved from the repository. Relevant chronological sections, test registers and final Test 20 definition were examined. Relevant Waydroid source files, ADB/scrcpy documentation, issues and project references listed in §6 were inspected during the reconstruction. Some historical paths mentioned inside the export were unavailable at their referenced locations; they are not represented as reviewed. This document must be refreshed if a newly available missing reference becomes material to a specific test.

---

## 14. Current continuation handoff

**Project:** Waydroid SSH — container-only feasibility audit.

**Current state:** no Waydroid installation; no permanent host changes authorized by this audit. Existing projects remain protected.

**Do not do next:**
- Do not create a permanent `waydroid-box` yet.
- Do not install Waydroid or import the old native installer.
- Do not repeat host/session/GPU/BinderFS/cgroup/network baseline checks.
- Do not repeat Tests 1–19.
- Do not enable host forwarding, change firewall rules, or add persistent services.
- Do not grant privileged mode, broad mounts, host namespaces, or broad device access.

**Next exact test:** Test 21 — repeat the nested user-namespace mapping test with `SETUID + SETGID + SETFCAP` but **without** `--security-opt=seccomp=unconfined`, thereby using Podman's default seccomp profile. Keep `--network=none`, `--cap-drop=ALL`, and `--pull=never`; propagate the inner `unshare` exit code and separately report the outer Podman exit code.

**After Test 21:**
1. If default seccomp passes, test nested mount namespace creation with the same capability set.
2. Then test nested PID namespace creation and process lifecycle.
3. Resolve cgroup/LXC requirements without changing host configuration.
4. Proceed to disposable LXC only if the security prerequisites justify it.

**Continuation rule:** Before any command, state which gate it addresses, which prior tests it relies on, and why it is not a repetition. After the user runs it, interpret only the actual output and update this document's ledger.
---

## 15. Change log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-11-06 | Initial canonical living audit reconstructed from the original export and prior consolidated audit. Preserved as `archive/2026-11-06/WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.0.md`. |
| 1.1 | 2026-11-06 | Recorded Test 20 as passed with `SETPCAP` removed; captured exact command/output and both exit statuses; corrected exit-status propagation; advanced the next gate to default-seccomp validation; clarified version/archive provenance. |

---

*End of living audit record.*

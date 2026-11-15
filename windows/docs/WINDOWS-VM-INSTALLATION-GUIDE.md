# Windows VM Installation Guide — Steam Deck OLED

A living installation guide and evidence log for evaluating a Windows virtual machine on the Steam Deck OLED (SteamOS).

> **Current phase (2026-11-15):** A separate Windows 11 Pro 25H2 guest, `windows-pro-box`, has completed installation. The user confirms **Windows 11 Pro, version 25H2, OS build 26200.9974**, successful RDP connectivity, and installation date 2026-11-15. The existing Podman container still has the installation ISO bind at `/custom.iso`; the project start script warned but continued, and a later start failed because the ISO source path was unavailable. Preserve `/home/deck/Windows11ProVM` and its persistent guest storage while replacing only the stopped container object with an ISO-free runtime container. The NO ISO BIND runtime rule is now the first deployment gate. See the Roadbook for the confirmed result and pending Home ISO comparison. No VM backup or snapshot is in scope.**

## TOP-PRIORITY RULE — NO ISO BIND IN NORMAL RUNTIME

**MANDATORY HARD GATE — READ THIS BEFORE EVERY VM CREATE OR START ACTION**

The normal Windows VM runtime container MUST have **NO installation ISO bind mount**. This rule takes priority over older examples, copied commands, templates and per-VM scripts. A warning that merely reports an ISO bind is not sufficient: the start procedure must refuse to start an ISO-bound container.

Before any normal runtime container is created or started, perform three independent checks:

1. **Command-source check:** inspect the complete Bash command/script. It must contain no ISO variable, no ISO readability test, and no `--volume "$ISO:/custom.iso:ro"` (or equivalent) argument.
2. **Created-container check:** inspect the actual Podman mount table. It must show the intended project `storage/` mapped to `/storage`, the intended `shared/` mapped to `/shared`, and no destination named `/custom.iso`.
3. **Pre-start check:** immediately before the first start, inspect the container again and confirm it is the intended project, its state is `created`, its restart policy is `no`, and `/custom.iso` is absent. Do not start if any check is missing, ambiguous or fails.

**The normal runtime container and its start script must not define, test for, require or mount an installation ISO.** Deleting or moving an ISO file does not remove a bind mount from an existing Podman container definition. Editing an environment file or start script does not rewrite an existing container's mounts.

### Why the container must be recreated

Podman stores bind-mount configuration in the container object at `podman create` time. If an ISO was mounted at `/custom.iso`, that mount remains part of the container definition even after the guest has installed Windows, the ISO is deleted, or a start script is edited. On a later start, the OCI runtime may fail before QEMU starts because it cannot stat the missing host ISO path. This is the exact failure observed for `windows-pro-box`.

The correction is to replace only the stopped Podman container object. The project root, protected environment file, persistent guest disk and shared directory remain in place. The replacement container uses the same pinned image, environment file, KVM device, port publication, and project-specific `storage/` and `shared/` paths—but no ISO bind.

### Recovery if the NO ISO BIND rule was not applied

1. Stop launching the old container. Do not keep retrying an ISO-bound definition.
2. Establish that Windows has completed a clean guest shutdown. If guest state is uncertain, inspect first; do not assume `Exited (0)` alone proves a clean guest shutdown.
3. Inspect the exact container name, state, image, ports and mounts. Confirm which project root and `storage/` directory it uses.
4. Confirm no other container is using that same guest storage. Never attach one guest disk to two containers simultaneously.
5. Preserve the entire project root. Remove only the stopped container object using `podman rm <container-name>`; **never use `-v`**, never remove the project root, and never delete/recreate `storage/` or `shared/`.
6. Recreate the same named runtime container using the same project root and protected environment file, with only the `/storage` and `/shared` bind mounts. Omit every ISO-related argument.
7. Perform the three checks above. Start only after the mount inspection proves there is no `/custom.iso`.

If Windows Setup did not complete, do not treat this recovery sequence as permission to discard or overwrite the partial guest. Preserve the project root and storage, inspect the failure, and agree a separate recovery/reinstallation plan before any further installation attempt.

### Installation-media distinction — installer is not runtime

A custom local ISO is installation media, not a runtime dependency. With Dockur's custom-ISO workflow, the ISO is presented to a temporary installer container as `/custom.iso`; that temporary definition is a distinct, explicitly identified phase. It must never be reused as the normal runtime container. The new `windows-pro-box-NO-ISO-BIND.template` is deliberately a **runtime-only** template: it cannot boot a fresh custom ISO installer. If a future fresh installation requires a custom ISO, use a separately reviewed and explicitly labelled temporary installer definition, then replace it with the NO ISO BIND runtime container immediately after Setup and clean guest shutdown. Do not call an ISO-bound installer definition a runtime template.

The normal runtime creation gate applies to every guest, including second and later VMs. Old examples below that show `/custom.iso` are installer-phase examples only; they must not be copied into runtime start scripts or runtime container creation commands.

**Creation gate:** no guest is ready for ordinary operation until its ISO-free runtime container has passed all three checks. A script that warns about an ISO mount and then continues is non-compliant and must fail closed.

**Decision history:** the ISO-free runtime transition was verified for `windows-box` on 2026-11-14. The Pro VM's 2026-11-15 failure demonstrates why the gate must be enforced before every normal start.## 0.1 First confirmation before any VM action — NO ISO BIND

Before running any Bash command that creates, recreates or starts a normal Windows VM container, stop and inspect the exact command. Confirm there is no ISO source variable and no `/custom.iso` volume argument. Then inspect the actual Podman object after creation and immediately before start. This confirmation is mandatory even if an earlier template or script was previously reviewed.

The runtime-only template is [windows-pro-box-NO-ISO-BIND.template](../templates/windows-pro-box-NO-ISO-BIND.template). The previous ISO-bound template is retained unchanged as [windows-pro-box-ISO-BIND-BAD.template](../templates/windows-pro-box-ISO-BIND-BAD.template) for audit history only; do not execute it.

## 1. Objective

Create a manually managed Windows virtual machine on the Steam Deck OLED, primarily to run Windows-only UUP conversion tooling.

The immediate downstream task is to produce a Windows 11 ISO with the selected updates integrated. The UUP Dump documentation supplied during the KB5132061 investigation explicitly states that Linux/macOS conversion scripts do not support installing updates during conversion; Windows conversion is required for that workflow. This is an established limitation, not an unresolved possibility. `AddUpdates=1` in `ConvertConfig.ini` does not override the Linux converter limitation.

The Windows VM is intended as a temporary/controlled tool environment for this conversion task unless a broader purpose is explicitly agreed later.

## 2. Scope and boundaries

### In scope

- Assessing whether the Deck can host a hardware-accelerated VM.
- Selecting and documenting the QEMU/KVM execution architecture.
- Running QEMU inside the dedicated rootless Podman container `windows-box` using the `dockurr/windows` image.
- Creating a Windows guest named `windows-vm`, with persistent storage and a local installation ISO.
- Manual VM start/stop and a documented storage/recovery approach.

### Out of scope unless separately approved

- Installing Windows directly on the Steam Deck host.
- Replacing, repurposing or modifying the existing `uup-box`.
- Changing Pi-hole, SSH, Shyrka, Odysseus or other existing projects.
- Host boot autostart, persistent background services or unattended VM startup.
- GPU passthrough; it is not required for UUP conversion.
- Publishing Windows guest services or RDP to the LAN. The user selected LAN publication of noVNC at 192.168.1.161:8006 for PC client 192.168.1.169; the host-side change is documented but not yet applied.
- Installing host packages, changing host configuration, or modifying permissions without a reviewed proposal and explicit approval.

## 3. Naming and component roles

| Name | Role | Current state |
|---|---|---|
| `windows-box` | Dedicated rootless Podman container running the `dockurr/windows` QEMU/KVM Windows VM image | Running; QEMU/KVM and local noVNC console verified |
| `windows-vm` | Windows guest VM | User reports Windows 11 Pro 24H2 build 26100 installed and running |
| QEMU | Virtual machine process/emulator; with KVM acceleration it can use the Linux kernel's hardware virtualisation interface | QEMU 11.1.1 available inside the downloaded `dockurr/windows` image; KVM probe passed |
| KVM | Linux kernel virtualisation facility exposed through `/dev/kvm` | Host and rootless-container access verified; QEMU KVM launch passed |
| OVMF | UEFI firmware implementation commonly used by QEMU guests | Not installed in the earlier inventory |
| swtpm | Software TPM emulator, potentially needed for a Windows 11 virtual TPM device | Not installed in the earlier inventory |
| libvirt / virt-manager | Optional VM management service and graphical management application | Not installed in the earlier inventory |

QEMU is the virtual-machine engine. KVM is the Linux kernel facility that can accelerate virtualisation. A Windows guest is a separate operating system running inside a virtual hardware definition; it does not replace SteamOS. The intended multi-guest model is one independent rootless Podman container created from the Dockur image per Windows guest. Each container runs its own QEMU process and must have its own persistent storage, environment file, container name and host console port. The Dockur image is shared as a reusable image; the running containers and guest disks are separate. See the [Console operation and multi-VM deployment](#console-operation-and-multi-vm-deployment) for the architecture diagram, inventory commands and clean-removal procedures.

The deployed configuration specifies 4 vCPUs, 6 GiB RAM and a 128 GiB growable raw virtual disk. Runtime inspection confirmed these values in the QEMU command line and the created disk image.

## 4. Repository and platform rules

This project follows:

- [Repository README](../../README.md)
- [Engineering & Security Baseline](../../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md)
- [Project Documentation Standard](../../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md)

Key requirements:

1. Identify the execution context for every command: SteamOS host, `windows-box`, Windows guest, or a client workstation.
2. Start with targeted read-only inspection.
3. Do not repeat completed checks without a reason.
4. Do not assume a container is automatically a strong security boundary. Inspect the actual Podman mounts, user mappings, capabilities, devices and network configuration.
5. Preserve existing environments and persistent data.
6. Manual lifecycle by default.
7. Obtain explicit approval before installing packages, changing host configuration, enabling services, creating persistent VM storage or taking destructive action.
8. Never put credentials, activation keys, private keys or secret-bearing files in Git or diagnostic output.

## 5. Hardware and host preflight

### 5.1 Hardware virtualisation

**Status: REPORTED — PASS**

The user supplied the following read-only host inventory:

| Check | Reported result |
|---|---|
| CPU architecture | x86_64 |
| CPU model | AMD Custom APU 0932 |
| Logical CPUs | 8 |
| Hardware virtualisation | AMD-V (`svm` flag) |
| KVM modules | `kvm_amd` and `kvm` loaded |
| KVM device | `/dev/kvm`, character device major 10/minor 232 |
| KVM device permissions | `crw-rw-rw-`, mode `666`, owner `root:kvm` |
| User | `deck`, UID 1000; not a member of the `kvm` group |
| Podman | 6.0.2, rootless |
| Podman inventory | Existing containers observed; `uup-box` remains separate and untouched |

Current supplied inventory reports 14 GiB RAM, 9.8 GiB available at the time of the check, and 507 GiB free on `/home`. These are point-in-time observations; recheck before starting a memory-intensive guest or allocating storage.

**Interpretation:** AMD-V is enabled, the KVM modules are loaded, and `/dev/kvm` is readable and writable by `deck`. Rootless Podman successfully passed the device into a temporary Ubuntu 24.04 container. Inside that container the device appeared as `nobody:nogroup` with mode `0666`, and read/write checks passed. A separate QEMU test inside `dockurr/windows` then successfully started a minimal VM using `-machine q35,accel=kvm -cpu host`. This verifies actual QEMU/KVM initialisation inside the selected image.

### 5.2 Existing environments

The pre-existing Distrobox inventory (separate from this VM's selected Podman deployment):

| Environment | Image | Reported state |
|---|---|---|
| `pihole-box` | `archlinux:latest` | Exited |
| `Stable-box` | `ubuntu:24.04` | Exited |
| `localai-box` | `ubuntu:24.04` | Exited |
| `uup-box` | `archlinux:latest` | Up |

No existing environment is to be reused for this project. In particular, the currently running `uup-box` must remain untouched.

The `windows-box` name now refers to the planned Podman container, not a Distrobox directory. The persistent VM storage directory and 128 GiB growable guest disk have been created.

### 5.3 Virtualisation software inventory

The earlier host package inventory reported the following host-side tools as absent. This does not describe the QEMU tooling bundled inside the downloaded `dockurr/windows` image:

| Component | Result |
|---|---|
| `qemu-system-x86_64` | Not installed |
| `virsh` | Not installed |
| `virt-manager` | Not installed |
| `gnome-boxes` | Not installed |
| `qemu-full` | Not installed |
| `qemu-desktop` | Not installed |
| `libvirt` | Not installed |
| `virt-manager` package | Not installed |
| `edk2-ovmf` | Not installed |
| `swtpm` | Not installed |
| Flatpak VM management apps | None listed |

No packages were installed during this inventory.

## 6. Architecture decision

**Status: DEPLOYED — WINDOWS 11 PRO 24H2 INSTALLATION USER-CONFIRMED; LAN NOVNC VERIFIED; RDP PENDING**

The current candidate is:

```text
Steam Deck OLED / SteamOS host
  |
  |-- AMD-V + KVM modules + /dev/kvm
  |
  |-- rootless Podman
        |
        |-- dockurr/windows image (`windows-box`)
              |-- QEMU 11.1.1 + KVM acceleration
              |-- persistent Windows VM data (`/home/deck/WindowsVM/storage`)
              |-- Windows guest (`windows-vm`, Windows 11 Pro 24H2 build 26100; user-confirmed)
              |
              |-- virtual CPU / RAM / disk
              |-- UEFI firmware
              |-- virtual TPM 2.0, if required
              |-- NAT networking
```

The selected arrangement is rootless Podman running the purpose-built `dockurr/windows` image. The image contains QEMU; KVM is provided by the SteamOS kernel through `/dev/kvm`. This is a real Windows virtual machine, not a Windows userspace container. Both a minimal QEMU/KVM probe and the deployed guest's QEMU startup have succeeded. Runtime inspection confirms the intended mounts, LAN-bound web port, manual lifecycle and `/dev/kvm` device mapping. The user subsequently confirmed successful LAN noVNC access from the PC client in Brave and Chrome and completion of Windows 11 Pro 24H2 installation. Rootless operation does not by itself prove every aspect is isolated or safe.

### Deployed guest configuration

| Setting | Initial planning value | Status |
|---|---:|---|
| vCPU | 4 | Runtime verified |
| RAM | 6 GiB | Runtime verified |
| Disk | 128 GiB growable raw image | Created; logical capacity verified |
| Firmware | UEFI / OVMF | Proposed |
| TPM | TPM 2.0 virtual device | Proposed |
| Network | `NETWORK=user` / `passt` | Runtime observed; guest-reported IPv4 requires interpretation |
| GPU passthrough | Not planned | Not required for UUP conversion |
| Lifecycle | Manual start/stop via project scripts | Configured; script contents/runtime to be re-reviewed before final operations docs |

These values must be checked against current host memory, disk capacity, Windows requirements and the selected VM implementation before creation.

## 7. Persistent project layout and disposable guest policy

**Design objective:** the Windows guest disk must persist independently of its Podman container so the container can be replaced without reinstalling Windows. This is ordinary runtime persistence, not backup or disaster recovery. The guest is intentionally disposable; no backup or snapshot layer is maintained.

Selected project root: `/home/deck/WindowsVM`.

Created and verified on 2026-11-12:

```text
/home/deck/WindowsVM/       mode 0700, owner deck:deck
├── config/                 mode 0700
├── docs/                   mode 0700
├── shared/                 mode 0700
└── storage/                mode 0700
```

Historical installation record: the ISO was stored under `/home/deck/uup-box` and mounted read-only at `/custom.iso` for the initial Windows installation. That mount is not part of the corrected runtime container. Persistent guest data remains mounted from `/home/deck/WindowsVM/storage:/storage`. The storage directory survives container replacement, but is not backed up.

**Storage evidence:** `df -h /home` reported a 939 GiB filesystem, 433 GiB used and 507 GiB available (47% used) at the time of the check. The selected ISO was readable. A 128 GiB logical-capacity growable raw disk has been created; the initial storage directory usage was 898 MiB.

**Image identity:** local image ID `cbfaef1f04b4cb08137512116a64ed2005b58852bf04067b3f896342d5b3cb02`; reported repo digests include `docker.io/dockurr/windows@sha256:16fd7c39a3e48bb946d29c59dc6015942e5b900a1fa5d7e5552053bfc48ee2ea` and `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`. The latter is the manifest digest previously used for the KVM validation. The local image configuration reports the same image ID as the validated image.

**Operating model:**
- Keep the VM disk and all guest state in the host-backed `storage/` directory.
- Keep the deployment definition and lifecycle commands in `config/`, independent of the container instance.
- Pin the tested image digest for reproducible recreation; perform image upgrades deliberately, not by silently tracking `latest`.
- Keep manual start/stop; do not add boot autostart or a host service.
- No backup folder, guest backup, VM snapshot, virtual-disk copy or routine configuration-script backup is part of this project. If a guest becomes damaged, preserve useful findings and recreate the guest when appropriate.
- After SteamOS updates, verify Podman, KVM device access, project mount ownership, container recreation and guest boot. SteamOS update survival is a design goal, not a guarantee until recovery has been tested.

This layout was created successfully. The deployment configuration files passed syntax/permission checks. The container, guest storage and Windows installation are in place. Container recreation has been demonstrated; survival of future SteamOS changes remains a separate validation item.

## 8. Journey log

### 2026-11-12 — Windows installation completed; local noVNC access confirmed

**User-reported guest state (installation completion):**

- Windows 11 Pro, version 24H2, build 26100.
- Local Windows account: `DeckVM`; user reports no password prompt at login. The generated local environment-file secret remains private and is not reproduced here.
- Windows hostname: `windows-vm`.
- User reports Windows Update paused until 2026-12-28.
- Guest-reported IPv4: `192.168.1.161`; DNS: `192.168.1.1`. The IPv4 matches the Steam Deck host address recorded in the deployment. Because QEMU is configured with `NETWORK=user`/`passt`, do not assume this represents a separately assigned, independently reachable LAN address. The guest networking model and any required inbound access must be verified before documenting it as a distinct endpoint.
- The user opened `http://127.0.0.1:8006/` locally on the Steam Deck and confirmed successful noVNC access. Browser tab title: `Windows - noVNC`.

**Historical status at that point:** Windows installation and local console access were user-confirmed. The read-only ISO mount was used during initial installation only; it is not part of the corrected 2026-11-14 runtime baseline. Windows activation, guest outbound network and shared-folder operation remain separate validation items.

**Lifecycle intent:** retain manual start/stop/status operation using the existing project scripts. No SteamOS boot autostart or always-on service is intended. The three script contents and stop/start behaviour are to be reviewed before declaring lifecycle documentation final.

**LAN console decision (2026-11-12):** the user selected http://192.168.1.161:8006/ for PC client 192.168.1.169 and accepts LAN reachability. The current host listener is still 127.0.0.1:8006. The start script must be changed to publish 192.168.1.161:8006:8006, then the existing container must be stopped and recreated (without deleting /home/deck/WindowsVM/storage) for the new binding to take effect. The active public firewalld zone already has broad TCP/UDP allowances for ports 1024-65535; no firewall change has been made. Do not publish guest RDP or other guest ports.

**Disposable-guest boundary:** the user explicitly rejected guest backups, VM snapshots, virtual-disk copies and routine script backups. This is a permanent project design choice, not a temporary deferral. Preserve verified configuration and engineering findings in documentation; do not plan a later backup phase.



### 2026-11-12 — KVM and selected container validated

**Host preflight:** AMD-V reported; `svm` CPU flag present; `kvm_amd` and `kvm` modules loaded; `/dev/kvm` present as `10:232`, mode `0666`, readable and writable by `deck`. `/dev/net/tun` also present with mode `0666`. Rootless Podman 6.0.2 confirmed. `free -h` reported 14 GiB total and 9.8 GiB available; `/home` reported 507 GiB free.

**Rootless device test:** a temporary Ubuntu 24.04 container was launched with `--device=/dev/kvm`. The device appeared inside the container as `nobody:nogroup`, character device major 10/minor 232, and both read and write checks passed. Container exit status was 0. No host permission changes were made.

**Selected image:** `docker.io/dockurr/windows:latest` downloaded successfully. Reported image ID/config digest: `cbfaef1f04b4cb08137512116a64ed2005b58852bf04067b3f896342d5b3cb02`; image manifest digest: `sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`.

**QEMU/KVM test:** image contains `/usr/bin/qemu-system-x86_64`, QEMU emulator version `11.1.1 (qemu-windows 11.2.23)`. `qemu-system-x86_64 -accel help` listed KVM. A minimal Q35 VM with `accel=kvm`, `-cpu host`, 256 MiB RAM, no devices/display and paused execution started successfully. Output: `KVM acceleration: SUCCESS`; the temporary QEMU process was terminated by the test cleanup. This confirms QEMU can initialise KVM inside the selected rootless Podman container.

**Architecture decision:** proceed with `dockurr/windows` in rootless Podman, named `windows-box`. Do not create a Distrobox for this VM. Keep manual lifecycle and persistent guest data separate from the container layer. This decision is based on the successful KVM test, not a blanket preference for containers.

**Installation ISO discovery and verification:** the selected ISO is `/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO` (4,335,187,968 bytes; approximately 4.1 GiB). Its SHA-256 is `3a65289ef20c85e6ea64778e360ef50acc88451cc864778b1df1eb55270545f9`. `file` identifies it as a bootable ISO 9660 filesystem labelled `26100.1_X64_EN-US`. `7z l` confirms `setup.exe`, `sources/boot.wim` and `sources/install.wim` are present. The filename mismatch in the first inspection command was only a typo in the command: it omitted `.1` from `26100.1.1`; the actual file was present. Do not conflate that command typo with the separate, expected UUP build-version difference.

**UUP conversion conclusion:** the source selection directory is named `26200.9974_pro`, but the Linux-generated ISO contains the base Windows image build `26100.1`, not the selected updated build `26200.9974`. This is expected because the Linux/macOS UUP conversion scripts do not support integrating the selected update packages. The UUP set contains the base image and separate update packages; `AddUpdates=1` in `ConvertConfig.ini` does not override this platform limitation. Windows-based conversion is required to integrate the updates. The same limitation explains why the Linux-generated base ISO is unsuitable as a matching repair source for the Dell M4800's installed Windows 11 Pro build `26200.9818`, and why the earlier DISM repair attempt returned `0x800f0915`. This ISO remains useful as installation media for the Windows VM, but must not be described as an updated `26200.9974` ISO or as a matching repair source.

### 2026-11-12 — Persistent project directory created and image configuration inspected

**Image configuration (read-only):**
- Image ID: `cbfaef1f04b4cb08137512116a64ed2005b58852bf04067b3f896342d5b3cb02`.
- Repo digests reported: `docker.io/dockurr/windows@sha256:16fd7c39a3e48bb946d29c59dc6015942e5b900a1fa5d7e5552053bfc48ee2ea` and `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`.
- Entrypoint: `/usr/bin/tini -s /run/entry.sh`; working directory `/`; no configured image user.
- Image defaults: `VERSION=11`, `CPU_CORES=2`, `RAM_SIZE=4G`, `DISK_SIZE=64G`.
- Declared persistent volume: `/storage`.
- Exposed container ports: `3389/tcp` and `8006/tcp`.
- Image size: 707,889,576 bytes.
- The inspected ID matches the image used in the earlier successful QEMU/KVM validation.

**Persistent directory creation:** created `/home/deck/WindowsVM` and its project subdirectories. The current documented layout consists of `config/`, `storage/`, `shared/`, and `docs/`, owned by `deck:deck` with mode `0700`. No container or guest was created by this step.

**ISO check:** the existing installation ISO at `/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO` is readable. It remains in place and was not copied or modified.

**Storage:** `df -h /home` reported 939 GiB total, 433 GiB used, 507 GiB available, 47% used. This is point-in-time capacity evidence.

**Storage decision:** guest state resides under `/home/deck/WindowsVM/storage`, outside the container writable layer and away from SteamOS-managed system paths. Deployment configuration is stored separately under `config/`. The container is replaceable; image upgrades remain deliberate and digest-pinned. Manual lifecycle remains the default. This design supports replacing the container while retaining the guest, but it does not protect the guest disk from loss or corruption.

### 2026-11-12 — Selected ISO verified; UUP version difference explained

**Selected ISO:** `/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO`.

- Size: 4,335,187,968 bytes (approximately 4.1 GiB).
- SHA-256: `3a65289ef20c85e6ea64778e360ef50acc88451cc864778b1df1eb55270545f9`.
- `file` output: bootable ISO 9660 filesystem, volume label `26100.1_X64_EN-US`.
- `7z l` confirms `setup.exe`, `sources/boot.wim` and `sources/install.wim`.
- The initial inspection command failed only because it omitted `.1` from the actual filename; the correct file existed and was subsequently inspected successfully.

**Important UUP finding (settled, not an open question):** the directory/source selection `26200.9974_pro` does not mean the Linux-generated ISO contains build `26200.9974`. The Linux UUP conversion script does not integrate the selected update packages. The ISO therefore contains the base `26100.1` image. `AddUpdates=1` in `ConvertConfig.ini` does not override this Linux converter limitation. The UUP set has the base image and separate update packages; integrating them requires the Windows conversion workflow.

This also explains why the base ISO is not a matching repair source for the Dell M4800's installed Windows 11 Pro `26200.9818` and why the previous DISM repair attempt returned `0x800f0915`. The ISO is retained as Windows VM installation media, not represented as an updated ISO or a suitable matching repair source.

### 2026-11-12 — Start-script configuration review

**Inspection:** the user supplied the complete contents of `config/windows-box-start.sh`. The script was reviewed read-only; it was not executed during this review.

**Review findings:**
- The image reference is pinned to the previously tested local manifest digest, and `--pull=never` prevents an implicit pull.
- The script checks the selected ISO and protected environment file are readable, and checks that the pinned image exists locally before deployment.
- It passes `/dev/kvm` only; it does not use `--privileged`, add capabilities, or pass `/dev/net/tun`.
- It binds `/home/deck/WindowsVM/storage` to `/storage` and the dedicated shared directory to `/shared`; the ISO is mounted read-only at `/custom.iso`.
- It publishes the web console on host loopback only (`127.0.0.1:8006:8006`). It does not publish RDP.
- The environment's `NETWORK=user` configures QEMU user-mode guest networking. This is distinct from Podman's container network mode; the script does not request host networking.
- The container uses `--restart=no` and a 120-second stop timeout, consistent with manual lifecycle.
- If a container named `windows-box` already exists and is stopped, the script starts that existing container rather than recreating it. Environment-file edits do not change an existing container's stored environment or mount/device configuration; deliberate recreation would be required to apply such changes.
- With `set -euo pipefail`, a failing Podman create/start command stops the script. The final message confirms the Podman command returned successfully, not that Windows setup or the guest web console is ready.

**Assessment:** no unexpected host-level changes, broad privilege grant, or mismatch with the selected persistence/network/lifecycle design was found in the supplied script. The script is approved for the initial container creation attempt, subject to runtime verification immediately afterward. This is a static review only; Podman argument acceptance, actual mounts, port binding, QEMU startup and guest storage writes remain to be verified at runtime.

**Next:** run the manual start script once. Then inspect container state, configuration/mounts, published port and startup logs before interacting with the guest installer.
### 2026-11-12 — Initial container deployment and QEMU/KVM guest startup

**User-supplied runtime evidence:** the manual start script created container `windows-box` (ID prefix `c1e364fcda07`) and returned successfully. Subsequent read-only inspection confirmed:

- Container state `running`; image reference is the pinned `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`; restart policy `no`.
- Persistent mount `/home/deck/WindowsVM/storage:/storage` is read/write.
- Installation ISO is mounted at `/custom.iso` read-only.
- Shared directory `/home/deck/WindowsVM/shared:/shared` is read/write.
- Host port publication is exactly `127.0.0.1:8006:8006`; `ss` independently confirmed a listener on `127.0.0.1:8006`.
- QEMU command line includes `-machine ... accel=kvm`, `-enable-kvm`, `-smp 4` and `-m 6G`. This is direct runtime evidence of KVM-backed QEMU startup using the configured four vCPUs and 6 GiB RAM.
- QEMU opened `/custom.iso` read-only as the boot DVD and `/storage/data.img` as the guest disk.
- Container logs detected Windows 11 Pro, created the growable 128 GiB raw disk and reported: `Windows started successfully`.
- `podman top` showed QEMU, nginx/web console, passt user-mode networking, dnsmasq and Samba processes.
- `storage/` reported 898 MiB by `du`; `data.img` has a logical size of 137,438,953,472 bytes (128 GiB). This is consistent with a growable, non-preallocated raw disk; logical capacity is not the same as physical blocks consumed.
- Storage files observed: `setup.img` (64 MiB), `windows.rom`, `windows.vars`, `windows.base`, `windows.ver`, `windows.mac`, and `data.img`.

**Interpretation and boundary:** container creation, persistent storage mount, QEMU/KVM startup, initial UEFI boot from the ISO and web-console service startup are VERIFIED from the supplied output. Windows Setup interaction, completion of OS installation, guest network connectivity, shared-folder functionality, Windows activation/build remain UNVERIFIED. The guest process is running; this is not yet proof that Windows installation is complete.

**Network note:** `NETWORK=user` is implemented by the image using `passt`; the logs show guest user-mode networking. The container's web console is bound to host loopback only. The image's internal QEMU guest network information should not be confused with direct LAN publication of the web console.

**Next:** open the web console locally at `http://127.0.0.1:8006/` and report what Windows Setup displays. Do not change the VM configuration unless the installer reveals a concrete issue.
### 2026-11-12 — Deployment configuration files created and validated

**User-supplied verification output:**

- `windows-box.env` exists, owner `deck:deck`, mode `0600`.
- `windows-box-start.sh`, `windows-box-stop.sh` and `windows-box-status.sh` exist, owner `deck:deck`, mode `0700`.
- All three shell scripts passed `bash -n` syntax validation.
- Environment settings were printed with the password redacted. The secret was not included in the output.
- `df -h` reported 507 GiB available on `/home` at the time of this check.

**Prepared environment (configuration only; not yet applied to a running container):**

| Setting | Prepared value |
|---|---|
| Windows version selector | `11` (custom ISO is mounted and takes precedence) |
| Locale | `en-US` for language, region and keyboard |
| vCPU | 4 |
| RAM | 6 GiB; `RAM_CHECK=Y` |
| KVM | Enabled |
| Virtual disk target | 128 GiB |
| Disk format | `raw` |
| Preallocation | Disabled (`ALLOCATE=N`) |
| Network | `user` (user-mode networking) |
| Display | Web viewer enabled on container port 8006 |
| Host publication | `127.0.0.1:8006:8006` only |
| Guest account name | `DeckVM` |
| Guest password | Random value generated locally and stored in the protected env file; value deliberately not recorded here |
| Guest hostname | `windows-vm` |
| Shared folder | `/home/deck/WindowsVM/shared:/shared` |
| Persistent guest storage | `/home/deck/WindowsVM/storage:/storage` |
| Installation ISO | Existing verified ISO mounted read-only at `/custom.iso` |
| Image | Pinned to `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc` |
| Lifecycle | Manual; `--restart=no`; 120-second stop timeout |

The start script is designed to use the existing local image without pulling (`--pull=never`), pass only `/dev/kvm`, and avoid `--privileged`. User-mode networking was selected because the immediate workflow needs outbound guest connectivity for UUP downloads, not unsolicited inbound guest access. No TUN device or `NET_ADMIN` capability is included in this initial configuration. RDP is not published; the web viewer is bound to host loopback.

**Boundary:** this step created configuration files only. It did not create or start `windows-box`, allocate the virtual disk, or create/install a Windows guest. The password remains local and must never be committed to Git or pasted into chat. If environment settings change after container creation, the existing container must be deliberately recreated for those changes to take effect; a simple `podman start` reuses its original container configuration.

**Next:** review the prepared start script and its exact mount/device/network arguments, then launch the container. After launch, inspect container state/logs, actual storage writes and allocated disk size before proceeding with Windows installation.
### 2026-11-12 — Project initiated

**Purpose:** establish a Windows VM project to support Windows-only UUP update integration without repeating the failed conversion attempt on the Dell M4800.

**Evidence reviewed:**

- Repository root README.
- Shared Engineering & Security Baseline.
- Project Documentation Standard.
- User-supplied Steam Deck host, Podman, KVM and memory/storage inventory.
- Successful rootless Podman `/dev/kvm` passthrough test.
- Successful QEMU/KVM acceleration probe inside `dockurr/windows`.

**Findings:**

- SteamOS reports AMD-V; `svm` is present and `kvm_amd`/`kvm` are loaded.
- `/dev/kvm` is accessible read/write by `deck`.
- Rootless Podman passes `/dev/kvm` into a temporary container successfully.
- QEMU 11.1.1 inside `dockurr/windows` starts a minimal Q35 guest using KVM acceleration.
- The `dockurr/windows` image is downloaded; no persistent VM storage or Windows guest exists yet.
- The existing `uup-box` remains separate and untouched.
- No host packages, services, permissions or configuration were changed for this project.

**Decision:** `windows-box` is the rootless Podman container running `dockurr/windows`; `windows-vm` is the Windows guest. Do not create a Distrobox for this VM. Keep the VM manually managed.

**Status at project initiation:** host, rootless Podman device access and QEMU/KVM acceleration validated. The subsequent deployment and ISO checks are recorded in the later journey entries above.

## 9. Next steps

The ISO path and checksum are now verified, and its bootable ISO structure and key setup files are confirmed. The expected Linux-conversion version difference is understood: this ISO contains the base `26100.1` image, not the selected `26200.9974` update level. Do not spend further time trying to make the Linux conversion output contain integrated updates. The purpose of the Windows VM is to run the Windows UUP conversion workflow that can integrate those update packages. The next media check, if needed for selecting the guest edition, is to inspect the `install.wim` image indexes and edition metadata; it is not to investigate the already-explained base/update version difference.

Windows installation is user-confirmed complete. The selected LAN noVNC endpoint is http://192.168.1.161:8006/ from 192.168.1.169; apply the documented publication change and recreate only the container, preserving /storage. Verify from the PC after the change. Do not add TUN or capabilities unless a concrete requirement emerges.

1. (Completed) Verify the selected ISO path, SHA-256, bootable ISO structure and key setup files.
2. (Completed) Confirm the selected image configuration and persistent data directory.
3. (Completed) Create and document the VM storage path and disk capacity.
4. (Completed) Prepare and deploy the reviewed Podman configuration, including KVM, persistent mounts and local console.
5. (Completed) Create persistent VM storage and start QEMU/KVM.
6. (Completed; user-confirmed) Install Windows 11 Pro 24H2 and access the noVNC console locally.
7. (Pending) Verify guest networking, shared-folder workflow and activation status; installed edition/build are user-confirmed.
8. (Pending) Apply the selected LAN console publication at 192.168.1.161:8006 and test from PC client 192.168.1.169.
9. Tune resources or display only in response to observed needs.

## 10. Change and evidence register

| Date | Item | Status | Notes |
|---|---|---|---|
| 2026-11-12 | AMD-V and KVM host availability | VERIFIED | AMD-V, KVM modules, `/dev/kvm` and device permissions confirmed from supplied output |
| 2026-11-12 | Rootless Podman KVM device passthrough | VERIFIED | Temporary Ubuntu container accessed `/dev/kvm` read/write; exit 0 |
| 2026-11-12 | `dockurr/windows` image download | VERIFIED | Manifest digest recorded in journey log |
| 2026-11-12 | QEMU/KVM acceleration inside selected image | VERIFIED | Minimal Q35 test VM started with `accel=kvm` |
| 2026-11-12 | Architecture | SELECTED | Rootless Podman + `dockurr/windows`; no Distrobox required |
| 2026-11-12 | Selected Windows ISO | VERIFIED | Actual path, 4,335,187,968-byte size, SHA-256, bootable ISO9660 label and setup/boot.wim/install.wim files verified. Base image is `26100.1`, not updated `26200.9974`; expected Linux UUP converter limitation is documented. |
| 2026-11-12 | Image configuration inspection | VERIFIED | Entrypoint, defaults, `/storage` volume, exposed ports, image ID and repo digests recorded |
| 2026-11-12 | Persistent project directory | VERIFIED | `/home/deck/WindowsVM` and five subdirectories created; all mode 0700, owner deck:deck |
| 2026-11-12 | ISO readability at deployment path | VERIFIED | Existing ISO readable; left in original `uup-box` location |
| 2026-11-12 | Home filesystem capacity | REPORTED | 507 GiB available at time of check |
| 2026-11-12 | Deployment configuration files | VERIFIED | Environment file and three lifecycle scripts created; ownership/modes verified; all scripts passed `bash -n`; secret value not displayed |
| 2026-11-12 | `windows-box` container deployment | VERIFIED | Container created and running with pinned image; restart policy `no` |
| 2026-11-12 | Persistent guest disk creation | VERIFIED | Growable raw `data.img`, logical size 128 GiB, stored under host-backed `/storage` |
| 2026-11-12 | QEMU/KVM guest startup | VERIFIED | QEMU running with `accel=kvm`, `-enable-kvm`, 4 vCPU and 6 GiB RAM; booted from read-only ISO |
| 2026-11-12 | Web console publication | VERIFIED | Listener and Podman mapping restricted to `127.0.0.1:8006` |
| 2026-11-12 | Windows 11 Pro installation | USER-CONFIRMED | Windows 11 Pro 24H2 build 26100; local account `DeckVM`; hostname `windows-vm` |
| 2026-11-12 | Local noVNC console | USER-CONFIRMED | Opened successfully on Deck at `127.0.0.1:8006`; browser title `Windows - noVNC` |
| 2026-11-12 | Guest network configuration | USER-REPORTED | Guest reports IPv4 `192.168.1.161` and DNS `192.168.1.1`; same IPv4 as Deck host, requires interpretation under user-mode `passt` networking |
| 2026-11-12 | PC-client noVNC endpoint | USER-SELECTED / HOST CHANGE PENDING | 192.168.1.161:8006 for client 192.168.1.169; runtime still loopback-only; container recreation required |

---

*Living project document. Update after each completed inspection, decision, installation or verification. Record only evidence actually supplied or observed; do not promote proposals to verified state.*


### 2026-11-12 — LAN console target and second-VM procedure documented

The user selected Steam Deck address 192.168.1.161, TCP port 8006, and PC client 192.168.1.169 for noVNC, and explicitly accepts LAN reachability. The current container and start script are still loopback-bound. The intended publication is 192.168.1.161:8006:8006; the container must be recreated for that setting to take effect while preserving the host-backed storage directory. No firewall change has been made; the active public zone already has broad high-port TCP/UDP allowances.

A new Console and Second-VM Deployment Guide documents viewer operation, host-side resource settings, unattended setup variables, and an isolated second-VM example. The example is documentation only; no second VM has been created.


### 2026-11-12 — Disposable guest and storage-tuning lab policy

The user clarified that this Windows VM is a disposable sandbox for learning QEMU/KVM, rootless Podman and Dockur. Do not create backup folders, guest backups, VM snapshots, copies of `data.img` or routine copies of configuration scripts. The user prefers diagnosing a damaged guest and creating a fresh VM over repairing a “wounded” experimental guest. Preserve configuration parameters, deployment settings and verified technical findings in documentation.

A dedicated [Disposable I/O, RAM-Backed Temporary Storage and SSD Lab](./WINDOWS-VM-DISPOSABLE-IO-AND-SSD-LAB.md) records the proposed RAM-disk, TEMP/TMP, pagefile, TRIM, Optimize Drives and NVMe-health investigations. No Windows storage tuning has been applied. The PowerShell baseline was mistakenly entered in SteamOS Bash and therefore did not run; it must be executed inside the Windows guest.

**Host baseline supplied while the VM was running:** `data.img` reported 8.5 GiB allocated by `du` and 128 GiB apparent size; `/home` had 498 GiB available (939 GiB total, 441 GiB used, 47%); host RAM was 14 GiB total with 3.0 GiB available; zram was 7.2 GiB total with 1.1 GiB used; the 1 GiB host swapfile had 3.6 MiB used. Both `nvme` and `smartctl` executables are installed, but no NVMe health query has been run. These are point-in-time readings, not wear-rate evidence.

**Resource safety:** do not increase guest RAM or allocate a RAM disk based on assumptions. The 3.0 GiB host available-memory reading is a caution requiring further baseline measurements. Do not alter SteamOS swap/zram, host filesystem, NVMe settings or host services for guest optimization.

**LAN console remains first priority:** the current start script contains `192.168.1.161:8006:8006`, but the running `windows-box` still publishes `127.0.0.1:8006`. The container must be recreated and PC-client browser access verified before starting the Windows-side PowerShell and storage audit.

**PowerShell command-context correction:** the first guest inspection block was entered into SteamOS Bash over SSH. Bash returned command-not-found/syntax errors; no PowerShell command ran and no guest configuration was changed.


## 9.4 2026-11-12 — LAN noVNC access completed

**VERIFIED:** The start script was changed to publish `192.168.1.161:8006:8006`. The running container was stopped and its Podman container object removed; the container was recreated from the updated script. The existing persistent host-backed storage mount was retained, and no VM disk backup or snapshot was created.

The new container ID began `781b320a14d0`. `podman ps` reported `192.168.1.161:8006->8006/tcp`; `podman port windows-box` reported `8006/tcp -> 192.168.1.161:8006`; `ss` confirmed a listener on `192.168.1.161:8006` owned by `passt.avx2`.

**USER-CONFIRMED:** From PC client `192.168.1.169`, the user opened `http://192.168.1.161:8006/` successfully in Brave and Chrome at the same time. Both browsers display the same Windows guest console; they are multiple viewers of one guest session, not separate Windows sessions.

**Next phase:** Run the Windows PowerShell baseline from inside the guest using the working noVNC console. The earlier attempt to run PowerShell commands in SteamOS Bash did not execute any guest commands or change guest settings.


## 14. Next guest preparation — 2026-11-13

**Status: GROUNDWORK IN PROGRESS.** The existing Windows 11 Pro 24H2 guest remains available for read-only inspection and experiments. The user intends to remove it and create a replacement only after the planned ISO, installation-customization and disposable-I/O groundwork is complete. RDP publication is deliberately deferred.

### 14.1 Proposed next-guest configuration

These are proposed settings, not yet deployed:

| Setting | Proposed value | Notes |
|---|---:|---|
| Windows edition | Windows 11 Pro | Verify edition in selected ISO |
| Display language | en-US | Windows UI language |
| Regional format | fr-FR | French regional formats |
| Keyboard | fr-FR | French AZERTY |
| Windows computer name | windeck | Replaces windows-vm |
| vCPU | 4 | QEMU launch-time configuration |
| RAM | 8 GiB | Recheck host available memory and pressure before launch |
| Virtual disk | 72 GiB | Raw, growable, not preallocated |
| Network | NETWORK=user | Keep user-mode networking |
| Display | Web, 1920×1080 | LAN noVNC retained |
| GPU acceleration | Pending | Do not set GPU=Y until host render-node access and start-script device mapping are verified |
| File share | Samba enabled | Keep the existing narrowly scoped shared directory |
| RDP | Deferred | Do not add USER_PORTS or publish 3389 in this preparation phase |

The reusable template is updated at ../templates/windows-vm.env.example. The real per-guest environment file remains local, mode 0600, and must never be committed.

### 14.2 UUP ISO work

**USER-REPORTED / IN PROGRESS (2026-11-13):** The user downloaded a Windows 11 25H2 UUP package and is running the Windows conversion script to create installation media.

The UUP conversion option to include updates is supported by the Windows conversion workflow. The conversion must be run on Windows for UUP Dump integration options that require Windows; the Linux/macOS conversion route used for the earlier base ISO did not integrate the selected updates. Do not mark the resulting ISO as updated until the conversion completes and its build/package state is verified.

After conversion, record:
- Exact UUP selection, architecture, edition and language.
- Build number and revision represented by the resulting image.
- Whether the Windows converter's Include updates option was selected.
- Conversion log and final ISO SHA-256.
- DISM image metadata and package inventory from install.wim or install.esd.

Do not assume that a downloaded UUP package or an in-progress conversion has already produced a bootable ISO.

### 14.3 25H2 ISO versus 26H2

Do not confuse the released Windows 11 26H2 servicing version with UUP Dump's separate 26H2 Experimental selection or the Future Platforms channel.

As of 2026-11-13, Microsoft's release information lists Windows 11 26H2 as a general-availability release, while Insider/Future Platforms builds are separate preview tracks. Record the exact build and channel, not just the text "26H2".

For the next practical VM, prefer a current released 26H2 Pro image if the objective is a current everyday Windows lab. Use 26H2 Experimental/Future Platforms only if the explicit objective is to test preview builds and accept instability. The already-running 25H2 conversion can still serve as a known comparison point; do not discard it until its result is inspected.

### 14.4 An updated ISO is not an MSU update package

Keep these operations distinct:

1. **Create refreshed installation media:** UUP conversion integrates updates into the Windows image in the ISO. This is the preferred route for installing a new VM already at the selected build/revision.
2. **Service an offline Windows image:** DISM applies matching MSU/CAB packages to a mounted offline Windows image (for example, a mounted install.wim or an offline Windows installation). An ISO is a container of setup media and WIM/ESD images; it is not itself a cumulative-update package.
3. **Update an already running guest:** use Windows Update or an applicable standalone update package. Running setup.exe from newer installation media is an in-place upgrade/repair-install path, not the same operation as applying an MSU.

For the disposable next VM, a refreshed ISO is preferable to installing an old base image and then applying a long sequence of updates. If the existing guest needs an offline servicing test, first identify the exact target image and matching package; do not apply an ISO as if it were an MSU.

### 14.5 Dockur ISO source and installation parameters

The deployed start configuration mounted a local ISO read-only at /custom.iso. Dockur documents that a local /custom.iso overrides VERSION; therefore the previous guest was installed from the mounted local ISO, not from a Dockur-initiated online ISO download.

In that deployment, VERSION=11 was effectively a fallback/ignored selector while /custom.iso was present. Download-related variables such as CONNECTIONS, MIDO and ESD apply to Dockur's own ISO-download path and were not the mechanism used to install the custom local ISO.

### 14.6 Environment variables: provisioning versus runtime

A populated .env is not a universal live Windows configuration interface. It is read by the container at startup, but Dockur variables have different lifetimes:

- **QEMU launch/runtime configuration:** CPU_CORES, RAM_SIZE, KVM, network/display parameters and device options are used when QEMU is launched. Changing the local file does not hot-resize a running VM; a controlled VM/container restart is normally needed. CPU hotplug is not part of Dockur's documented simple configuration.
- **Disk parameters:** DISK_FMT and ALLOCATE govern how the virtual disk is created. Dockur documents increasing DISK_SIZE as a supported way to expand an existing virtual disk; Windows may then need its partition extended. Setting a smaller DISK_SIZE does not shrink an existing disk. A fresh guest is the straightforward way to start with a smaller 72 GiB disk.
- **Initial Windows provisioning:** LANGUAGE, REGION, KEYBOARD, USERNAME, PASSWORD, AUTOLOGIN and HOST are installation/setup inputs. Do not expect edits to these values to rewrite an existing Windows profile, change an existing password, or rename an installed guest automatically.
- **Container services and exposure:** web console, file sharing and port-forwarding settings may be consumed on each container start, but the actual host publication is separately configured by the Podman start script.
- **Optional dynamic memory:** Dockur documents BALLOONING and related controls. This is a separate memory-pressure feature, not a general guarantee that Windows RAM can be arbitrarily resized. It requires a compatible guest balloon driver and careful testing.

The current official Dockur environment reference is the authority for the variable list; the repository template deliberately omits experimental options until justified.

### 14.7 Credentials and automatic sign-in

USERNAME is the actual Windows local account name. The project's win-user term is a role label, not necessarily the literal account name. PASSWORD provisions the Windows local account; it is not the noVNC console password. A unique password must be generated locally and stored only in the protected local environment file during initial installation.

Changing the Windows account password inside Windows later does not require changing the .env for normal use of that already-installed account. However, the stored Dockur environment value would then be stale for future reinstall/reprovisioning, and automatic sign-in may need to be reconfigured if its stored credentials no longer match. Never print or paste the password.

### 14.8 Dynamic CPU/RAM distinction

The number of vCPUs and the initial/max RAM allocation are QEMU machine parameters. The normal Dockur configuration sets them when QEMU starts; it does not provide a simple live slider for CPU count.

Dockur documents memory ballooning as an optional way for the host to reclaim guest memory under host pressure. Ballooning is not free extra RAM, can create guest memory pressure, and may fail to reclaim quickly enough. It must not be enabled until host/guest memory baselines, driver availability and a conservative minimum are established. No ballooning experiment has been run.

### 14.9 Setup customization and debloating — pending analysis

The user wants a clean Windows Pro setup with:
- no Microsoft account requirement during OOBE if a supported local-account route remains available;
- OneDrive not installed;
- no unnecessary Remote Desktop client application;
- Copilot/AI features and related optional components removed or disabled where supported;
- privacy/diagnostic/feedback settings minimized without breaking Windows Update, Defender, servicing or core functionality;
- Windows power behavior set to best performance for the guest workload.

Do not equate "no visible Start-menu tile" with an application being absent. Verify installed packages, provisioned packages, optional capabilities, services and actual executables before claiming Edge, OneDrive or another component is removed.

Winhance is a candidate GUI configuration tool, not yet approved/applied. Review its exact toggles and exportable configuration before use. Avoid opaque AI-generated removal scripts and broad "remove everything" scripts. Prefer a small, explicit, reviewable set of supported Windows settings and package removals.

Dockur already performs automated Windows setup using its own generated configuration. A separate answer file is not automatically required for this single-VM lab. If further customization is needed, investigate Dockur's supported setup hooks (including its /oem post-install folder and install.bat) before introducing a manually maintained unattend XML. Do not assume arbitrary XML placed under /storage is consumed by Setup; inspect the actual generated files and Dockur implementation first.

The guest power plan is not a documented Dockur .env variable. Treat it as a Windows post-install setting, preferably a small explicit command/script whose effect can be verified inside Windows.

### 14.10 Pre-recreation gate

Do not remove the current guest until:
- the 25H2 UUP conversion has completed and its ISO has been verified;
- the 26H2 stable versus Experimental choice is explicit;
- offline servicing versus ISO-based installation has been decided;
- the current guest's useful setup and storage baselines have been collected;
- the Dockur setup/unattend mechanism and customization scope have been reviewed;
- the proposed .env values and actual Windows account name have been agreed;
- the disposable I/O/SSD lab has a read-only baseline and a safe experiment plan.

No VM deletion, disk recreation, snapshot or disk copy is authorized by this preparation note.


### 14.11 Local account and OOBE — why the current install did not need a Microsoft account

The absence of a Microsoft-account sign-in during the existing Dockur installation is consistent with Dockur's automated installation path. The configured USERNAME and PASSWORD are used to provision a local Windows account, and AUTOLOGIN controls automatic sign-in. This is not evidence that Windows 24H2 alone permits local accounts or that the ISO was a specially debloated image.

Windows Setup supports answer-file configuration for OOBE and local-account creation. Microsoft's deployment documentation defines OOBE settings such as HideOnlineAccountScreens and the UserAccounts/LocalAccounts component. Dockur automates setup rather than requiring the user to manually build an answer file for the standard account flow. The same deployment mechanism is not inherently tied to 24H2, but the next selected ISO must still be tested because Windows setup behavior and Dockur's generated answer file can change between builds.

The old interactive shortcuts for bypassing online-account prompts have changed across releases. Do not base the new VM on an undocumented OOBE command or assume a workaround from an older build remains valid. Prefer Dockur's maintained automatic setup and verify local-account creation during the next installation.

The user does not want to maintain a manually authored XML file. That remains the default: use Dockur's documented environment variables for standard account/locale/hostname inputs, then a small reviewed OEM post-install script only for settings that Dockur does not expose. An answer file is a Windows deployment mechanism, not a requirement to operate a fleet of PCs.

### 14.12 Distinguish Windows components from shortcuts

- OneDrive: can be excluded or removed as a separate application/package decision; verify that it is actually absent after setup.
- Remote Desktop client: not required inside the guest for incoming RDP. The guest needs its Remote Desktop host service; the RDP client runs on the connecting PC.
- Copilot and other AI features: removing the Copilot app does not necessarily remove every Windows AI component or related OS capability. Review each component separately; avoid deleting shared frameworks or system packages indiscriminately.
- Edge: verify the executable, package and WebView2 dependencies before claiming it is absent or attempting removal. Do not remove Edge/WebView components blindly because other Windows features may depend on them.
- Diagnostics/privacy: minimize optional diagnostic data, tailored experiences, advertising ID and feedback prompts using supported Windows settings/policies. Do not claim that all diagnostics can be disabled; required security, reliability and servicing diagnostics may remain.
- Power: "Best performance" is a Windows guest power-mode/plan setting, not a Dockur environment variable. Verify the actual selected plan/mode inside the installed guest. If automated later, use a narrowly scoped post-install command and verify its result.

No debloating, package removal, privacy-policy change or power-plan change has been applied as part of this groundwork.


## 2026-11-14 — Installation ISO is not a runtime dependency

**Correction based on successful container recreation and Web Console validation.** The original deployment mounted the custom installation ISO at /custom.iso for the initial Windows installation. That mount was mistakenly retained in the normal VM start definition. When the ISO was later deleted, the start script refused to run even though the installed Windows guest and its persistent disk remained present.

The correct lifecycle separates installation media from the installed guest:

- **Installation phase:** mount a selected custom ISO read-only at /custom.iso only when creating the guest for its initial installation (or a deliberately planned recovery/reinstallation workflow).
- **Runtime phase:** do not mount /custom.iso; do not make the ISO a prerequisite in the normal start script. The installed guest boots from persistent storage.
- **Persistent state:** /home/deck/WindowsVM/storage remains mounted at /storage. The guest disk (data.img) and associated firmware/state files live there. Preserve this directory when replacing a container wrapper.
- **Container configuration:** Podman bind mounts are part of the container definition. Deleting an ISO from the host does not remove its old mount entry from an existing container. Recreate the container without that mount to remove the obsolete dependency; retain the host storage directory.

### Verified repair — 2026-11-14

The original stopped container was preserved as windows-box-iso-legacy. A replacement windows-box was created against the same persistent storage and shared directory, using the same pinned image, protected environment file, KVM device, LAN console publication and manual restart policy. The replacement was inspected while still in the created state.

Verified replacement mounts:

~~~text
/home/deck/WindowsVM/storage -> /storage  RW=true
/home/deck/WindowsVM/shared  -> /shared   RW=true
~~~

There is no /custom.iso mount. The replacement was then started successfully; Podman reported it running, the host listener appeared on 192.168.1.161:8006, and the user confirmed successful Web Console connectivity. The ISO-free runtime correction therefore passed container creation, mount inspection, startup and console-connectivity validation.

The corrected local start script no longer defines an ISO path, checks whether an installation ISO is readable, or mounts /custom.iso. It continues to preserve the persistent storage and shared-folder mounts and the existing pinned runtime configuration.

The prior ISO-mounted deployment details above are retained as historical installation evidence. They must not be copied into a normal runtime start script.

### Required pattern for future VMs

1. Create a unique project root, protected environment file and empty, unique storage directory for the new guest.
2. If using a custom ISO, create the initial installation container with that ISO mounted read-only at /custom.iso. Inspect its mounts before starting it.
3. Complete Windows installation and shut down the guest.
4. Preserve the new guest's storage directory. Remove/recreate only the container object, then create the normal runtime container with the storage and shared-folder mounts but without the ISO mount.
5. Inspect the runtime container mounts before starting it. Confirm that /storage points to the intended guest directory and that no /custom.iso mount remains.
6. Start the runtime container and verify the guest boots from its installed disk.

Do not run two containers against the same guest storage simultaneously. Do not delete or recreate the storage directory during this transition. Retain the ISO separately as optional offline installation media if desired; its continued presence is not required for ordinary VM startup.


## Console operation and multi-VM deployment

This chapter incorporates the former Console and Second-VM Deployment Guide. It is now part of this Installation Guide and is no longer maintained as a separate document.

#### 1. Purpose and architecture

This guide explains how to operate the browser console, where VM resources are configured, and how to create another independent Windows guest without reusing the first guest's disk or identity.

The console is a display/input channel, not a complete VM management dashboard. The current architecture does not include a central web manager comparable to VMware Horizon. Podman CLI provides the inventory and lifecycle view, while each Windows guest has a separate noVNC endpoint:

- noVNC displays the Windows guest screen and forwards keyboard/mouse input.
- SteamOS and Podman own the container lifecycle and resource configuration.
- Dockur environment variables are read when the container is created.
- QEMU/KVM runs the virtual machine.
- /home/deck/WindowsVM/storage contains persistent guest state and must not be removed when recreating the container.

~~~text
PC client (192.168.1.169)
        | HTTP / noVNC, TCP 8006
        v
Steam Deck host (192.168.1.161)
        | Podman published port
        v
windows-box container
        | QEMU + KVM (/dev/kvm)
        v
Windows guest: windows-vm
        +-- 4 vCPUs
        +-- 6 GiB RAM
        +-- 128 GiB growable raw disk
        +-- persistent host storage
~~~

The selected viewer URL is **http://192.168.1.161:8006/**. The Deck's loopback address `127.0.0.1:8006` is no longer bound; this is intentional and no restoration is requested.

**Current verified state (2026-11-12):** the start script publishes `192.168.1.161:8006:8006`; the container was recreated; `podman port` and `ss` confirmed the LAN listener; and the user successfully opened the console from PC client `192.168.1.169` in Brave and Chrome simultaneously. Both viewers show the same guest desktop.

#### 1.1 How Podman, Dockur, QEMU/KVM and each Windows VM relate

The important distinction is that **Dockur is the container image used as a VM runtime package; it is not a single shared hypervisor instance that hosts all guests inside one container**.

For this deployment model, create one rootless Podman container from the Dockur image for each Windows guest. Each such container launches its own QEMU process and owns one Windows guest. All containers share the host's Podman engine and KVM device, and may use the same locally cached Dockur image, but each guest must have independent storage, configuration, container name and host console port.

~~~text
Steam Deck OLED / SteamOS host
|
+-- AMD-V / SVM CPU virtualisation support
|   |
|   +-- Linux KVM kernel modules (kvm, kvm_amd)
|       |
|       +-- /dev/kvm
|
+-- Rootless Podman (one user-level container engine)
    |
    +-- Dockur Windows image (shared image/template, pinned digest)
    |   |
    |   +-- Container: windows-box
    |   |   |
    |   |   +-- Dockur entrypoint / helper services
    |   |   +-- QEMU process using KVM acceleration
    |   |   +-- Virtual hardware: vCPU, RAM, disk, UEFI
    |   |   +-- Windows guest: windows-vm
    |   |   +-- Host bind mount:
    |   |       /home/deck/WindowsVM/storage -> /storage
    |   |   +-- noVNC viewer -> host TCP 8006
    |   |
    |   +-- Container: windows-box-2 (example, not created)
    |       |
    |       +-- Separate QEMU process using KVM acceleration
    |       +-- Separate virtual hardware and Windows guest
    |       +-- Separate host bind mount:
    |       |   /home/deck/WindowsVM-2/storage -> /storage
    |       +-- Separate noVNC viewer -> host TCP 8007
    |
    +-- Other unrelated Podman containers (Pi-hole, etc.)
~~~

The Dockur image is a reusable image artifact. A container is an instance created from that image. The QEMU process inside each container is the actual VM execution process. The Windows operating system is the guest. KVM is the host kernel's hardware-virtualisation acceleration interface; it is not another Windows VM and is not a management console.

The diagram is a conceptual relationship diagram. The first container and its QEMU guest are the deployed instance. The second container is only an example documented for a future independent guest.

#### Virtual hardware notes

- **vCPU and RAM:** assigned to each QEMU guest through its own container environment/configuration.
- **Virtual disk:** stored in that guest's independent host-backed storage directory.
- **UEFI:** provided by the guest firmware files and QEMU configuration in the Dockur storage/runtime model.
- **TPM 2.0:** Windows 11 may require a virtual TPM. Do not assume a separate host TPM device or software TPM installation from this diagram; the precise virtual TPM implementation is image-version/configuration-specific and was not independently audited in the current guest.
- **Networking:** the current guest uses Dockur's user-mode networking (passt observed in the container process list), rather than an independently bridged LAN adapter. The guest-reported address must not be mistaken for proof that each guest has a distinct LAN IP.
- **noVNC:** each guest has its own viewer endpoint. Different containers must publish different host ports.

#### 2. Apply the selected LAN address to the existing VM

This changes only the container's host-side web-console publication. It does not change the Windows guest disk or its installation.

**Expected result:** Deck host 192.168.1.161 listens on TCP 8006; the PC opens http://192.168.1.161:8006/.

First inspect the current script line and persistent mounts:

~~~bash
SCRIPT="/home/deck/WindowsVM/config/windows-box-start.sh"
grep -n -- '--publish' "$SCRIPT"
podman inspect windows-box --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
~~~

The original publication was `127.0.0.1:8006:8006`; it has now been changed and verified as `192.168.1.161:8006:8006`. Confirm the persistent host storage mount is `/home/deck/WindowsVM/storage -> /storage` before any future container recreation. If either differs from the documented current state, stop and inspect rather than applying the example blindly.

After confirming those facts, edit the start script directly. This is a disposable lab. The user has explicitly rejected backup copies of guest state and configuration scripts. Preserve the known original setting in project documentation instead:

~~~bash
set -euo pipefail
SCRIPT="/home/deck/WindowsVM/config/windows-box-start.sh"
grep -qF -- '--publish 127.0.0.1:8006:8006' "$SCRIPT"
sed -i 's/--publish 127\.0\.0\.1:8006:8006/--publish 192.168.1.161:8006:8006/' "$SCRIPT"
sed -i 's#http://127\.0\.0\.1:8006#http://192.168.1.161:8006#' "$SCRIPT"

bash -n "$SCRIPT"
grep -nE -- '--publish|Web console:' "$SCRIPT"
~~~

Review the diff. It should change only the host publication and printed console URL.

Then recreate the container wrapper while retaining the persistent host mounts:

~~~bash
set -euo pipefail
podman stop --time 120 windows-box
podman rm windows-box
/home/deck/WindowsVM/config/windows-box-start.sh
~~~

The rm command removes the stopped container object, not /home/deck/WindowsVM/storage. Do not run rm -rf on the project directory or storage. The start script creates a new runtime container using the same pinned image, environment file and persistent bind mounts. The normal runtime container does not mount an installation ISO.

Verify on the Steam Deck:

~~~bash
podman port windows-box
ss -ltn '( sport = :8006 )'
podman inspect windows-box --format 'State={{.State.Status}} Restart={{.HostConfig.RestartPolicy.Name}}'
~~~

Expected publication/listener: `192.168.1.161:8006`. This procedure has been executed and the browser test passed from PC `192.168.1.169`. The user also confirmed that Brave and Chrome can view the same guest desktop simultaneously. A host listener check does not replace the browser test for future changes.

If the LAN binding must be reverted, edit the two documented lines directly back to 127.0.0.1:8006 and validate with bash -n. No script backup is created. Preserve /home/deck/WindowsVM/storage throughout.

No firewall change is included. The inspected public zone already has broad TCP/UDP port allowances from 1024 through 65535. Do not add another broad rule or publish guest RDP as part of this change.

#### 3. Using the noVNC web console

1. Start the VM on the Steam Deck:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-start.sh
   ~~~

2. From the PC, open:

   ~~~text
   http://192.168.1.161:8006/
   ~~~

3. Wait for the Windows desktop. The viewer is the guest's screen and input device.
4. Use the noVNC toolbar for display scaling, keyboard handling and fullscreen as available in the bundled viewer.
5. Shut Windows down from inside Windows when practical, or use the Deck stop script:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-stop.sh
   ~~~

The stop script requests a container stop with a 120-second timeout.

#### What the console does not do

The noVNC page does not provide authoritative controls for vCPU count, RAM, disk capacity, Podman mounts, KVM device access or host port publication. Those are deployment settings controlled on SteamOS.

The web viewer is a convenient screen/keyboard/mouse console, particularly during installation and recovery. It is not a hypervisor settings panel or a Windows RDP service.

#### 4. Where CPU, RAM, disk and Windows setup parameters live

Edit the protected Steam Deck environment file:

~~~text
/home/deck/WindowsVM/config/windows-box.env
~~~

It is mode 0600 and contains a generated Windows account password. Do not print the complete file, paste it into chat, or commit it to Git.

Known deployed values:

| Variable | Current value | Meaning |
|---|---:|---|
| VERSION | 11 | Windows 11 Pro download selection; mounted custom ISO takes precedence |
| LANGUAGE | en-US | Windows language |
| REGION | en-US | Regional formats |
| KEYBOARD | en-US | Keyboard layout |
| CPU_CORES | 4 | Virtual CPU cores |
| RAM_SIZE | 6G | Guest RAM |
| RAM_CHECK | Y | Check host memory before starting |
| KVM | Y | Hardware-assisted virtualisation |
| DISK_SIZE | 128G | Primary virtual disk capacity |
| DISK_FMT | raw | Raw disk image format |
| ALLOCATE | N | Do not preallocate full disk capacity |
| NETWORK | user | User-mode networking; passt observed at runtime |
| DISPLAY | web | Web viewer display backend |
| WEB | Y | Enable web viewer |
| WEB_PORT | 8006 | Web viewer port inside the container |
| USERNAME | DeckVM | Local Windows account name |
| AUTOLOGIN | Y | Automatically sign in after startup |
| HOST | windows-vm | Windows computer name |
| SAMBA | Y | Enable shared-folder Samba integration |

The environment file also contains PASSWORD; its value is intentionally not shown. KEY is not configured in the known deployment. Windows can install without supplying a product key; that does not activate Windows or grant a licence. Activation/licensing is separate.

#### Change procedure

1. Stop the VM gracefully:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-stop.sh
   ~~~

2. Edit only the required keys locally:

   ~~~bash
   nano /home/deck/WindowsVM/config/windows-box.env
   ~~~

3. Check permissions without displaying contents:

   ~~~bash
   stat -c '%A %a %U:%G %n' /home/deck/WindowsVM/config/windows-box.env
   ~~~

   Expected mode: 600, owned by deck:deck.

4. Recreate the container if the change affects container creation or QEMU configuration. A simple podman start windows-box does not apply modified environment variables, devices, mounts or port publications; the existing start script starts the existing container unchanged.
5. Preserve /home/deck/WindowsVM/storage. Removing the container is not the same as deleting the persistent guest disk.

CPU_CORES and RAM_SIZE changes require a new container configuration so the entrypoint can launch QEMU with the new values. Plan memory conservatively: SteamOS, the desktop, browsers and other containers also need RAM.

Do not reduce DISK_SIZE to shrink an existing guest. Increasing virtual disk capacity and extending the Windows partition are separate operations; validate the exact resize procedure before changing an existing disk.

#### 5. How the current unattended Windows installation worked

The deployment uses the image pinned to:

~~~text
docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc
~~~

Dockur automates Windows Setup. The deployment supplies settings through environment variables rather than a manually authored Windows answer file.

The current configuration used:

- VERSION=11: Windows 11 Pro selection when Dockur downloads its own media.
- A local ISO mounted read-only as /custom.iso. When a custom ISO is mounted, it is used as the installation media; VERSION is not the source of the installed build.
- USERNAME=DeckVM: local account name.
- PASSWORD: generated locally and stored in the protected environment file; secret value is not recorded here.
- AUTOLOGIN=Y: automatic sign-in after startup. This explains why no login password prompt appeared; it does not mean the account has no password.
- HOST=windows-vm: Windows computer name.
- LANGUAGE, REGION and KEYBOARD: locale and input configuration.
- CPU_CORES=4, RAM_SIZE=6G, DISK_SIZE=128G, DISK_FMT=raw and ALLOCATE=N: virtual hardware and disk creation.
- KVM=Y, NETWORK=user, DISPLAY=web, WEB=Y, WEB_PORT=8006 and SAMBA=Y: execution, networking, viewer and file-sharing behavior.

No product key was supplied in the known configuration. Installation without entering a key does not activate Windows. Use a valid licence/entitlement separately; never put a real key in Git or a public script.

#### Timing and persistence

Account, locale, computer-name and initial installation variables are intended to be set before first installation. Changing USERNAME, PASSWORD, VERSION or locale variables after Windows is installed does not reliably reconfigure the existing guest. For a genuinely fresh guest, create a separate empty storage directory and a separate container.

The official Dockur environment reference documents variables including USERNAME, PASSWORD, AUTOLOGIN, KEY, CPU_CORES, RAM_SIZE, DISK_SIZE, KVM, NETWORK, WEB_PORT and PROTECT. Check the reference against the exact pinned image before using less common settings:

https://github.com/dockur/windows/blob/master/docs/environment.md

#### 6. Create another Windows VM — reusable step-by-step checklist

This is the reusable deployment recipe for a new, independent Windows VM project. Follow it from top to bottom. The examples use a second VM name, but every path and name is deliberately selected per project.

**Architecture rule:** the Dockur image is the VM runtime package. It is not a Windows ISO. Windows installation media is selected separately. For this workflow, use a locally prepared UUP ISO and mount it into the installation container at `/custom.iso`. After Windows is installed, recreate the container without that ISO mount.

**One VM at a time:** this Steam Deck workflow normally runs only one Windows guest at once. Sequential VM projects may therefore reuse host TCP port `8006` and the same bookmark. The previous container must be stopped before starting the next one. If two guests are intentionally run simultaneously, they need distinct host ports and sufficient CPU/RAM/storage.

#### 6.1 Deployment checklist — decisions before commands

Complete these choices before creating files or containers:

- [ ] **Project root:** choose a unique path, e.g. `/home/deck/Windows11HomeVM`.
- [ ] **Container name:** choose a unique Podman name, e.g. `windows-home-box`.
- [ ] **Environment filename:** choose a per-VM file under that project's `config/`.
- [ ] **Windows ISO:** identify the exact local ISO file to install, e.g. `/home/deck/Downloads/windows-11-home.iso`. This is where the ISO is selected. It is not selected by the Dockur image digest.
- [ ] **Guest identity and resources:** decide edition/media, Windows account name, locally generated password, hostname, CPU, RAM, disk, locale and keyboard.
- [ ] **Host console port:** use `8006` for sequential/manual VM use; select a different free port only if concurrent guests are required.
- [ ] **Persistent storage:** each VM must have its own empty `storage/` directory and its own `shared/` directory.
- [ ] **Image version:** use the reviewed pinned Dockur image digest; do not silently switch to a moving tag.

Do not proceed if the project root, container name or storage directory already exists. Inspect it rather than overwriting it.

#### 6.2 Read-only preflight

Run as the normal SteamOS user `deck`, not with sudo. Adapt the values to the new project:

~~~bash
PROJECT="/home/deck/Windows11HomeVM"
CONTAINER="windows-home-box"
ISO="/home/deck/Downloads/windows-11-home.iso"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
HOST_PORT="8006"

echo "===== PROJECT / CONTAINER COLLISIONS ====="
[[ ! -e "$PROJECT" ]] && echo "Project path is available" || echo "STOP: project path already exists"
podman ps -a --filter "name=^$CONTAINER$"

echo
echo "===== SELECTED WINDOWS ISO ====="
[[ -r "$ISO" ]] && stat -c 'Readable: yes | Size: %s bytes | %n' "$ISO" || echo "STOP: ISO is not readable"

echo
echo "===== PINNED DOCKUR IMAGE ====="
podman image exists "$IMAGE" && echo "Image available" || echo "STOP: pinned image is unavailable"

echo
echo "===== KVM / STORAGE / MEMORY ====="
test -r /dev/kvm && test -w /dev/kvm && echo "/dev/kvm accessible" || echo "STOP: /dev/kvm unavailable"
df -h /home
free -h

echo
echo "===== HOST CONSOLE PORT ====="
ss -lnt "( sport = :$HOST_PORT )"
~~~

A stopped old container may retain historical port-publication metadata. That does not itself mean the host port is occupied; check the actual listener and ensure no other guest is running on it. Do not remove or modify old containers as part of this preflight.

#### 6.3 Create the project and protected per-VM environment file

Set `PROJECT`, `CONTAINER` and `ENV_FILE` for this VM. Directory paths are derived from `PROJECT`, so changing that root adapts the layout. The ISO path is a separate deployment input and is intentionally not stored in the normal runtime environment file.

~~~bash
set -euo pipefail
umask 077

PROJECT="/home/deck/Windows11HomeVM"
CONFIG="$PROJECT/config"
STORAGE="$PROJECT/storage"
SHARED="$PROJECT/shared"
ENV_FILE="$CONFIG/windows-home-box.env"

if [[ -e "$PROJECT" ]]; then
    echo "ERROR: $PROJECT already exists; inspect it before proceeding." >&2
    exit 1
fi

mkdir -p "$CONFIG" "$STORAGE" "$SHARED"
chmod 700 "$PROJECT" "$CONFIG" "$STORAGE" "$SHARED"

VM_PASSWORD="$(openssl rand -hex 24)"
cat > "$ENV_FILE" <<EOF
VERSION=11
LANGUAGE=en-US
REGION=fr-FR
KEYBOARD=fr-FR
CPU_CORES=4
RAM_SIZE=8G
RAM_CHECK=Y
KVM=Y
DISK_SIZE=72G
DISK_FMT=raw
ALLOCATE=N
NETWORK=user
DISPLAY=web
WIDTH=1920
HEIGHT=1080
WEB=Y
WEB_PORT=8006
PROTECT=N
USERNAME=win-user
PASSWORD=$VM_PASSWORD
AUTOLOGIN=Y
HOST=windeck-home
SAMBA=Y
EOF
unset VM_PASSWORD
chmod 600 "$ENV_FILE"

stat -c '%A %a %U:%G %n' "$PROJECT" "$CONFIG" "$STORAGE" "$SHARED" "$ENV_FILE"
~~~

The values above are an example profile, not universal defaults. Review and change guest settings before first installation. Keep the password local; never print the environment file, paste its contents into chat, or commit it to Git. Preserve the documented environment template's optional commented settings when using that template.

#### 6.4 Select the Windows ISO — the critical step

**This is the explicit ISO selection point.** Set the host-side path in the installation command:

~~~bash
ISO="/home/deck/Downloads/windows-11-home.iso"
~~~

Then expose that exact file to the container using a read-only bind mount:

~~~bash
--volume "$ISO:/custom.iso:ro"
~~~

The left side is the actual ISO path on SteamOS. The right side, `/custom.iso`, is the path Dockur expects inside the container. The `:ro` suffix prevents the container from modifying the source ISO.

When `/custom.iso` is mounted, Dockur uses that local ISO and ignores the `VERSION` download selection. Thus `VERSION=11` in the environment file does **not** choose or download media in this custom-ISO deployment. It is not a substitute for setting `ISO=/path/to/your.iso`.

#### 6.5 Create the temporary installation container

Use the unique project/container names, the selected local ISO, the pinned image and the project's persistent directories. This is the **only** creation command in the normal workflow that includes the ISO mount.

~~~bash
set -euo pipefail

PROJECT="/home/deck/Windows11HomeVM"
CONTAINER="windows-home-box"
ENV_FILE="$PROJECT/config/windows-home-box.env"
ISO="/home/deck/Downloads/windows-11-home.iso"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
HOST_IP="192.168.1.161"
HOST_PORT="8006"

test -r "$ISO"
test -r "$ENV_FILE"
podman image exists "$IMAGE"

podman create \
    --name "$CONTAINER" \
    --pull=never \
    --restart=no \
    --stop-timeout 120 \
    --device=/dev/kvm \
    --publish "$HOST_IP:$HOST_PORT:8006" \
    --volume "$PROJECT/storage:/storage:rw" \
    --volume "$PROJECT/shared:/shared:rw" \
    --volume "$ISO:/custom.iso:ro" \
    --env-file "$ENV_FILE" \
    "$IMAGE"
~~~

**Required device/capability baseline — follow this for future VMs:**

- Include **only** `--device=/dev/kvm` for the proven hardware-virtualisation device mapping.
- Do **not** add `--device=/dev/net/tun`, `--cap-add=NET_ADMIN` or `--privileged` by default. The known-working first VM was created with `/dev/kvm` only, without TUN, NET_ADMIN or privileged mode. No requirement for the extra device or capability has been demonstrated.
- Add another device or capability only when a specific feature requires it and a separate test establishes that requirement. Do not copy unexplained capabilities from an example command.

**Podman inspection caveat from this SteamOS rootless deployment:** `podman inspect` returned an empty `HostConfig.Devices` array for both the original known-working `windows-box` and the recreated `windows-home-box`, even though each recorded `CreateCommand` includes `--device=/dev/kvm`. Therefore, do not interpret `Devices=[]` alone as proof that KVM was not requested or is unavailable. Check the recorded create command, then verify actual QEMU/KVM startup evidence when diagnosing runtime acceleration. The create command records the requested configuration; it does not, by itself, prove that QEMU successfully initialized KVM.

Before starting, inspect the created container:

~~~bash
podman inspect "$CONTAINER" --format '{{.State.Status}}'
podman inspect "$CONTAINER" --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
podman inspect "$CONTAINER" --format '{{json .HostConfig.PortBindings}}'
~~~

Confirm all of the following:

- [ ] Container is created but not yet running.
- [ ] The intended project `storage/` maps to `/storage`.
- [ ] The intended project `shared/` maps to `/shared`.
- [ ] The selected ISO maps to `/custom.iso` with read-only access.
- [ ] The expected host IP and port map to container port 8006.
- [ ] No other Windows guest is running on the same host port.

Only then start the installation container:

~~~bash
podman start "$CONTAINER"
~~~

Open `http://192.168.1.161:8006/` from the LAN client and complete/monitor Windows Setup. Wait until Windows is installed on the project's persistent virtual disk. Shut Windows down cleanly before changing the container definition.

#### 6.6 Transition from installation to normal runtime

The installation ISO is not part of the installed Windows disk and is not required for ordinary startup. The ISO mount exists only in the temporary installation container definition.

After Windows Setup is complete and the guest is shut down:

1. Stop the container if it is still running.
2. Remove only the temporary container object.
3. Do **not** delete or recreate the project directory, `storage/` or `shared/`.
4. Recreate the container using the same image, environment file, device, port and persistent mounts, but omit the `/custom.iso` mount.
5. Inspect the new container before starting it.

~~~bash
set -euo pipefail

PROJECT="/home/deck/Windows11HomeVM"
CONTAINER="windows-home-box"
ENV_FILE="$PROJECT/config/windows-home-box.env"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
HOST_IP="192.168.1.161"
HOST_PORT="8006"

podman stop --time 120 "$CONTAINER" 2>/dev/null || true
podman rm "$CONTAINER"

podman create \
    --name "$CONTAINER" \
    --pull=never \
    --restart=no \
    --stop-timeout 120 \
    --device=/dev/kvm \
    --publish "$HOST_IP:$HOST_PORT:8006" \
    --volume "$PROJECT/storage:/storage:rw" \
    --volume "$PROJECT/shared:/shared:rw" \
    --env-file "$ENV_FILE" \
    "$IMAGE"

echo "=== Verify ISO-free runtime mounts before start ==="
podman inspect "$CONTAINER" --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
~~~

The inspected mounts must include the intended `storage/` and `shared/` directories and must **not** include `/custom.iso`. Start only after confirming this:

~~~bash
podman start "$CONTAINER"
~~~

#### 6.7 Final verification and operating checklist

- [ ] Windows boots from the persistent virtual disk with no ISO mounted.
- [ ] Container uses the intended pinned Dockur image.
- [ ] `/storage` maps to this VM project's unique storage directory.
- [ ] `/shared` maps to this VM project's unique shared directory.
- [ ] No `/custom.iso` mount exists in the normal runtime container.
- [ ] Host console is reachable at `http://192.168.1.161:8006/`.
- [ ] Container restart policy is `no`; startup remains manual.
- [ ] Start/stop/status scripts, if created, describe the ISO-free normal runtime only.

Useful read-only checks:

~~~bash
podman ps -a --filter "name=^windows-home-box$"
podman port windows-home-box
podman inspect windows-home-box --format 'State={{.State.Status}} Restart={{.HostConfig.RestartPolicy.Name}}'
podman inspect windows-home-box --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
podman top windows-home-box
ss -lnt '( sport = :8006 )'
~~~

For a future VM, repeat this checklist with a new project root, container name, environment file, ISO path and unique storage. Reusing port 8006 is appropriate when VMs are strictly sequential; only concurrently active guests require distinct host ports.

#### 6.8 Actual second-VM deployment record — 2026-11-14

**USER-CONFIRMED / IN PROGRESS:** The reusable procedure above was executed for the independent Home guest:

| Item | Verified state |
|---|---|
| Project | `/home/deck/Windows11HomeVM` |
| Container | `windows-home-box` |
| Image | Same pinned Dockur image digest as the first VM |
| Device request | `--device=/dev/kvm` |
| TUN / NET_ADMIN | Not requested in the final container definition |
| Privileged mode | `false` |
| Host console | `192.168.1.161:8006` |
| Persistent mounts | Project `storage/` to `/storage`; project `shared/` to `/shared` |
| Installation media | Selected local ISO mounted read-only at `/custom.iso` for installation |
| Restart policy | `no` |
| Initial state before launch | `created` |
| Current state | `running`; user confirmed successful connection to the Web Console and Windows Setup is in progress |

The first proposed Home VM create command temporarily included `/dev/net/tun` and `NET_ADMIN`. Those additions were removed by recreating the still-unstarted container before its first launch. The final container definition follows the KVM-only baseline above. No TUN or NET_ADMIN requirement was established.

The Home VM's `HostConfig.Devices` inspection also returned `[]`, matching the original known-working container. Its recorded `CreateCommand` includes `--device=/dev/kvm`. This is a deployment-specific inspection observation, not evidence that KVM is missing. The Home VM's successful Web Console connection confirms container startup and viewer reachability; it does not alone prove the QEMU process selected KVM acceleration. Record that only after obtaining direct QEMU/KVM runtime evidence.

Windows installation has not yet been reported complete. Do not mark the Home guest as fully installed or ISO-independent until Setup completes, the guest is shut down, and the ISO-free runtime transition is verified.

#### 7. Lifecycle commands

#### Listing and checking all Windows VM containers

There is no VMware Horizon-style central console in the current deployment. Podman is the host-side inventory and lifecycle manager; each Dockur container exposes its own noVNC viewer on its own published port.

Use podman ps to see only running containers, or podman ps -a to include stopped/exited containers. The naming convention used in this project is windows-box, windows-box-2, and so on.

~~~bash
echo "===== ALL WINDOWS VM CONTAINERS ====="
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | { head -n 1; grep -E '^windows-box(-[0-9]+)?[[:space:]]' || true; }

echo
echo "===== RUNNING WINDOWS VM CONTAINERS ====="
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | { head -n 1; grep -E '^windows-box(-[0-9]+)?[[:space:]]' || true; }
~~~

For a specific VM:

~~~bash
podman inspect windows-box --format 'Name={{.Name}} State={{.State.Status}}'
podman port windows-box
~~~

Interpretation:

- running: the container is running; verify QEMU is active if diagnosing the guest.
- exited: the container exists but is stopped.
- created: the container exists but has not started successfully yet.
- No matching container: it has not been created or has been removed.

To check QEMU inside a running instance:

~~~bash
podman top windows-box
~~~

Replace the name with the desired instance. The per-VM noVNC URL is the host IP and port assigned to that container (currently intended to be 192.168.1.161:8006 for the first VM and 192.168.1.161:8007 for the second example).



Existing VM:

~~~bash
/home/deck/WindowsVM/config/windows-box-start.sh
/home/deck/WindowsVM/config/windows-box-status.sh
/home/deck/WindowsVM/config/windows-box-stop.sh
~~~

Second example, if created:

~~~bash
podman start windows-box-2
podman stop --time 120 windows-box-2
podman ps -a --filter name='^windows-box-2$'
~~~

Neither container is configured for boot autostart.

#### 8. Cleanly remove a Windows VM

There are two different operations. Choose deliberately:

1. **Remove the Podman container but keep the Windows guest data.** This is useful for replacing a container wrapper while retaining the installed Windows system.
2. **Permanently remove the VM and its project data.** This deletes the Windows installation, virtual disk, firmware state, environment file and shared-folder contents. This is intentionally irreversible under the disposable-lab policy; no guest backup or snapshot is maintained.

Do not confuse container removal with guest removal. In this project, /storage is a host bind mount. Removing the container does not remove the host directory or its contents. Podman's documentation distinguishes containers from bind-mounted host data:
https://docs.podman.io/en/stable/markdown/podman-run.1.html
https://docs.podman.io/en/latest/markdown/podman-rm.1.html

#### 8.1 Inventory and confirm the exact VM

Run as deck, without sudo:

~~~bash
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
podman inspect windows-box --format '{{.Name}} state={{.State.Status}}'
podman inspect windows-box --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
~~~

For a second guest, substitute its exact container name, such as windows-box-2. Confirm the host project directory from the /storage mount before proceeding. Do not infer the data path from a container name alone.

#### 8.2 Remove only the container; preserve Windows data

This leaves the project directory and guest disk intact. It removes the container object, not the Dockur image and not the host bind-mounted files.

For the current VM:

~~~bash
set -euo pipefail
NAME="windows-box"

podman container exists "$NAME" || {
    echo "Container $NAME does not exist."
    exit 1
}

STATE="$(podman inspect --format '{{.State.Status}}' "$NAME")"
if [[ "$STATE" == "running" ]]; then
    podman stop --time 120 "$NAME"
fi

podman rm "$NAME"

if podman container exists "$NAME"; then
    echo "ERROR: container still exists; inspect before continuing." >&2
    exit 1
fi

test -d /home/deck/WindowsVM/storage
echo "Container removed; persistent Windows storage retained."
~~~

For another guest, change both the container name and the verified project path. Do not use podman rm -f as the routine path; if graceful stop or removal fails, inspect the state and logs before deciding how to proceed.

#### 8.3 Permanently erase the VM and its project directory

**DESTRUCTIVE:** this removes the Windows guest and its persistent files. The project intentionally maintains no Windows guest backup or snapshot. Use this procedure only when you intend to discard the complete guest installation and its data.

First remove the container using Section 8.2. Then verify the exact project directory. The example below is intentionally tied to the current VM path and asks for an explicit confirmation phrase:

~~~bash
set -euo pipefail

NAME="windows-box"
PROJECT="/home/deck/WindowsVM"
EXPECTED="/home/deck/WindowsVM"

# Refuse to proceed if the container still exists.
if podman container exists "$NAME"; then
    echo "ERROR: remove container $NAME first." >&2
    exit 1
fi

# Refuse unexpected paths and require the expected storage directory.
[[ "$PROJECT" == "$EXPECTED" ]] || {
    echo "ERROR: project path mismatch." >&2
    exit 1
}
[[ -d "$PROJECT/storage" ]] || {
    echo "ERROR: expected storage directory not found." >&2
    exit 1
}

echo "This will permanently delete:"
printf '  %s\n' "$PROJECT"
read -r -p 'Type DELETE-WINDOWS-VM to continue: ' CONFIRM
[[ "$CONFIRM" == "DELETE-WINDOWS-VM" ]] || {
    echo "Cancelled."
    exit 1
}

rm -r --one-file-system -- "$PROJECT"
echo "Project directory removed."
~~~

For a second VM, update NAME, PROJECT and EXPECTED to that VM's independently verified values before running. Never copy this command unchanged for an arbitrary path.

#### 8.4 What is not removed automatically

- The shared Dockur image remains available for other Windows VM containers. Do not remove it while another guest uses it.
- Any installation ISO stored outside the project is independent of the guest storage; this procedure does not delete it. It is not required by the normal runtime container.
- Other Podman containers and projects are unaffected.
- No global prune command is required. Avoid podman system prune, podman volume prune, or broad podman rm -a for removing one guest.

After removal, list remaining containers:

~~~bash
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
~~~

#### 9. Security and operational notes

- noVNC is an administrative console. Anyone able to reach an unprotected viewer may be able to interact with the Windows desktop.
- The user accepts LAN reachability. The current public firewalld zone already has broad TCP/UDP allowances for ports 1024-65535; this guide does not claim access is restricted to the single PC.
- Dockur documents PROTECT as enabling password protection for the web interface. Verify its behavior against the pinned image before relying on it.
- Do not publish guest RDP (3389) unless separately required and reviewed.
- Keep environment files mode 0600; do not commit them. Never print passwords or product keys.
- Use unique host ports and persistent directories for every guest.
- Stop a guest before changing its deployment configuration.
- Never remove a storage directory as part of routine container recreation.
- Disposable-lab policy: do not create Windows guest backups, snapshots or virtual-disk copies. Preserve useful configuration parameters and verified findings in documentation; rebuild a damaged guest rather than restoring a wounded one.

#### 10. Connections, identities and RDP

See [Windows VM Connections and Credential Naming Convention](./WINDOWS-VM-CONNECTIONS-AND-CREDENTIALS.md) for the `container-user`, `console-user` and `win-user` roles, the PC/Deck connection matrix, `host.lan\Data` mapping, and the planned RDP port-forwarding design.

**RDP is not yet configured.** The current guest uses `NETWORK=user`/`passt`; Dockur requires custom guest ports to be listed in `USER_PORTS` in user-mode networking. The intended RDP target from the PC is `192.168.1.161:3389`, but it will not work until Windows guest readiness and host/container port forwarding are verified and configured. Do not infer that the guest's reported `192.168.1.161` is a directly reachable independent LAN address.

#### 11. References

- Dockur environment variables: https://github.com/dockur/windows/blob/master/docs/environment.md
- Dockur project: https://github.com/dockur/windows
- Podman run and bind mounts: https://docs.podman.io/en/stable/markdown/podman-run.1.html
- Podman container removal: https://docs.podman.io/en/latest/markdown/podman-rm.1.html
- [Installation guide and Roadbook](#)
- [Project README](../README.md)

---

*Living operations guide. Distinguish documented templates from commands actually executed on the Steam Deck.*


#### 3.1 Verified PC-client access — 2026-11-12

The user confirmed that `http://192.168.1.161:8006/` opens successfully from PC client `192.168.1.169` in both Brave and Chrome at the same time. This is a mirrored view of one Windows guest console, not independent guest sessions. No guest RDP port was published as part of this change.


#### Custom ISO lifecycle — mandatory for every VM

The installation ISO is installation media, not the installed Windows system. The 2026-11-14 decision applies to every VM, not only the first deployment:

1. During initial installation only, the temporary installation container may include the selected ISO as a read-only `/custom.iso` mount.
2. Complete Windows Setup and shut down the guest.
3. Preserve the VM's own `storage/` and `shared/` directories. Remove only the stopped installation container object.
4. Create the normal runtime container using the same intended VM-specific settings and persistent mounts, but omit `/custom.iso` entirely.
5. Inspect the stopped runtime container. Verify its unique `storage/` and `shared/` mappings and verify that no `/custom.iso` mount exists.
6. Start the runtime container and verify that Windows boots from its installed disk.

This applies to the first VM, every additional VM, and every future replacement guest. Never run installation and runtime containers concurrently against the same guest storage. Do not make the ISO a prerequisite in a normal runtime script or environment file. See the mandatory rule at the beginning of this guide.

## Roadbook — 2026-11-15 05:27 CET

### Critical major rule formalized — original decision dated 2026-11-14

The ISO-free runtime architecture was already decided and successfully verified on the first VM, `windows-box`, on 2026-11-14. The failure was that the rule was not sufficiently prominent and universal across the separate Installation Guide and Console/Second-VM Guide. The second-VM instructions still described the temporary installation ISO mount in their deployment recipe, so the distinction could be missed when creating another guest.

**Corrective documentation decision:** merge the console, multi-VM deployment, resource, lifecycle and removal procedures into this Installation Guide. This is the single authoritative source for Windows VM installation and deployment. The former `WINDOWS-VM-CONSOLE-AND-SECOND-VM-GUIDE.md` is retired and deleted after its operational content is incorporated here. The project README is updated to point only to this consolidated guide.

**Mandatory rule for every VM:** custom ISO mount only during initial installation or deliberately approved recovery/reinstallation; normal runtime container must never mount `/custom.iso`. Preserve each guest's persistent storage during the transition, recreate only the container object, inspect the ISO-free runtime mounts before starting, and never attach the same guest storage to two containers simultaneously.

### Home VM discrepancy identified — 2026-11-15

Read-only inspection of `windows-home-box` showed that its existing container still retained the initial-installation ISO bind mount. The recorded source path `/home/deck/Downloads/26100.1.240331-1435.GE_win11home_RELEASE_CLIENTCORE_OEM_RET_X64FRE_EN-US.ISO` was no longer present. A subsequent start attempt failed before the container started because crun could not stat that missing bind-mount source. The container was already reported as `Exited (0)` before this failed attempt; that status alone does not establish whether Windows had shut down cleanly.

This Home VM configuration is non-compliant with the 2026-11-14 architecture decision. It has not yet been migrated by this documentation update. Any correction must preserve the Home VM's existing `storage/` and `shared/` data, verify that no other container is using the same guest storage, confirm the guest is shut down, and obtain explicit approval before removing/recreating its container object. No VM container or guest storage was changed by this documentation work.

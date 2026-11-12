# Windows VM Installation Guide — Steam Deck OLED

A living installation guide and evidence log for evaluating a Windows virtual machine on the Steam Deck OLED (SteamOS).

> **Current phase: host/container KVM validation passed; persistent project directory and deployment scripts created and syntax-checked; container deployment pending. No Windows guest disk or guest OS has been created.**

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
- Publishing VM services or ports to the LAN.
- Installing host packages, changing host configuration, or modifying permissions without a reviewed proposal and explicit approval.

## 3. Naming and component roles

| Name | Role | Current state |
|---|---|---|
| `windows-box` | Dedicated rootless Podman container running the `dockurr/windows` QEMU/KVM Windows VM image | Image downloaded; runtime test passed; VM deployment pending |
| `windows-vm` | Proposed Windows guest VM | PENDING creation |
| QEMU | Virtual machine process/emulator; with KVM acceleration it can use the Linux kernel's hardware virtualisation interface | QEMU 11.1.1 available inside the downloaded `dockurr/windows` image; KVM probe passed |
| KVM | Linux kernel virtualisation facility exposed through `/dev/kvm` | Host and rootless-container access verified; QEMU KVM launch passed |
| OVMF | UEFI firmware implementation commonly used by QEMU guests | Not installed in the earlier inventory |
| swtpm | Software TPM emulator, potentially needed for a Windows 11 virtual TPM device | Not installed in the earlier inventory |
| libvirt / virt-manager | Optional VM management service and graphical management application | Not installed in the earlier inventory |

QEMU is the virtual-machine engine. KVM is the Linux kernel facility that can accelerate virtualisation. A Windows guest is a separate operating system running inside a virtual hardware definition; it does not replace SteamOS.

The prepared deployment configuration specifies 4 vCPUs, 6 GiB RAM and a 128 GiB virtual disk. The environment file has been created and validated, but these values are not yet active: the container has not been created or started.

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

The `windows-box` name now refers to the planned Podman container, not a Distrobox directory. No persistent VM storage directory or guest disk has been created.

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

**Status: SELECTED — KVM EXECUTION VALIDATED; WINDOWS GUEST NOT YET CREATED**

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
              |-- persistent Windows VM data (planned)
              |-- Windows guest (`windows-vm`, not yet created)
              |
              |-- virtual CPU / RAM / disk
              |-- UEFI firmware
              |-- virtual TPM 2.0, if required
              |-- NAT networking
```

The selected arrangement is rootless Podman running the purpose-built `dockurr/windows` image. The image contains QEMU; KVM is provided by the SteamOS kernel through `/dev/kvm`. This is a real Windows virtual machine, not a Windows userspace container. The selected approach was validated by a successful QEMU/KVM probe inside the image. The container still requires deliberate device, network, mount and lifecycle configuration; rootless operation does not by itself prove every aspect is isolated or safe.

### Candidate guest configuration

| Setting | Initial planning value | Status |
|---|---:|---|
| vCPU | 4 | Proposed |
| RAM | 6 GiB | Proposed |
| Disk | 128 GiB target capacity; allocation mode to be confirmed from image configuration | Proposed |
| Firmware | UEFI / OVMF | Proposed |
| TPM | TPM 2.0 virtual device | Proposed |
| Network | NAT | Proposed |
| GPU passthrough | Not planned | Not required for UUP conversion |
| Lifecycle | Manual start/stop | Required default |

These values must be checked against current host memory, disk capacity, Windows requirements and the selected VM implementation before creation.

## 7. Resilience and persistent project layout

**Design objective:** the Windows guest and its recoverable state must survive SteamOS system updates. The Podman container is a replaceable runtime wrapper; the guest's durable data must live in a dedicated location under the user's persistent home filesystem, not in the container writable layer or SteamOS-managed system directories.

Selected project root: `/home/deck/WindowsVM`.

Created and verified on 2026-11-12:

```text
/home/deck/WindowsVM/       mode 0700, owner deck:deck
├── backups/                mode 0700
├── config/                 mode 0700
├── docs/                   mode 0700
├── shared/                 mode 0700
└── storage/                mode 0700
```

The ISO remains at its existing path under `/home/deck/uup-box`; it is not duplicated into the project at this stage. The planned container mount is read-only at `/custom.iso`. The planned persistent guest-data mount is `/home/deck/WindowsVM/storage:/storage`. The exact contents written by the image and backup/restore procedure still need to be verified.

**Storage evidence:** `df -h /home` reported a 939 GiB filesystem, 433 GiB used and 507 GiB available (47% used) at the time of the check. The selected ISO was readable. No VM disk has yet been allocated.

**Image identity:** local image ID `cbfaef1f04b4cb08137512116a64ed2005b58852bf04067b3f896342d5b3cb02`; reported repo digests include `docker.io/dockurr/windows@sha256:16fd7c39a3e48bb946d29c59dc6015942e5b900a1fa5d7e5552053bfc48ee2ea` and `docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`. The latter is the manifest digest previously used for the KVM validation. The local image configuration reports the same image ID as the validated image.

**Resilience approach (planned):**
- Keep the VM disk and all guest state in the host-backed `storage/` directory.
- Keep the deployment definition and lifecycle commands in `config/`, independent of the container instance.
- Pin the tested image digest for reproducible recreation; perform image upgrades deliberately, not by silently tracking `latest`.
- Keep manual start/stop; do not add boot autostart or a host service.
- Back up the guest while stopped or using a documented application/VM-consistent method; test restore before treating backups as reliable.
- After SteamOS updates, verify Podman, KVM device access, project mount ownership, container recreation and guest boot. SteamOS update survival is a design goal, not a guarantee until recovery has been tested.

This layout was created successfully. The deployment configuration files now exist and have passed syntax/permission checks. Container creation, guest storage creation, backup validation and a full SteamOS-update recovery test remain pending.

## 8. Journey log

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

**Persistent directory creation:** created `/home/deck/WindowsVM` and subdirectories `config/`, `storage/`, `shared/`, `backups/`, and `docs/`. All were verified as owned by `deck:deck` with mode `0700`. This is the first persistent filesystem change for the VM project. No container or guest was created by this step.

**ISO check:** the existing installation ISO at `/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO` is readable. It remains in place and was not copied or modified.

**Storage:** `df -h /home` reported 939 GiB total, 433 GiB used, 507 GiB available, 47% used. This is point-in-time capacity evidence.

**Resilience decision:** durable guest state will reside under `/home/deck/WindowsVM/storage`, outside the container writable layer and away from SteamOS-managed system paths. Deployment configuration will be stored separately under `config/`. The container will be treated as replaceable; image upgrades will be deliberate and digest-pinned. Manual lifecycle remains the default. Backup/restore and post-SteamOS-update recovery must be documented and tested before claiming resilience is proven.

### 2026-11-12 — Selected ISO verified; UUP version difference explained

**Selected ISO:** `/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO`.

- Size: 4,335,187,968 bytes (approximately 4.1 GiB).
- SHA-256: `3a65289ef20c85e6ea64778e360ef50acc88451cc864778b1df1eb55270545f9`.
- `file` output: bootable ISO 9660 filesystem, volume label `26100.1_X64_EN-US`.
- `7z l` confirms `setup.exe`, `sources/boot.wim` and `sources/install.wim`.
- The initial inspection command failed only because it omitted `.1` from the actual filename; the correct file existed and was subsequently inspected successfully.

**Important UUP finding (settled, not an open question):** the directory/source selection `26200.9974_pro` does not mean the Linux-generated ISO contains build `26200.9974`. The Linux UUP conversion script does not integrate the selected update packages. The ISO therefore contains the base `26100.1` image. `AddUpdates=1` in `ConvertConfig.ini` does not override this Linux converter limitation. The UUP set has the base image and separate update packages; integrating them requires the Windows conversion workflow.

This also explains why the base ISO is not a matching repair source for the Dell M4800's installed Windows 11 Pro `26200.9818` and why the previous DISM repair attempt returned `0x800f0915`. The ISO is retained as Windows VM installation media, not represented as an updated ISO or a suitable matching repair source.

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

**Status:** host, rootless Podman device access and QEMU/KVM acceleration validated. Windows VM deployment and installation-media verification remain pending.

## 9. Next steps

The ISO path and checksum are now verified, and its bootable ISO structure and key setup files are confirmed. The expected Linux-conversion version difference is understood: this ISO contains the base `26100.1` image, not the selected `26200.9974` update level. Do not spend further time trying to make the Linux conversion output contain integrated updates. The purpose of the Windows VM is to run the Windows UUP conversion workflow that can integrate those update packages. The next media check, if needed for selecting the guest edition, is to inspect the `install.wim` image indexes and edition metadata; it is not to investigate the already-explained base/update version difference.

Then inspect the selected image's documented environment variables, volume layout, device requirements and startup behaviour. Design the `windows-box` Podman command with persistent storage under `/home/deck`, local ISO mounted read-only as `/custom.iso`, KVM and TUN access, manual lifecycle and a conservative resource allocation. Confirm the exact configuration before creating persistent VM storage or starting installation.

1. (Completed) Verify the selected ISO path, SHA-256, bootable ISO structure and key setup files. Inspect WIM indexes/edition metadata only if needed to confirm the Pro install index.
2. Confirm the image's current supported configuration and persistent data directory.
3. Choose and document the VM storage path and disk capacity.
4. Prepare the exact Podman create/run configuration, including network and console access.
5. Create the persistent VM storage and start installation after reviewing the final plan.
6. Verify Windows setup, guest boot, networking, activation status and installed build.
7. Tune memory, CPU and display/remote access based on observed performance.

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
| 2026-11-12 | `windows-box` container deployment | PENDING | Configuration is ready for review; container not created |
| 2026-11-12 | Windows guest creation | PENDING | No VM disk or guest created |

---

*Living project document. Update after each completed inspection, decision, installation or verification. Record only evidence actually supplied or observed; do not promote proposals to verified state.*

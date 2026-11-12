# Windows VM Installation Guide — Steam Deck OLED

A living installation guide and evidence log for evaluating a Windows virtual machine on the Steam Deck OLED (SteamOS).

> **Current phase: host/container KVM validation passed; deployment design and ISO verification are next. No Windows guest or persistent VM disk has been created.**

## 1. Objective

Create a manually managed Windows virtual machine on the Steam Deck OLED, primarily to run Windows-only UUP conversion tooling.

The immediate downstream task is to produce a Windows 11 ISO with the selected updates integrated. The UUP Dump documentation supplied during the KB5132061 investigation states that Linux/macOS conversion scripts do not support installing updates during conversion; Windows conversion is required for that workflow.

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

The initial deployment proposal is 4 vCPUs, 6 GiB RAM and a 128 GiB virtual disk, subject to the image's supported disk allocation behaviour and final configuration review. These values are not yet an active VM configuration.

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

## 7. Journey log

### 2026-11-12 — KVM and selected container validated

**Host preflight:** AMD-V reported; `svm` CPU flag present; `kvm_amd` and `kvm` modules loaded; `/dev/kvm` present as `10:232`, mode `0666`, readable and writable by `deck`. `/dev/net/tun` also present with mode `0666`. Rootless Podman 6.0.2 confirmed. `free -h` reported 14 GiB total and 9.8 GiB available; `/home` reported 507 GiB free.

**Rootless device test:** a temporary Ubuntu 24.04 container was launched with `--device=/dev/kvm`. The device appeared inside the container as `nobody:nogroup`, character device major 10/minor 232, and both read and write checks passed. Container exit status was 0. No host permission changes were made.

**Selected image:** `docker.io/dockurr/windows:latest` downloaded successfully. Reported image ID/config digest: `cbfaef1f04b4cb08137512116a64ed2005b58852bf04067b3f896342d5b3cb02`; image manifest digest: `sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc`.

**QEMU/KVM test:** image contains `/usr/bin/qemu-system-x86_64`, QEMU emulator version `11.1.1 (qemu-windows 11.2.23)`. `qemu-system-x86_64 -accel help` listed KVM. A minimal Q35 VM with `accel=kvm`, `-cpu host`, 256 MiB RAM, no devices/display and paused execution started successfully. Output: `KVM acceleration: SUCCESS`; the temporary QEMU process was terminated by the test cleanup. This confirms QEMU can initialise KVM inside the selected rootless Podman container.

**Architecture decision:** proceed with `dockurr/windows` in rootless Podman, named `windows-box`. Do not create a Distrobox for this VM. Keep manual lifecycle and persistent guest data separate from the container layer. This decision is based on the successful KVM test, not a blanket preference for containers.

**Installation ISO discovery:** three ISO files were reported by the initial `find` output. The intended Pro source directory is `/home/deck/uup-box/26200.9974_pro/`. A subsequent inspection command used the wrong filename (`26100.1_PROFESSIONAL_X64_EN-US.ISO`) and failed with `No such file or directory`. The directory listing showed the actual file as `26100.1.1_PROFESSIONAL_X64_EN-US.ISO` (about 4.1 GiB). The ISO itself has not yet been inspected or checksummed. Do not claim its installed build is 26200.9974: the UUP conversion history indicates Linux conversion did not integrate updates, and the ISO filename/metadata needs verification.

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

## 8. Next steps

The next action is to inspect the actual ISO using its corrected filename, calculate its SHA-256 checksum and inspect the Windows image metadata with the available `7z` tooling. Confirm the exact Windows edition and build contained in the ISO; do not infer the integrated update level from the UUP directory name.

Then inspect the selected image's documented environment variables, volume layout, device requirements and startup behaviour. Design the `windows-box` Podman command with persistent storage under `/home/deck`, local ISO mounted read-only as `/custom.iso`, KVM and TUN access, manual lifecycle and a conservative resource allocation. Confirm the exact configuration before creating persistent VM storage or starting installation.

1. Verify the ISO path, checksum, contents, edition and actual build.
2. Confirm the image's current supported configuration and persistent data directory.
3. Choose and document the VM storage path and disk capacity.
4. Prepare the exact Podman create/run configuration, including network and console access.
5. Create the persistent VM storage and start installation after reviewing the final plan.
6. Verify Windows setup, guest boot, networking, activation status and installed build.
7. Tune memory, CPU and display/remote access based on observed performance.

## 9. Change and evidence register

| Date | Item | Status | Notes |
|---|---|---|---|
| 2026-11-12 | AMD-V and KVM host availability | VERIFIED | AMD-V, KVM modules, `/dev/kvm` and device permissions confirmed from supplied output |
| 2026-11-12 | Rootless Podman KVM device passthrough | VERIFIED | Temporary Ubuntu container accessed `/dev/kvm` read/write; exit 0 |
| 2026-11-12 | `dockurr/windows` image download | VERIFIED | Manifest digest recorded in journey log |
| 2026-11-12 | QEMU/KVM acceleration inside selected image | VERIFIED | Minimal Q35 test VM started with `accel=kvm` |
| 2026-11-12 | Architecture | SELECTED | Rootless Podman + `dockurr/windows`; no Distrobox required |
| 2026-11-12 | Windows ISO path | CORRECTED / PENDING VERIFICATION | Actual filename is `26100.1.1_PROFESSIONAL_X64_EN-US.ISO`; checksum and image metadata not yet checked |
| 2026-11-12 | `windows-box` persistent deployment | PENDING | No persistent VM data directory/container created |
| 2026-11-12 | Windows guest creation | PENDING | No VM disk or guest created |

---

*Living project document. Update after each completed inspection, decision, installation or verification. Record only evidence actually supplied or observed; do not promote proposals to verified state.*

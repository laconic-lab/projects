# Windows VM Installation Guide — Steam Deck OLED

A living installation guide and evidence log for evaluating a Windows virtual machine on the Steam Deck OLED (SteamOS).

> **Current phase: read-only preflight and architecture selection. No VM has been installed or created.**

## 1. Objective

Create a manually managed Windows virtual machine on the Steam Deck OLED, primarily to run Windows-only UUP conversion tooling.

The immediate downstream task is to produce a Windows 11 ISO with the selected updates integrated. The UUP Dump documentation supplied during the KB5132061 investigation states that Linux/macOS conversion scripts do not support installing updates during conversion; Windows conversion is required for that workflow.

The Windows VM is intended as a temporary/controlled tool environment for this conversion task unless a broader purpose is explicitly agreed later.

## 2. Scope and boundaries

### In scope

- Assessing whether the Deck can host a hardware-accelerated VM.
- Selecting and documenting the QEMU/KVM execution architecture.
- Evaluating a dedicated Distrobox named `windows-box` for VM tooling.
- Creating a Windows guest named `windows-vm`, only after architecture, storage, installation media and rollback are reviewed and approved.
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
| `windows-box` | Proposed Distrobox userspace for QEMU/KVM tools and supporting utilities | PENDING creation |
| `windows-vm` | Proposed Windows guest VM | PENDING creation |
| QEMU | Virtual machine process/emulator; with KVM acceleration it can use the Linux kernel's hardware virtualisation interface | Not installed in the earlier inventory |
| KVM | Linux kernel virtualisation facility exposed through `/dev/kvm` | Device present and accessible in reported host check |
| OVMF | UEFI firmware implementation commonly used by QEMU guests | Not installed in the earlier inventory |
| swtpm | Software TPM emulator, potentially needed for a Windows 11 virtual TPM device | Not installed in the earlier inventory |
| libvirt / virt-manager | Optional VM management service and graphical management application | Not installed in the earlier inventory |

QEMU is the virtual-machine engine. KVM is the Linux kernel facility that can accelerate virtualisation. A Windows guest is a separate operating system running inside a virtual hardware definition; it does not replace SteamOS.

The proposed initial guest sizing, subject to later review, is 4 vCPUs, 6 GiB RAM and a 100 GiB dynamically allocated virtual disk. These are planning values, not an approved or created VM configuration.

## 4. Repository and platform rules

This project follows:

- [Repository README](../../README.md)
- [Engineering & Security Baseline](../../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md)
- [Project Documentation Standard](../../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md)

Key requirements:

1. Identify the execution context for every command: SteamOS host, `windows-box`, Windows guest, or a client workstation.
2. Start with targeted read-only inspection.
3. Do not repeat completed checks without a reason.
4. Do not treat Distrobox as a strong security sandbox. Inspect its actual mounts, identity mappings, capabilities, devices and network configuration.
5. Preserve existing environments and persistent data.
6. Manual lifecycle by default.
7. Obtain explicit approval before installing packages, changing host configuration, enabling services, creating persistent VM storage or taking destructive action.
8. Never put credentials, activation keys, private keys or secret-bearing files in Git or diagnostic output.

## 5. Hardware and host preflight

### 5.1 Hardware virtualisation

<badge color="success">REPORTED — PASS</badge>

The user supplied the following read-only host inventory:

| Check | Reported result |
|---|---|
| CPU architecture | x86_64 |
| CPU model | AMD Custom APU 0932 |
| Logical CPUs | 8 |
| Hardware virtualisation | AMD-V |
| KVM device | `/dev/kvm` present |
| KVM device permissions | `crw-rw-rw-`, mode `666`, owner `root:kvm` |
| User | `deck`, UID 1000 |
| Podman | 6.0.2 |
| Distrobox environments | `pihole-box`, `Stable-box`, `localai-box`, `uup-box` |

Earlier hardware inventory also reported 14 GiB total memory and approximately 507 GiB free on `/home`. These figures are historical observations from the preflight and must be rechecked before allocating VM resources or creating a disk.

**Interpretation:** the host exposes the KVM device and the reported device mode permits access by the current user. This is a strong feasibility indicator, but it does not yet prove that a process inside a new Distrobox can use KVM successfully.

### 5.2 Existing environments

The reported Distrobox inventory:

| Environment | Image | Reported state |
|---|---|---|
| `pihole-box` | `archlinux:latest` | Exited |
| `Stable-box` | `ubuntu:24.04` | Exited |
| `localai-box` | `ubuntu:24.04` | Exited |
| `uup-box` | `archlinux:latest` | Up |

No existing environment is to be reused for this project. In particular, the currently running `uup-box` must remain untouched.

The supplied directory check showed `/home/deck/OdysseusRecovery` and `/home/deck/pihole-box`; it did not show a `windows-box` directory. This does not establish the absence of every possible VM storage location, which will be checked before any creation step.

### 5.3 Virtualisation software inventory

The earlier read-only inventory reported:

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

<badge color="warning">PROPOSED — NOT VALIDATED</badge>

The current candidate is:

```text
Steam Deck OLED / SteamOS host
  |
  |-- existing KVM device: /dev/kvm
  |
  |-- Distrobox: windows-box (proposed)
        |
        |-- QEMU tooling (candidate)
        |
        |-- Windows guest: windows-vm (proposed)
              |
              |-- virtual CPU / RAM / disk
              |-- UEFI firmware
              |-- virtual TPM 2.0, if required
              |-- NAT networking
```

This arrangement may keep most userspace dependencies in a dedicated environment, but Distrobox is integrated with the host and is not a security boundary. QEMU's access to `/dev/kvm`, firmware files, virtual TPM, graphical display, networking and persistent disk paths must all be tested and documented.

We have not yet decided whether QEMU should run inside `windows-box` or directly on the SteamOS host. The container approach is a candidate, not a commitment. The decision must be based on the least invasive reliable setup and the repository's host-stability rules.

### Candidate guest configuration

| Setting | Initial planning value | Status |
|---|---:|---|
| vCPU | 4 | Proposed |
| RAM | 6 GiB | Proposed |
| Disk | 100 GiB, dynamically allocated | Proposed |
| Firmware | UEFI / OVMF | Proposed |
| TPM | TPM 2.0 virtual device | Proposed |
| Network | NAT | Proposed |
| GPU passthrough | Not planned | Not required for UUP conversion |
| Lifecycle | Manual start/stop | Required default |

These values must be checked against current host memory, disk capacity, Windows requirements and the selected VM implementation before creation.

## 7. Journey log

### 2026-11-12 — Project initiated

**Purpose:** establish a Windows VM project to support Windows-only UUP update integration without repeating the failed conversion attempt on the Dell M4800.

**Evidence reviewed:**

- Repository root README.
- Shared Engineering & Security Baseline.
- Project Documentation Standard.
- User-supplied Steam Deck hardware, Distrobox, Podman and KVM inventory.

**Findings:**

- AMD-V was reported available.
- `/dev/kvm` was reported present with mode `666`.
- Podman 6.0.2 is installed.
- Existing Distroboxes are present; `uup-box` is currently running and is explicitly excluded from reuse.
- QEMU/libvirt/OVMF/swtpm tools were absent in the earlier package inventory.
- No `windows-box` has been created.
- No VM has been created and no project-related host changes have been made.

**Decision:** use `windows-box` as the proposed dedicated Distrobox name and `windows-vm` as the proposed Windows guest name. Keep the VM manually managed.

**Status:** initial preflight evidence recorded; architecture remains pending validation.

## 8. Next steps

The next action is a focused, read-only inspection of the existing Distrobox/Podman configuration and the host display/session environment. It should establish whether a new Distrobox can access KVM and whether QEMU can display a guest window in the existing Deck desktop session without privileged mode or broad new host exposure.

Do not create `windows-box`, install QEMU, install host packages, create VM storage or change permissions until the inspection results have been reviewed and a specific implementation plan is approved.

After that inspection:

1. Decide whether QEMU belongs inside `windows-box` or on the host.
2. Identify the minimum packages and exact installation transaction.
3. Review the container's effective mounts, user mappings, capabilities, device access, network and GUI path.
4. Define the VM storage path, capacity, backup and rollback plan.
5. Obtain approval before creating the environment or installing anything.
6. Create and verify the VM in small, documented stages.

## 9. Change and evidence register

| Date | Item | Status | Notes |
|---|---|---|---|
| 2026-11-12 | AMD-V and KVM host availability | REPORTED | User supplied read-only inventory |
| 2026-11-12 | Existing Distrobox inventory | REPORTED | `uup-box` remains separate and untouched |
| 2026-11-12 | QEMU/libvirt package inventory | REPORTED | Components absent in earlier inventory |
| 2026-11-12 | `windows-box` creation | PENDING | No environment created |
| 2026-11-12 | Windows guest creation | PENDING | No VM disk or guest created |
| 2026-11-12 | Architecture validation | PENDING | Container vs host execution not decided |

---

*Living project document. Update after each completed inspection, decision, installation or verification. Record only evidence actually supplied or observed; do not promote proposals to verified state.*

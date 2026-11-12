# Windows on Steam Deck

A project to evaluate and, if feasible, operate a manually managed Windows virtual machine on the Steam Deck OLED running SteamOS.

The immediate goal is to provide a Windows environment capable of running the **Windows-based UUP conversion process** required to produce a correctly updated Windows 11 ISO. That ISO is needed as a repair source for the Dell Precision M4800 currently running Windows 11 Pro build `26200.9818`, before proceeding with the KB5132061 servicing work.

This project is an experiment and installation journey. It is **not yet an installed or working VM**.

## Current status

<badge>PLANNING / READ-ONLY PREFLIGHT</badge>

- Hardware virtualisation support is present: AMD-V was reported by the host inventory.
- `/dev/kvm` exists and was reported accessible to user `deck`.
- QEMU, libvirt, virt-manager, OVMF and swtpm were not installed in the earlier package inventory.
- A dedicated `windows-box` Distrobox does not yet exist.
- No Windows VM disk or guest has been created.
- No host packages, services or configuration have been changed for this project.

See the [installation and project journey guide](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md) for evidence, decisions, pending checks and the next approved step.

## Proposed naming

| Name | Intended role | Status |
|---|---|---|
| `windows-box` | Dedicated Distrobox userspace for evaluating/running the VM tooling | PROPOSED; not created |
| `windows-vm` | Windows guest virtual machine | PROPOSED; not created |

The names are deliberately distinct: `windows-box` is the Linux tool environment; `windows-vm` is the virtual Windows computer. We will not repurpose the existing `uup-box` or modify other project environments.

## Operating principles

- Keep SteamOS host changes to the minimum justified.
- Diagnose first; read-only checks before changes.
- Prefer a project-specific environment, but do not assume Distrobox provides a strong security boundary.
- Inspect actual device access, mounts, identity mappings, capabilities, networking and GUI requirements before approving an architecture.
- Manual startup and shutdown by default; no boot autostart or background service without a separate decision.
- Keep VM disks and project data in a dedicated, documented location.
- Back up and verify before significant changes.
- Obtain explicit approval before package installation, host configuration changes, service changes, or creation/deletion of persistent VM data.
- Record evidence and distinguish VERIFIED, REPORTED, PROPOSED and PENDING states.

These rules follow the repository's [Engineering & Security Baseline](../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) and [Project Documentation Standard](../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md).

## Project documents

- [Windows VM Installation Guide and journey log](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md)

---

*Project: laconic-lab / projects / windows*

# Windows on Steam Deck

A project to evaluate and, if feasible, operate a manually managed Windows virtual machine on the Steam Deck OLED running SteamOS.

The immediate goal is to provide a Windows environment capable of running the **Windows-based UUP conversion process** required to produce a correctly updated Windows 11 ISO. That ISO is needed as a repair source for the Dell Precision M4800 currently running Windows 11 Pro build `26200.9818`, before proceeding with the KB5132061 servicing work.

The existing Linux-generated ISO selected for VM installation is intentionally a base `26100.1` image, despite originating from the `26200.9974_pro` UUP selection. Linux/macOS UUP conversion does not integrate the selected update packages; `AddUpdates=1` does not change that limitation. The VM is being created so the Windows-based conversion workflow can perform that integration. The base ISO is not being treated as a matching repair source for build `26200.9818`.

This project is an experiment and installation journey. It is **not yet an installed or working VM**.

## Current status

**Status: KVM VALIDATED / DEPLOYMENT PLANNING**

- AMD-V is present; `kvm_amd` and `kvm` are loaded.
- `/dev/kvm` is readable and writable by `deck` on the host.
- Rootless Podman successfully passed `/dev/kvm` into a temporary container.
- QEMU inside `dockurr/windows` successfully started a minimal KVM-accelerated VM.
- The `dockurr/windows` image is downloaded; no Windows guest or persistent VM disk has been created.
- No host packages, services, permissions or configuration have been changed for this project.

The selected ISO's SHA-256 and contents have now been verified; its base-build status and the Linux UUP conversion limitation are documented in the [installation and project journey guide](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md). See that guide for the evidence, decisions and next steps.

## Proposed naming

| Name | Intended role | Status |
|---|---|---|
| `windows-box` | Dedicated rootless Podman container running `dockurr/windows` | Selected; image downloaded; no persistent VM deployed |
| `windows-vm` | Windows guest virtual machine | PROPOSED; not created |

The names are deliberately distinct: `windows-box` is the Podman container hosting QEMU; `windows-vm` is the virtual Windows computer. We will not repurpose the existing `uup-box` or modify other project environments.

## Operating principles

- Keep SteamOS host changes to the minimum justified.
- Diagnose first; read-only checks before changes.
- Use the selected Podman/QEMU/KVM architecture because its KVM execution path has been tested; do not create an unnecessary Distrobox.
- Inspect actual device access, mounts, identity mappings, capabilities, networking and GUI requirements before approving an architecture.
- Manual startup and shutdown by default; no boot autostart or background service without a separate decision.
- Keep VM disks and project data in a dedicated, documented location.
- Back up and verify before significant changes.
- Obtain explicit approval before package installation, host configuration changes, service changes, or creation/deletion of persistent VM data.
- Record evidence and distinguish VERIFIED, REPORTED, PROPOSED and PENDING states.

These rules follow the repository's [Engineering & Security Baseline](../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) and [Project Documentation Standard](../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md).

## Project documents

- [Windows VM Installation Guide and journey log](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md)

The guide records the verified host/container/KVM tests, selected image digest, architecture decision and corrected ISO filename.

---

*Project: laconic-lab / projects / windows*

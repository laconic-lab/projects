# Windows on Steam Deck

A project to evaluate and, if feasible, operate a manually managed Windows virtual machine on the Steam Deck OLED running SteamOS.

The immediate goal is to provide a Windows environment capable of running the **Windows-based UUP conversion process** required to produce a correctly updated Windows 11 ISO. That ISO is needed as a repair source for the Dell Precision M4800 currently running Windows 11 Pro build `26200.9818`, before proceeding with the KB5132061 servicing work.

The existing Linux-generated ISO selected for VM installation is intentionally a base `26100.1` image, despite originating from the `26200.9974_pro` UUP selection. Linux/macOS UUP conversion does not integrate the selected update packages; `AddUpdates=1` does not change that limitation. The VM is being created so the Windows-based conversion workflow can perform that integration. The base ISO is not being treated as a matching repair source for build `26200.9818`.

This project is an experiment and installation journey. It is **not yet an installed or working VM**.

## Current status

**Status: KVM VALIDATED / PERSISTENT PROJECT DIRECTORY CREATED / CONTAINER DEPLOYMENT PENDING**

- AMD-V is present; `kvm_amd` and `kvm` are loaded.
- `/dev/kvm` is readable and writable by `deck` on the host.
- Rootless Podman successfully passed `/dev/kvm` into a temporary container.
- QEMU inside `dockurr/windows` successfully started a minimal KVM-accelerated VM.
- The `dockurr/windows` image is downloaded and its entrypoint, defaults, `/storage` volume and exposed ports have been inspected.
- `/home/deck/WindowsVM` and its `config/`, `storage/`, `shared/`, `backups/` and `docs/` directories have been created and verified as `deck:deck`, mode `0700`.
- The selected ISO remains readable at its original `uup-box` path; it has not been copied or modified.
- `/home` had 507 GiB available at the time of the latest check.
- No Windows guest disk or guest OS has been created.
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
- Keep VM disks and project data in `/home/deck/WindowsVM`, outside the container writable layer and SteamOS-managed system directories.
- Treat the container as replaceable; preserve the guest under the host-backed `/storage` mount and keep deployment configuration independently reproducible.
- Pin the tested image digest for recreation and update it deliberately; do not silently follow a moving `latest` tag.
- Test backup/restore and post-SteamOS-update recovery before claiming resilience is proven.
- Back up and verify before significant changes.
- Obtain explicit approval before package installation, host configuration changes, service changes, or creation/deletion of persistent VM data.
- Record evidence and distinguish VERIFIED, REPORTED, PROPOSED and PENDING states.

These rules follow the repository's [Engineering & Security Baseline](../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) and [Project Documentation Standard](../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md).

## Project documents

- [Windows VM Installation Guide and journey log](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md)

The guide records the verified host/container/KVM tests, selected image identity, image configuration, ISO evidence, persistent directory creation and the resilience design.

---

*Project: laconic-lab / projects / windows*

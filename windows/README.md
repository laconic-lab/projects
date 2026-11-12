# Windows on Steam Deck

A project to evaluate and, if feasible, operate a manually managed Windows virtual machine on the Steam Deck OLED running SteamOS.

The immediate goal is to provide a Windows environment capable of running the **Windows-based UUP conversion process** required to produce a correctly updated Windows 11 ISO. That ISO is needed as a repair source for the Dell Precision M4800 currently running Windows 11 Pro build `26200.9818`, before proceeding with the KB5132061 servicing work.

The existing Linux-generated ISO selected for VM installation is intentionally a base `26100.1` image, despite originating from the `26200.9974_pro` UUP selection. Linux/macOS UUP conversion does not integrate the selected update packages; `AddUpdates=1` does not change that limitation. The VM is being created so the Windows-based conversion workflow can perform that integration. The base ISO is not being treated as a matching repair source for build `26200.9818`.

The Windows 11 Pro guest installation is user-confirmed complete. Local noVNC works. The selected LAN endpoint is http://192.168.1.161:8006/ for PC client 192.168.1.169; the current container remains loopback-bound until its publication is changed and the container is recreated.

## Current status

**Status: WINDOWS 11 PRO 24H2 INSTALLED / LOCAL CONSOLE VERIFIED / MANUAL LIFECYCLE CONFIGURED / LAN CONSOLE TARGET SELECTED (APPLICATION PENDING)**

- AMD-V is present; `kvm_amd` and `kvm` are loaded.
- `/dev/kvm` is readable and writable by `deck` on the host.
- Rootless Podman successfully passed `/dev/kvm` into a temporary container.
- QEMU inside `dockurr/windows` successfully started a minimal KVM-accelerated VM, and the deployed guest QEMU process is running with KVM acceleration.
- The `dockurr/windows` image is downloaded and its entrypoint, defaults, `/storage` volume and exposed ports have been inspected.
- `/home/deck/WindowsVM` and its `config/`, `storage/`, `shared/`, `backups/` and `docs/` directories have been created and verified as `deck:deck`, mode `0700`.
- The protected environment file and three manual lifecycle scripts have been created; the environment file is mode `0600`, scripts are mode `0700`, and all scripts pass `bash -n`.
- Prepared settings: 4 vCPUs, 6 GiB RAM, 128 GiB raw virtual disk target (no preallocation), user-mode networking, loopback-only web viewer on port 8006, pinned image digest and persistent `/storage` bind mount. The secret remains local and is not recorded in Git.
- The selected ISO remains readable at its original `uup-box` path and is mounted read-only by the running VM.
- `windows-box` is running with the pinned image digest and `--restart=no`.
- Runtime inspection confirms `/dev/kvm`, persistent `/storage`, read-only `/custom.iso`, and `/shared` mounts.
- QEMU is running with 4 vCPUs and 6 GiB RAM; logs detected Windows 11 Pro and reported successful guest startup.
- The growable raw guest disk `storage/data.img` has a logical capacity of 128 GiB; `du` reported 898 MiB for the storage directory at the time of inspection.
- Local noVNC console access at `http://127.0.0.1:8006/` was confirmed by the user on the Steam Deck.
- User reports Windows 11 Pro 24H2, build `26100`, local account `DeckVM`, hostname `windows-vm`, IPv4 `192.168.1.161`, DNS `192.168.1.1`, and Windows Update paused until 2026-12-28.
- The reported guest IPv4 matches the Deck host IPv4; this is recorded as guest-reported network information, not proof that the guest has an independent LAN address. The configured `NETWORK=user`/`passt` mode remains in effect.
- Selected PC-client endpoint: http://192.168.1.161:8006/ from 192.168.1.169. Runtime is still loopback-bound pending the start-script update and container recreation.
- `/home` had 507 GiB available at the time of the latest check.
- Windows installation completion and local console access are user-confirmed. Windows activation, guest network reachability, shared-folder workflow and PC-client console access remain unverified.
- No host packages, services, permissions or configuration have been changed for this project.

The selected ISO's SHA-256 and contents have now been verified; its base-build status and the Linux UUP conversion limitation are documented in the [installation and project journey guide](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md). See that guide for the evidence, decisions and next steps.

## Proposed naming

| Name | Intended role | Status |
|---|---|---|
| `windows-box` | Dedicated rootless Podman container running `dockurr/windows` | Running; QEMU/KVM startup verified |
| `windows-vm` | Windows guest virtual machine | Windows 11 Pro 24H2 build 26100 installed; user-confirmed running |

The names are deliberately distinct: `windows-box` is the Podman container hosting QEMU; `windows-vm` is the virtual Windows computer. We will not repurpose the existing `uup-box` or modify other project environments.

## Operating principles

- Keep SteamOS host changes to the minimum justified.
- Diagnose first; read-only checks before changes.
- Use the selected Podman/QEMU/KVM architecture because its KVM execution path has been tested; do not create an unnecessary Distrobox.
- Inspect actual device access, mounts, identity mappings, capabilities, networking and GUI requirements before approving an architecture.
- Manual startup and shutdown; no boot autostart or background service. Use the project start, stop and status scripts.
- Keep VM disks and project data in `/home/deck/WindowsVM`, outside the container writable layer and SteamOS-managed system directories.
- Treat the container as replaceable; preserve the guest under the host-backed `/storage` mount and keep deployment configuration independently reproducible.
- Pin the tested image digest for recreation and update it deliberately; do not silently follow a moving `latest` tag.
- Backup/restore and post-SteamOS-update recovery are future work. No backup is authorized or planned in the current installation-finalization phase.
- Back up and verify before significant changes.
- Obtain explicit approval before package installation, host configuration changes, service changes, or creation/deletion of persistent VM data.
- Record evidence and distinguish VERIFIED, REPORTED, PROPOSED and PENDING states.

These rules follow the repository's [Engineering & Security Baseline](../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) and [Project Documentation Standard](../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md).

## Project documents

- [Windows VM Installation Guide and journey log](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md)
- [Windows VM Console and Second-VM Deployment Guide](./docs/WINDOWS-VM-CONSOLE-AND-SECOND-VM-GUIDE.md)

The installation guide records the verified host/container/KVM tests, selected image identity, ISO evidence, persistent directory and deployment configuration. The console guide explains the Podman/Dockur/QEMU/KVM relationship, how to inventory multiple Windows VM containers, noVNC operation, host-side resource settings, unattended installation variables, second-VM deployment and clean removal.

---

*Project: laconic-lab / projects / windows*

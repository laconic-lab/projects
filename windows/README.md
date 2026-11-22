# Windows on Steam Deck

A project to evaluate and, if feasible, operate a manually managed Windows virtual machine on the Steam Deck OLED running SteamOS.

The immediate goal is to provide a Windows environment capable of running the **Windows-based UUP conversion process** required to produce a correctly updated Windows 11 ISO. That ISO is needed as a repair source for the Dell Precision M4800 currently running Windows 11 Pro build `26200.9818`, before proceeding with the KB5132061 servicing work.

The existing Linux-generated ISO selected for VM installation is intentionally a base `26100.1` image, despite originating from the `26200.9974_pro` UUP selection. Linux/macOS UUP conversion does not integrate the selected update packages; `AddUpdates=1` does not change that limitation. The VM is being created so the Windows-based conversion workflow can perform that integration. The base ISO is not being treated as a matching repair source for build `26200.9818`.

The Windows 11 Pro guest installation is user-confirmed complete. LAN noVNC access is verified at http://192.168.1.161:8006/ from PC client 192.168.1.169. The host loopback endpoint 127.0.0.1:8006 is intentionally not bound; the user accepts the LAN endpoint.


## Architecture overview

The Windows workload runs on the Steam Deck. The LAN PC is a remote client for the web console and RDP; it does not host the VM.

```text
                 LOCAL NETWORK (LAN)
        +----------------------------------+
        |                                  |
        |       Linux / Windows PC         |
        |       remote workstation         |
        |                                  |
        |  - Browser: Web Console          |
        |  - Remote Desktop (RDP)           |
        |  - SSH / project administration  |
        +----------------+-----------------+
                         |
              LAN access to the Deck
              Web Console: :8006
              RDP: guest access (verified)
                         |
        +----------------v-----------------+
        |          STEAM DECK OLED         |
        |              SteamOS             |
        |                                  |
        |  HOST                            |
        |  - hardware, kernel and network  |
        |  - /dev/kvm                      |
        |  - rootless Podman               |
        |                                  |
        |  +----------------------------+  |
        |  | windows-pro-box            |  |
        |  | dockurr/windows container  |  |
        |  |                            |  |
        |  |  QEMU + KVM acceleration   |  |
        |  |            |               |  |
        |  |  +---------v------------+  |  |
        |  |  | Windows 11 Pro       |  |  |
        |  |  | 25H2 guest           |  |  |
        |  |  |                      |  |  |
        |  |  | - Windows workloads  |  |  |
        |  |  | - Web console agent  |  |  |
        |  |  | - RDP service        |  |  |
        |  |  +----------------------+  |  |
        |  |                            |  |
        |  |  Mounts:                   |  |
        |  |  /storage -> persistent    |  |
        |  |  /shared  -> host shared   |  |
        |  |  NO /custom.iso            |  |
        |  +----------------------------+  |
        |                |                 |
        |       /home/deck/WindowsVM       |
        |       - storage/ (guest disk)   |
        |       - shared/  (exchange)    |
        |       - config/ and scripts    |
        +----------------------------------+
```

The diagram represents the current runtime model, not every historical deployment state. The normal runtime container must remain ISO-free: installation media belongs only in a separately identified temporary installer container. The guest disk and shared data persist on the host under `/home/deck/WindowsVM`; the container is replaceable.


## Current status

**Status (2026-11-15): WINDOWS 11 PRO 25H2 GUEST RUNNING / WEB CONSOLE VERIFIED / RDP VERIFIED / NO ISO BIND VERIFIED**

The current `windows-pro-box` guest reports Windows 11 Pro 25H2, build `26200.9974`. The user confirms both Web Console and RDP access. Its normal runtime container has exactly the project `storage/ -> /storage` and `shared/ -> /shared` mounts, no `/custom.iso`, and the expected host port bindings.

> **TOP PRIORITY — NO ISO BIND:** Installation media is permitted only in a separately identified temporary installer container. A normal runtime container and its start script must never define or mount `/custom.iso`. If a completed VM is accidentally ISO-bound, do not troubleshoot or retry it: follow [Installation Guide Section 0.2](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md#02-standard-correction-procedure--accidental-iso-bound-runtime-container). Preserve guest storage; replace only the stopped container object after clean guest shutdown and exclusive-storage verification.


**Historical snapshot notice:** the following inventory bullets and the older `windows-box` naming/status describe the original 2026-11-13 deployment. They are retained as project history; they are not the current `windows-pro-box` runtime status above.

The existing guest is not to be removed yet. Preparation work includes Windows-based UUP conversion of a current Windows 11 25H2 image, comparison with released 26H2 versus 26H2 Experimental, review of offline servicing and setup customization, and analysis of the disposable I/O/SSD lab. RDP publication is deliberately deferred.

- AMD-V is present; `kvm_amd` and `kvm` are loaded.
- `/dev/kvm` is readable and writable by `deck` on the host.
- Rootless Podman successfully passed `/dev/kvm` into a temporary container.
- QEMU inside `dockurr/windows` successfully started a minimal KVM-accelerated VM, and the deployed guest QEMU process is running with KVM acceleration.
- The `dockurr/windows` image is downloaded and its entrypoint, defaults, `/storage` volume and exposed ports have been inspected.
- `/home/deck/WindowsVM` and its `config/`, `storage/`, `shared/` and `docs/` directories have been created and verified as `deck:deck`, mode `0700`.
- The protected environment file and three manual lifecycle scripts have been created; the environment file is mode `0600`, scripts are mode `0700`, and all scripts pass `bash -n`.
- Existing guest configuration: 4 vCPUs, 6 GiB RAM, 128 GiB raw virtual disk target (no preallocation), user-mode networking, LAN-bound web viewer at 192.168.1.161:8006, pinned image digest and persistent `/storage` bind mount. The secret remains local and is not recorded in Git.
- Historical original `windows-box` installer configuration: the selected ISO was mounted read-only at `/custom.iso` during installation. That mount is not permitted in any normal runtime container.
- `windows-box` is running with the pinned image digest and `--restart=no`.
- Historical original `windows-box` runtime inspection included `/custom.iso`; this was corrected by replacing its container object. Normal runtime must now be ISO-free.
- QEMU is running with 4 vCPUs and 6 GiB RAM; logs detected Windows 11 Pro and reported successful guest startup.
- The growable raw guest disk `storage/data.img` has a logical capacity of 128 GiB; `du` reported 898 MiB for the storage directory at the time of inspection.
- Local noVNC console access at `http://127.0.0.1:8006/` was confirmed by the user on the Steam Deck.
- User reports Windows 11 Pro 24H2, build `26100`, local account `DeckVM`, hostname `windows-vm`, IPv4 `192.168.1.161`, DNS `192.168.1.1`, and Windows Update paused until 2026-12-28.
- The reported guest IPv4 matches the Deck host IPv4; this is recorded as guest-reported network information, not proof that the guest has an independent LAN address. The configured `NETWORK=user`/`passt` mode remains in effect.
- LAN noVNC publication is verified at `192.168.1.161:8006`; the user successfully opened the same guest desktop from Brave and Chrome on PC client `192.168.1.169` simultaneously. Loopback `127.0.0.1:8006` is intentionally not bound.
- `/home` had 507 GiB available at the time of the latest check.
- Original `windows-box` guest and noVNC history is retained above. Current `windows-pro-box` status is Windows 11 Pro 25H2 build `26200.9974`, Web Console verified, RDP verified, and NO ISO BIND verified (2026-11-15).
- No host packages, services, permissions or configuration have been changed for this project.

The selected ISO's SHA-256 and contents have now been verified; its base-build status and the Linux UUP conversion limitation are documented in the [installation and project journey guide](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md). See that guide for the evidence, decisions and next steps.

## Proposed naming

| Name | Intended role | Status |
|---|---|---|
| `windows-box` | Dedicated rootless Podman container running `dockurr/windows` | Running; QEMU/KVM startup verified |
| `windows-vm` | Windows guest virtual machine | Windows 11 Pro 24H2 build 26100 installed; user-confirmed running |

The names are deliberately distinct: `windows-box` is the Podman container hosting QEMU; `windows-vm` is the virtual Windows computer. We will not repurpose the existing `uup-box` or modify other project environments.

- **NO ISO BIND in normal runtime:** every Windows VM runtime container must have only its project-specific `/storage` and `/shared` mounts; never `/custom.iso`. Apply the documented container-object replacement procedure if this rule is violated.

## Operating principles

- Keep SteamOS host changes to the minimum justified.
- Diagnose first; read-only checks before changes.
- Use the selected Podman/QEMU/KVM architecture because its KVM execution path has been tested; do not create an unnecessary Distrobox.
- Inspect actual device access, mounts, identity mappings, capabilities, networking and GUI requirements before approving an architecture.
- Manual startup and shutdown; no boot autostart or background service. Use the project start, stop and status scripts.
- Keep VM disks and project data in `/home/deck/WindowsVM`, outside the container writable layer and SteamOS-managed system directories.
- Treat the container as replaceable; preserve the guest under the host-backed `/storage` mount and keep deployment configuration independently reproducible.
- Pin the tested image digest for recreation and update it deliberately; do not silently follow a moving `latest` tag.
- This is a disposable Windows laboratory. Do not create Windows guest backups, snapshots or virtual-disk copies; if the guest becomes damaged, inspect the failure and prefer a fresh VM when appropriate. Preserve configuration parameters, deployment scripts and verified technical findings in documentation.
- Obtain explicit approval before package installation, host configuration changes, service changes, or creation/deletion of persistent VM data.
- Record evidence and distinguish VERIFIED, REPORTED, PROPOSED and PENDING states.

These rules follow the repository's [Engineering & Security Baseline](../deck/docs/ENGINEERING-AND-SECURITY-BASELINE.md) and [Project Documentation Standard](../deck/docs/PROJECT-DOCUMENTATION-STANDARD.md).

## Project documents

- [Windows VM Installation Guide, Console Operations, Multi-VM Deployment and Roadbook](./docs/WINDOWS-VM-INSTALLATION-GUIDE.md)
- [Disposable VM I/O, RAM-Backed Temporary Storage and SSD Lab](./docs/WINDOWS-VM-DISPOSABLE-IO-AND-SSD-LAB.md)
- [VM Lifecycle and Manual Start/Stop Script Philosophy](./docs/WINDOWS-VM-LIFECYCLE-AND-SCRIPT-PHILOSOPHY.md)
- [Connections and Credential Naming Convention](./docs/WINDOWS-VM-CONNECTIONS-AND-CREDENTIALS.md)
- [Generic per-VM environment template](./templates/windows-vm.env.example)

The consolidated installation guide is the single authoritative source for the verified host/container/KVM tests, ISO evidence and mandatory ISO-free runtime rule, persistent storage, deployment configuration, Podman/Dockur/QEMU/KVM architecture, noVNC operation, host-side resource settings, multi-VM deployment and clean removal. The lifecycle guide explains manual, on-demand VM operation and the start/stop/status responsibilities. The single disposable I/O lab records RAM-disk, pagefile, temporary-folder, TRIM and SSD-wear experiments; proposed tuning remains unimplemented until tested.

---

*Project: laconic-lab / projects / windows*


## Next guest — proposed, not deployed

The current replacement-guest draft is 4 vCPU, 8 GiB RAM (subject to a fresh host-memory safety check), 72 GiB growable raw disk, Windows computer name windeck, en-US display language, fr-FR regional format and French AZERTY keyboard, user-mode networking, and 1920×1080 web display. GPU acceleration is pending host render-node/device-mapping review. The actual Windows account name and generated password must be finalized locally; win-user remains a role label in project documentation.

See the installation guide and environment template. The current guest and its disk remain intact until the pre-recreation gate in the installation guide is satisfied.

# Windows VM Installation Guide — Steam Deck OLED

A living installation guide and evidence log for evaluating a Windows virtual machine on the Steam Deck OLED (SteamOS).

> **Current phase (2026-11-14): the temporary Windows 11 Pro 24H2 guest is running from persistent storage in an ISO-free runtime container; LAN Web Console connectivity is user-confirmed. The initial-install ISO mount has been removed from the normal start definition. The guest is a validation instance, not the intended long-term VM. RDP remains unconfigured. No VM backup or snapshot is in scope.**

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

QEMU is the virtual-machine engine. KVM is the Linux kernel facility that can accelerate virtualisation. A Windows guest is a separate operating system running inside a virtual hardware definition; it does not replace SteamOS. The intended multi-guest model is one independent rootless Podman container created from the Dockur image per Windows guest. Each container runs its own QEMU process and must have its own persistent storage, environment file, container name and host console port. The Dockur image is shared as a reusable image; the running containers and guest disks are separate. See the [Console and Second-VM Deployment Guide](./WINDOWS-VM-CONSOLE-AND-SECOND-VM-GUIDE.md) for the architecture diagram, inventory commands and clean-removal procedures.

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

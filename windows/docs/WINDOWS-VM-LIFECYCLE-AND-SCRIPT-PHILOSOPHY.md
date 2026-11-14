# Windows VM Lifecycle and Manual Start/Stop Script Philosophy

**Platform:** Steam Deck OLED / SteamOS / rootless Podman / Dockur Windows / QEMU/KVM  
**Container:** `windows-box`  
**Guest:** `windows-vm`  
**Status:** Manual lifecycle policy documented; local Windows script source is on the Deck and has not yet been committed for line-by-line repository review  
**Policy:** Manual start and stop only. No boot autostart, unattended startup or automatic restart.

## 1. Purpose

The Windows VM is an on-demand laboratory. The user deliberately starts it when entering the Windows box and stops it when finished. It must not start itself when SteamOS boots or quietly become an always-on service.

The principle is simple: **the user enters the box; the box does not start itself.**

## 2. Keep the lifecycle layers distinct

```text
User manually invokes a SteamOS script
                 |
                 v
        Rootless Podman
                 |
                 v
       Dockur Windows image
                 |
                 v
             QEMU process
                 |
          KVM via /dev/kvm
                 |
                 v
       Windows guest (windows-vm)

Persistent guest state:
  /home/deck/WindowsVM/storage
```

- SteamOS owns the hardware, kernel, host filesystem, network and rootless Podman engine.
- Podman creates and manages the container object.
- Dockur supplies the packaged VM runtime and entrypoint.
- QEMU creates and runs the virtual machine.
- KVM is the Linux kernel hardware-virtualization interface used by QEMU.
- Windows is the guest operating system.
- The guest disk is stored in the host-backed storage mount, not in the container writable layer.

A container is not the Windows guest itself. Removing a container object is different from deleting the host-backed virtual disk.

## 3. Windows lifecycle scripts

The scripts are local Steam Deck files (not committed under `windows/` in this repository):

- `/home/deck/WindowsVM/config/windows-box-start.sh`
- `/home/deck/WindowsVM/config/windows-box-stop.sh`
- `/home/deck/WindowsVM/config/windows-box-status.sh`
- Configuration: `/home/deck/WindowsVM/config/windows-box.env`

The executable scripts are not currently present in the GitHub `windows/` directory. The observations below describe known configuration and runtime behavior, not a verified line-by-line source audit. The user's identity labels are documented in [Connections and Credentials](./WINDOWS-VM-CONNECTIONS-AND-CREDENTIALS.md). Never print the complete environment file because it contains a secret.

### Start

The start script is the deliberate entry point. The known deployment:

- Uses rootless Podman as `deck`, not `sudo`.
- Uses the pinned Dockur image digest.
- Passes `/dev/kvm` to the container.
- Uses `--restart=no`.
- Publishes noVNC on `192.168.1.161:8006`.
- Mounts persistent guest storage at `/storage` and the shared directory at `/shared`. The normal runtime container has no installation ISO mount.
- Reads configuration from the protected environment file.
- Passes shell syntax validation with `bash -n`.

It should not be called by a systemd unit, cron job, shell profile, desktop autostart entry, Podman auto-update hook or other background scheduler.

### Stop

The known stop command requests:

```bash
podman stop --time 120 windows-box
```

This asks Podman to stop the container and allows up to 120 seconds before forced termination. That timeout alone does **not** prove Windows received an ACPI shutdown request or completed a clean guest shutdown.

Keep these operations distinct:

1. Windows-initiated guest shutdown.
2. QEMU process termination.
3. Container stop.
4. Container object removal.

The exact Dockur/QEMU signal and guest shutdown behavior should be verified before describing `podman stop` as a guaranteed clean Windows shutdown.

Normal stop should not remove the container object. Container removal is reserved for deliberate recreation/reconfiguration. Do not add `-v` to removal commands for this bind-mount deployment.

### Status

The status script should be observational: report container state, exit status, port publication and relevant mounts without starting, stopping, recreating, pruning or repairing anything.


### Operator quick reference — manual start and stop

Run these commands in a SteamOS host terminal as the normal host account `deck`. Do not enter a Distrobox first.

**Start the VM:**

```bash
cd /home/deck/WindowsVM/config
./windows-box-start.sh
```

**Check its state:**

```bash
cd /home/deck/WindowsVM/config
./windows-box-status.sh
```

**Connect to the guest from the PC:**

- Open the verified noVNC console: `http://192.168.1.161:8006/`
- The Windows local account is `DeckVM`. Its password remains in the local protected environment file; never display or share that file.
- RDP at `192.168.1.161:3389` remains pending end-to-end verification. Do not use it as the documented working path yet.

**Stop the VM deliberately:**

```bash
cd /home/deck/WindowsVM/config
./windows-box-stop.sh
./windows-box-status.sh
```

The stop script's currently documented Podman stop request is `podman stop --time 120 windows-box`. This provides a bounded container-stop wait; it is not, by itself, proof that Windows received and completed a clean guest shutdown. Prefer a Windows-initiated shutdown when practical, then use the stop script to complete the documented host-side lifecycle. Check the status output afterward.

**Important command distinction:**

- `distrobox enter windows-box` is incorrect: the named object is not a Distrobox.
- `podman start windows-box` directly bypasses the project start script and is not the normal operator procedure.
- `podman exec -it windows-box ...` opens a process inside an already-running container; it does not start the VM and is not the Windows user interface.
- Do not remove the container or guest storage as part of routine start/stop.

## 4. Manual lifecycle policy

| Event | Expected behavior |
|---|---|
| Steam Deck boots | Windows VM remains stopped |
| User wants Windows | User manually invokes the start script |
| Container starts | Dockur launches QEMU and the Windows guest |
| User works in Windows | PC browser connects to noVNC |
| User finishes | User deliberately shuts down/stops the VM |
| Steam Deck restarts | User starts Windows again only when wanted |
| Unexpected guest/container exit | No silent restart; inspect status/logs and let the user decide |

The current container was created with `--restart=no`. No boot autostart or background service is intended.

## 5. Reference analysis: Odysseus lifecycle scripts

The following existing scripts were inspected as a reference:

- [odysseus_start.sh](https://github.com/laconic-lab/projects/blob/main/odysseus/decktools/odysseus_start.sh)
- [odysseus_stop.sh](https://github.com/laconic-lab/projects/blob/main/odysseus/decktools/odysseus_stop.sh)
- [odysseus_status.sh](https://github.com/laconic-lab/projects/blob/main/odysseus/decktools/odysseus_status.sh)
- [odysseus_logs.sh](https://github.com/laconic-lab/projects/blob/main/odysseus/decktools/odysseus_logs.sh)

These are Odysseus scripts, not Windows VM scripts. Their design principles are useful, but their implementation should not be copied blindly.

### Odysseus start

The start script:

1. Uses strict Bash error handling.
2. Defines project-local PID, ownership-marker and log paths.
3. Calls host Podman through `distrobox-host-exec podman`; it controls the SteamOS host Podman engine.
4. Checks that a recorded PID identifies the expected non-zombie Uvicorn process.
5. Removes a stale/invalid PID file and scans `/proc` to avoid duplicate application processes.
6. Verifies the dedicated ChromaDB container exists.
7. Starts ChromaDB only if it is stopped.
8. Writes an ownership marker only when this script starts ChromaDB; it does not claim an already-running dependency.
9. Waits up to 30 seconds for ChromaDB health.
10. Launches Uvicorn detached with `nohup`, records its PID and logs output.
11. Waits for an HTTP response and verifies process identity.
12. Attempts graceful cleanup if startup fails.

This demonstrates idempotence, dependency checks, readiness checks, process identity verification and ownership tracking.

### Odysseus stop

The stop script:

1. Verifies the recorded PID still identifies the expected application process.
2. Sends SIGTERM and waits up to 20 seconds.
3. Refuses to proceed if the application remains active.
4. Checks for any other Odysseus process before stopping ChromaDB.
5. Stops ChromaDB only when the ownership marker says this start script started it.
6. Leaves independently running ChromaDB untouched.
7. Removes the ownership marker only after confirming the container is stopped.

The key principle is: **stop only what this lifecycle controller started and still owns.**

### Odysseus status and logs

- The status script reports process identity, PID-file consistency, HTTP response, listeners, ChromaDB state/heartbeat, ownership marker and log-file presence. It does not intentionally start or stop services.
- The logs script is a bounded, read-only tail viewer for the project logs.

### Review caveats

- Odysseus Uvicorn is launched with `--host 0.0.0.0 --port 7011`, listening on all IPv4 interfaces. Actual exposure depends on host firewall/network policy; this deserves a separate exposure review.
- The ChromaDB ownership marker is a persistent file. After an interrupted start/stop sequence or manual container operation, it could become stale and no longer accurately describe current ownership. Review marker recovery behavior if that project changes.
- The start script starts the existing ChromaDB container; it does not recreate or redefine the container's restart policy.
- The repository directory also currently contains `odysseus/decktools/runtime/odysseus.pid` with the value `1107511`. A PID is specific to a running host instance and is not portable source configuration; do not trust a committed PID file after reboot or on another machine. Runtime PID/marker files are generally better treated as generated state and excluded from version control. This was observed, not changed.
- These scripts do not themselves configure boot autostart. They run when explicitly invoked unless some external mechanism calls them.

These are design caveats, not a claim that Odysseus is currently malfunctioning.

## 6. Principles to carry into Windows scripts

- Explicit user entry point.
- Idempotent start; do not create duplicate guests.
- Clear ownership of the named container and its guest storage.
- Check required image, configuration, device, mounts and port before launch.
- Distinguish container-created, QEMU-running, Windows-booted and noVNC-reachable states.
- Use bounded waits and useful failure messages.
- Do not silently prune, delete guest data or modify broad host settings to recover.
- Report state and logs without printing secrets.
- Keep `--restart=no`; no systemd, Quadlet, cron or desktop autostart.

Windows has a different shutdown boundary from a Uvicorn process. The script must clearly distinguish stopping Windows, QEMU and the Podman container, and must not claim a graceful guest shutdown unless verified.

## 7. Host safety and authorization

- Run lifecycle scripts as `deck`, not root.
- Do not add privileged mode or broaden host permissions.
- Do not modify host KVM modules, swap/zram, firewall or system services as an automatic side effect.
- Do not print the protected environment file.
- Do not create Windows guest backups, snapshots or copies of `data.img`; this is a disposable lab. Preserve technical knowledge and configuration facts in documentation.
- Do not delete host storage during ordinary stop or container recreation.
- Any future move to automatic startup requires a separate explicit user decision.

## 8. Focused source-review checklist

The local Windows scripts are not committed in the GitHub `windows/` directory. A full source-level audit remains pending. When reviewed on the Deck, check:

- [ ] Pinned image digest and rootless execution as `deck`.
- [ ] `--restart=no`; no hidden autostart mechanism.
- [ ] No privileged mode; correct `/dev/kvm` device mapping.
- [ ] Correct persistent storage and shared-folder mounts; no installation ISO dependency in the normal runtime container.
- [ ] Verified LAN publication `192.168.1.161:8006:8006`.
- [ ] Existing running/stopped container handling; no duplicate guest.
- [ ] Stop semantics, timeout and failure behavior.
- [ ] Status is read-only.
- [ ] No automatic deletion of storage, images or unrelated workloads.
- [ ] No secrets printed.
- [ ] All scripts pass `bash -n`.

This is a focused review plan, not a requirement to add complexity or extra scripts.

## 9. Verified state — 2026-11-12

- The Windows container was manually stopped, its container object removed, and a replacement created from the updated start script.
- The new container uses `--restart=no`; no boot autostart was introduced.
- Podman reported `192.168.1.161:8006->8006/tcp`.
- The host listener was verified on `192.168.1.161:8006`.
- The user confirmed PC client `192.168.1.169` can open the same Windows guest console in Brave and Chrome simultaneously.
- Persistent guest storage was retained during container recreation.
- No VM backup, snapshot or virtual-disk copy was created.

---

*Operating philosophy: the user enters the box deliberately; the box does not start itself. Keep the lifecycle transparent, manual, observable and safe for SteamOS.*


## 10. Installation media versus normal runtime — correction verified 2026-11-14

A custom ISO may be mounted read-only at /custom.iso for the initial Windows installation. It is not a normal runtime dependency after Windows has been installed to the persistent guest disk.

The 2026-11-12 deployment originally kept the ISO mount in the regular start script and container definition. This was a lifecycle mistake: deleting the ISO then blocked startup at the script's readability check, even though the installed guest data remained in /home/deck/WindowsVM/storage.

**Correct normal-runtime definition:**
- /home/deck/WindowsVM/storage:/storage:rw
- /home/deck/WindowsVM/shared:/shared:rw
- no /custom.iso mount and no ISO readability check.

**2026-11-14 validation:** the original stopped container was preserved as windows-box-iso-legacy; a replacement windows-box was created with the same persistent storage, shared folder, pinned Dockur image, protected environment file, KVM device, port publication and --restart=no. Before it was started, inspection showed exactly the two mounts above and no ISO mount. The replacement then started successfully and the user confirmed Web Console connectivity at http://192.168.1.161:8006/.

Future custom-ISO deployments must use two distinct container-definition phases: an installation container with the temporary read-only ISO mount, followed by a normal runtime container without it. Recreate the container object to change its bind mounts; preserve the host-backed guest storage throughout. Inspect the created runtime container before starting it. Never run two containers against the same guest storage simultaneously.

The preserved windows-box-iso-legacy container is a rollback reference for this validation only. Do not start it while the replacement uses the same storage.

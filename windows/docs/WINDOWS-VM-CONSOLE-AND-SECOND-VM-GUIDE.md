# Windows VM Console and Second-VM Deployment Guide

**Platform:** Steam Deck OLED / SteamOS / rootless Podman / dockur/windows  
**Current guest:** windows-vm in container windows-box  
**Status:** Operating guide; LAN noVNC access verified from the PC client; second-VM example is not executed.

## 1. Purpose and architecture

This guide explains how to operate the browser console, where VM resources are configured, and how to create another independent Windows guest without reusing the first guest's disk or identity.

The console is a display/input channel, not a complete VM management dashboard. The current architecture does not include a central web manager comparable to VMware Horizon. Podman CLI provides the inventory and lifecycle view, while each Windows guest has a separate noVNC endpoint:

- noVNC displays the Windows guest screen and forwards keyboard/mouse input.
- SteamOS and Podman own the container lifecycle and resource configuration.
- Dockur environment variables are read when the container is created.
- QEMU/KVM runs the virtual machine.
- /home/deck/WindowsVM/storage contains persistent guest state and must not be removed when recreating the container.

~~~text
PC client (192.168.1.169)
        | HTTP / noVNC, TCP 8006
        v
Steam Deck host (192.168.1.161)
        | Podman published port
        v
windows-box container
        | QEMU + KVM (/dev/kvm)
        v
Windows guest: windows-vm
        +-- 4 vCPUs
        +-- 6 GiB RAM
        +-- 128 GiB growable raw disk
        +-- persistent host storage
~~~

The selected viewer URL is **http://192.168.1.161:8006/**.

**Current verified state (2026-11-12):** the start script publishes `192.168.1.161:8006:8006`; the container was recreated; `podman port` and `ss` confirmed the LAN listener; and the user successfully opened the console from PC client `192.168.1.169` in Brave and Chrome simultaneously. Both viewers show the same guest desktop.

## 1.1 How Podman, Dockur, QEMU/KVM and each Windows VM relate

The important distinction is that **Dockur is the container image used as a VM runtime package; it is not a single shared hypervisor instance that hosts all guests inside one container**.

For this deployment model, create one rootless Podman container from the Dockur image for each Windows guest. Each such container launches its own QEMU process and owns one Windows guest. All containers share the host's Podman engine and KVM device, and may use the same locally cached Dockur image, but each guest must have independent storage, configuration, container name and host console port.

~~~text
Steam Deck OLED / SteamOS host
|
+-- AMD-V / SVM CPU virtualisation support
|   |
|   +-- Linux KVM kernel modules (kvm, kvm_amd)
|       |
|       +-- /dev/kvm
|
+-- Rootless Podman (one user-level container engine)
    |
    +-- Dockur Windows image (shared image/template, pinned digest)
    |   |
    |   +-- Container: windows-box
    |   |   |
    |   |   +-- Dockur entrypoint / helper services
    |   |   +-- QEMU process using KVM acceleration
    |   |   +-- Virtual hardware: vCPU, RAM, disk, UEFI
    |   |   +-- Windows guest: windows-vm
    |   |   +-- Host bind mount:
    |   |       /home/deck/WindowsVM/storage -> /storage
    |   |   +-- noVNC viewer -> host TCP 8006
    |   |
    |   +-- Container: windows-box-2 (example, not created)
    |       |
    |       +-- Separate QEMU process using KVM acceleration
    |       +-- Separate virtual hardware and Windows guest
    |       +-- Separate host bind mount:
    |       |   /home/deck/WindowsVM-2/storage -> /storage
    |       +-- Separate noVNC viewer -> host TCP 8007
    |
    +-- Other unrelated Podman containers (Pi-hole, etc.)
~~~

The Dockur image is a reusable image artifact. A container is an instance created from that image. The QEMU process inside each container is the actual VM execution process. The Windows operating system is the guest. KVM is the host kernel's hardware-virtualisation acceleration interface; it is not another Windows VM and is not a management console.

The diagram is a conceptual relationship diagram. The first container and its QEMU guest are the deployed instance. The second container is only an example documented for a future independent guest.

### Virtual hardware notes

- **vCPU and RAM:** assigned to each QEMU guest through its own container environment/configuration.
- **Virtual disk:** stored in that guest's independent host-backed storage directory.
- **UEFI:** provided by the guest firmware files and QEMU configuration in the Dockur storage/runtime model.
- **TPM 2.0:** Windows 11 may require a virtual TPM. Do not assume a separate host TPM device or software TPM installation from this diagram; the precise virtual TPM implementation is image-version/configuration-specific and was not independently audited in the current guest.
- **Networking:** the current guest uses Dockur's user-mode networking (passt observed in the container process list), rather than an independently bridged LAN adapter. The guest-reported address must not be mistaken for proof that each guest has a distinct LAN IP.
- **noVNC:** each guest has its own viewer endpoint. Different containers must publish different host ports.

## 2. Apply the selected LAN address to the existing VM

This changes only the container's host-side web-console publication. It does not change the Windows guest disk or its installation.

**Expected result:** Deck host 192.168.1.161 listens on TCP 8006; the PC opens http://192.168.1.161:8006/.

First inspect the current script line and persistent mounts:

~~~bash
SCRIPT="/home/deck/WindowsVM/config/windows-box-start.sh"
grep -n -- '--publish' "$SCRIPT"
podman inspect windows-box --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
~~~

The original publication was `127.0.0.1:8006:8006`; it has now been changed and verified as `192.168.1.161:8006:8006`. Confirm the persistent host storage mount is `/home/deck/WindowsVM/storage -> /storage` before any future container recreation. If either differs from the documented current state, stop and inspect rather than applying the example blindly.

After confirming those facts, edit the start script directly. This is a disposable lab and the user has explicitly rejected configuration-script backups as well as Windows guest backups. Preserve the known original setting in project documentation instead:

~~~bash
set -euo pipefail
SCRIPT="/home/deck/WindowsVM/config/windows-box-start.sh"
grep -qF -- '--publish 127.0.0.1:8006:8006' "$SCRIPT"
sed -i 's/--publish 127\.0\.0\.1:8006:8006/--publish 192.168.1.161:8006:8006/' "$SCRIPT"
sed -i 's#http://127\.0\.0\.1:8006#http://192.168.1.161:8006#' "$SCRIPT"

bash -n "$SCRIPT"
grep -nE -- '--publish|Web console:' "$SCRIPT"
~~~

Review the diff. It should change only the host publication and printed console URL.

Then recreate the container wrapper while retaining the persistent host mounts:

~~~bash
set -euo pipefail
podman stop --time 120 windows-box
podman rm windows-box
/home/deck/WindowsVM/config/windows-box-start.sh
~~~

The rm command removes the stopped container object, not /home/deck/WindowsVM/storage. Do not run rm -rf on the project directory or storage. The start script creates a new container using the same pinned image, environment file, ISO and persistent bind mounts.

Verify on the Steam Deck:

~~~bash
podman port windows-box
ss -ltn '( sport = :8006 )'
podman inspect windows-box --format 'State={{.State.Status}} Restart={{.HostConfig.RestartPolicy.Name}}'
~~~

Expected publication/listener: `192.168.1.161:8006`. This procedure has been executed and the browser test passed from PC `192.168.1.169`. The user also confirmed that Brave and Chrome can view the same guest desktop simultaneously. A host listener check does not replace the browser test for future changes.

If the LAN binding must be reverted, edit the two documented lines directly back to 127.0.0.1:8006 and validate with bash -n. No script backup is created. Preserve /home/deck/WindowsVM/storage throughout.

No firewall change is included. The inspected public zone already has broad TCP/UDP port allowances from 1024 through 65535. Do not add another broad rule or publish guest RDP as part of this change.

## 3. Using the noVNC web console

1. Start the VM on the Steam Deck:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-start.sh
   ~~~

2. From the PC, open:

   ~~~text
   http://192.168.1.161:8006/
   ~~~

3. Wait for the Windows desktop. The viewer is the guest's screen and input device.
4. Use the noVNC toolbar for display scaling, keyboard handling and fullscreen as available in the bundled viewer.
5. Shut Windows down from inside Windows when practical, or use the Deck stop script:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-stop.sh
   ~~~

The stop script requests a container stop with a 120-second timeout.

### What the console does not do

The noVNC page does not provide authoritative controls for vCPU count, RAM, disk capacity, Podman mounts, KVM device access or host port publication. Those are deployment settings controlled on SteamOS.

The web viewer is a convenient screen/keyboard/mouse console, particularly during installation and recovery. It is not a hypervisor settings panel or a Windows RDP service.

## 4. Where CPU, RAM, disk and Windows setup parameters live

Edit the protected Steam Deck environment file:

~~~text
/home/deck/WindowsVM/config/windows-box.env
~~~

It is mode 0600 and contains a generated Windows account password. Do not print the complete file, paste it into chat, or commit it to Git.

Known deployed values:

| Variable | Current value | Meaning |
|---|---:|---|
| VERSION | 11 | Windows 11 Pro download selection; mounted custom ISO takes precedence |
| LANGUAGE | en-US | Windows language |
| REGION | en-US | Regional formats |
| KEYBOARD | en-US | Keyboard layout |
| CPU_CORES | 4 | Virtual CPU cores |
| RAM_SIZE | 6G | Guest RAM |
| RAM_CHECK | Y | Check host memory before starting |
| KVM | Y | Hardware-assisted virtualisation |
| DISK_SIZE | 128G | Primary virtual disk capacity |
| DISK_FMT | raw | Raw disk image format |
| ALLOCATE | N | Do not preallocate full disk capacity |
| NETWORK | user | User-mode networking; passt observed at runtime |
| DISPLAY | web | Web viewer display backend |
| WEB | Y | Enable web viewer |
| WEB_PORT | 8006 | Web viewer port inside the container |
| USERNAME | DeckVM | Local Windows account name |
| AUTOLOGIN | Y | Automatically sign in after startup |
| HOST | windows-vm | Windows computer name |
| SAMBA | Y | Enable shared-folder Samba integration |

The environment file also contains PASSWORD; its value is intentionally not shown. KEY is not configured in the known deployment. Windows can install without supplying a product key; that does not activate Windows or grant a licence. Activation/licensing is separate.

### Change procedure

1. Stop the VM gracefully:

   ~~~bash
   /home/deck/WindowsVM/config/windows-box-stop.sh
   ~~~

2. Edit only the required keys locally:

   ~~~bash
   nano /home/deck/WindowsVM/config/windows-box.env
   ~~~

3. Check permissions without displaying contents:

   ~~~bash
   stat -c '%A %a %U:%G %n' /home/deck/WindowsVM/config/windows-box.env
   ~~~

   Expected mode: 600, owned by deck:deck.

4. Recreate the container if the change affects container creation or QEMU configuration. A simple podman start windows-box does not apply modified environment variables, devices, mounts or port publications; the existing start script starts the existing container unchanged.
5. Preserve /home/deck/WindowsVM/storage. Removing the container is not the same as deleting the persistent guest disk.

CPU_CORES and RAM_SIZE changes require a new container configuration so the entrypoint can launch QEMU with the new values. Plan memory conservatively: SteamOS, the desktop, browsers and other containers also need RAM.

Do not reduce DISK_SIZE to shrink an existing guest. Increasing virtual disk capacity and extending the Windows partition are separate operations; validate the exact resize procedure before changing an existing disk.

## 5. How the current unattended Windows installation worked

The deployment uses the image pinned to:

~~~text
docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc
~~~

Dockur automates Windows Setup. The deployment supplies settings through environment variables rather than a manually authored Windows answer file.

The current configuration used:

- VERSION=11: Windows 11 Pro selection when Dockur downloads its own media.
- A local ISO mounted read-only as /custom.iso. When a custom ISO is mounted, it is used as the installation media; VERSION is not the source of the installed build.
- USERNAME=DeckVM: local account name.
- PASSWORD: generated locally and stored in the protected environment file; secret value is not recorded here.
- AUTOLOGIN=Y: automatic sign-in after startup. This explains why no login password prompt appeared; it does not mean the account has no password.
- HOST=windows-vm: Windows computer name.
- LANGUAGE, REGION and KEYBOARD: locale and input configuration.
- CPU_CORES=4, RAM_SIZE=6G, DISK_SIZE=128G, DISK_FMT=raw and ALLOCATE=N: virtual hardware and disk creation.
- KVM=Y, NETWORK=user, DISPLAY=web, WEB=Y, WEB_PORT=8006 and SAMBA=Y: execution, networking, viewer and file-sharing behavior.

No product key was supplied in the known configuration. Installation without entering a key does not activate Windows. Use a valid licence/entitlement separately; never put a real key in Git or a public script.

### Timing and persistence

Account, locale, computer-name and initial installation variables are intended to be set before first installation. Changing USERNAME, PASSWORD, VERSION or locale variables after Windows is installed does not reliably reconfigure the existing guest. For a genuinely fresh guest, create a separate empty storage directory and a separate container.

The official Dockur environment reference documents variables including USERNAME, PASSWORD, AUTOLOGIN, KEY, CPU_CORES, RAM_SIZE, DISK_SIZE, KVM, NETWORK, WEB_PORT and PROTECT. Check the reference against the exact pinned image before using less common settings:

https://github.com/dockur/windows/blob/master/docs/environment.md

## 6. Second Windows VM: isolation rules

A second guest needs its own:

- Podman container name;
- protected environment file and generated password;
- persistent storage directory, including its own data.img and firmware variables;
- shared folder;
- host-side web-console port.

Never run two QEMU guests against the same storage directory or data.img. Never reuse the first guest's storage directory. Do not publish both web viewers on the same host IP/port pair.

The example creates windows-box-2, guest windows-vm-2, project root /home/deck/WindowsVM-2 and web viewer port 8007. It uses the same pinned image and existing ISO. It is a template only; it has not been executed.

### 5.1 Read-only preflight

Run as the normal SteamOS user deck, not with sudo:

~~~bash
echo "===== CONTAINER NAME ====="
podman ps -a --filter name='^windows-box-2$'

echo
echo "===== PINNED IMAGE ====="
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
podman image exists "$IMAGE"
echo "image-exists-exit=$?"

echo
echo "===== KVM ====="
test -r /dev/kvm && test -w /dev/kvm && echo "/dev/kvm accessible"

echo
echo "===== ISO ====="
test -r /home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO && echo "ISO readable"

echo
echo "===== HOME CAPACITY ====="
df -h /home

echo
echo "===== HOST PORT ====="
ss -ltn '( sport = :8007 )'
~~~

Stop if the container name or project directory already exists. Inspect it rather than overwriting it. Ensure there is enough RAM for both guests plus SteamOS, and enough storage for the second guest's growth.

### 5.2 Create a separate protected configuration

Only after reviewing the preflight and deciding to create a second VM:

~~~bash
set -euo pipefail
umask 077

PROJECT="/home/deck/WindowsVM-2"
CONFIG="$PROJECT/config"
STORAGE="$PROJECT/storage"
SHARED="$PROJECT/shared"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
ISO="/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO"

if [[ -e "$PROJECT" ]]; then
    echo "ERROR: $PROJECT already exists; inspect it before proceeding." >&2
    exit 1
fi

test -r "$ISO"
podman image exists "$IMAGE"

mkdir -p "$CONFIG" "$STORAGE" "$SHARED"
chmod 700 "$PROJECT" "$CONFIG" "$STORAGE" "$SHARED"

# Generate a unique per-VM password; never print it.
VM_PASSWORD="$(openssl rand -hex 24)"

cat > "$CONFIG/windows-box-2.env" <<EOF
VERSION=11
LANGUAGE=en-US
REGION=en-US
KEYBOARD=en-US
CPU_CORES=2
RAM_SIZE=4G
RAM_CHECK=Y
KVM=Y
DISK_SIZE=128G
DISK_FMT=raw
ALLOCATE=N
NETWORK=user
DISPLAY=web
WEB=Y
WEB_PORT=8006
USERNAME=DeckVM2
PASSWORD=$VM_PASSWORD
AUTOLOGIN=Y
HOST=windows-vm-2
SAMBA=Y
EOF

unset VM_PASSWORD
chmod 600 "$CONFIG/windows-box-2.env"
stat -c '%A %a %U:%G %n' "$PROJECT" "$CONFIG" "$STORAGE" "$SHARED" "$CONFIG/windows-box-2.env"
~~~

This example starts with 2 vCPUs and 4 GiB RAM, but these are not guaranteed safe allocations if both VMs run simultaneously. The first VM already uses 4 vCPUs and 6 GiB RAM. Check current host memory and CPU contention before running both at once.

The second account password is stored only in the second environment file. Automatic logon is enabled, but the account still has a password. Retrieve it locally if interactive authentication is later required.

### 5.3 Create and start the second container

This is the Podman equivalent of the existing deployment pattern. It does not modify windows-box or its storage:

~~~bash
set -euo pipefail

PROJECT="/home/deck/WindowsVM-2"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
ISO="/home/deck/uup-box/26200.9974_pro/26100.1.1_PROFESSIONAL_X64_EN-US.ISO"

podman run --detach \
    --name windows-box-2 \
    --pull=never \
    --restart=no \
    --stop-timeout 120 \
    --device=/dev/kvm \
    --publish 192.168.1.161:8007:8006 \
    --volume "$PROJECT/storage:/storage:rw" \
    --volume "$ISO:/custom.iso:ro" \
    --volume "$PROJECT/shared:/shared:rw" \
    --env-file "$PROJECT/config/windows-box-2.env" \
    "$IMAGE"
~~~

The second console would be http://192.168.1.161:8007/.

### 5.4 Verify the second VM

~~~bash
podman ps -a --filter name='^windows-box-2$'
podman port windows-box-2
podman inspect windows-box-2 --format 'State={{.State.Status}} Restart={{.HostConfig.RestartPolicy.Name}}'
podman inspect windows-box-2 --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
podman top windows-box-2
~~~

Verify the unique container, restart policy no, host port 8007 mapped to container port 8006, second storage mounted at /storage, ISO mounted read-only, and QEMU using KVM. After setup, verify Windows edition, build, account, computer name, activation and guest networking.

## 7. Lifecycle commands

### Listing and checking all Windows VM containers

There is no VMware Horizon-style central console in the current deployment. Podman is the host-side inventory and lifecycle manager; each Dockur container exposes its own noVNC viewer on its own published port.

Use podman ps to see only running containers, or podman ps -a to include stopped/exited containers. The naming convention used in this project is windows-box, windows-box-2, and so on.

~~~bash
echo "===== ALL WINDOWS VM CONTAINERS ====="
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | { head -n 1; grep -E '^windows-box(-[0-9]+)?[[:space:]]' || true; }

echo
echo "===== RUNNING WINDOWS VM CONTAINERS ====="
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | { head -n 1; grep -E '^windows-box(-[0-9]+)?[[:space:]]' || true; }
~~~

For a specific VM:

~~~bash
podman inspect windows-box --format 'Name={{.Name}} State={{.State.Status}}'
podman port windows-box
~~~

Interpretation:

- running: the container is running; verify QEMU is active if diagnosing the guest.
- exited: the container exists but is stopped.
- created: the container exists but has not started successfully yet.
- No matching container: it has not been created or has been removed.

To check QEMU inside a running instance:

~~~bash
podman top windows-box
~~~

Replace the name with the desired instance. The per-VM noVNC URL is the host IP and port assigned to that container (currently intended to be 192.168.1.161:8006 for the first VM and 192.168.1.161:8007 for the second example).



Existing VM:

~~~bash
/home/deck/WindowsVM/config/windows-box-start.sh
/home/deck/WindowsVM/config/windows-box-status.sh
/home/deck/WindowsVM/config/windows-box-stop.sh
~~~

Second example, if created:

~~~bash
podman start windows-box-2
podman stop --time 120 windows-box-2
podman ps -a --filter name='^windows-box-2$'
~~~

Neither container is configured for boot autostart.

## 8. Cleanly remove a Windows VM

There are two different operations. Choose deliberately:

1. **Remove the Podman container but keep the Windows guest data.** This is useful for replacing a container wrapper while retaining the installed Windows system.
2. **Permanently remove the VM and its project data.** This deletes the Windows installation, virtual disk, firmware state, environment file and shared-folder contents. This is intentionally irreversible under the disposable-lab policy; no guest backup or snapshot is maintained.

Do not confuse container removal with guest removal. In this project, /storage is a host bind mount. Removing the container does not remove the host directory or its contents. Podman's documentation distinguishes containers from bind-mounted host data:
https://docs.podman.io/en/stable/markdown/podman-run.1.html
https://docs.podman.io/en/latest/markdown/podman-rm.1.html

### 8.1 Inventory and confirm the exact VM

Run as deck, without sudo:

~~~bash
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
podman inspect windows-box --format '{{.Name}} state={{.State.Status}}'
podman inspect windows-box --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
~~~

For a second guest, substitute its exact container name, such as windows-box-2. Confirm the host project directory from the /storage mount before proceeding. Do not infer the data path from a container name alone.

### 8.2 Remove only the container; preserve Windows data

This leaves the project directory and guest disk intact. It removes the container object, not the Dockur image and not the host bind-mounted files.

For the current VM:

~~~bash
set -euo pipefail
NAME="windows-box"

podman container exists "$NAME" || {
    echo "Container $NAME does not exist."
    exit 1
}

STATE="$(podman inspect --format '{{.State.Status}}' "$NAME")"
if [[ "$STATE" == "running" ]]; then
    podman stop --time 120 "$NAME"
fi

podman rm "$NAME"

if podman container exists "$NAME"; then
    echo "ERROR: container still exists; inspect before continuing." >&2
    exit 1
fi

test -d /home/deck/WindowsVM/storage
echo "Container removed; persistent Windows storage retained."
~~~

For another guest, change both the container name and the verified project path. Do not use podman rm -f as the routine path; if graceful stop or removal fails, inspect the state and logs before deciding how to proceed.

### 8.3 Permanently erase the VM and its project directory

**DESTRUCTIVE:** this removes the Windows guest and its persistent files. The project intentionally maintains no Windows guest backup or snapshot. Use this procedure only when you intend to discard the complete guest installation and its data.

First remove the container using Section 8.2. Then verify the exact project directory. The example below is intentionally tied to the current VM path and asks for an explicit confirmation phrase:

~~~bash
set -euo pipefail

NAME="windows-box"
PROJECT="/home/deck/WindowsVM"
EXPECTED="/home/deck/WindowsVM"

# Refuse to proceed if the container still exists.
if podman container exists "$NAME"; then
    echo "ERROR: remove container $NAME first." >&2
    exit 1
fi

# Refuse unexpected paths and require the expected storage directory.
[[ "$PROJECT" == "$EXPECTED" ]] || {
    echo "ERROR: project path mismatch." >&2
    exit 1
}
[[ -d "$PROJECT/storage" ]] || {
    echo "ERROR: expected storage directory not found." >&2
    exit 1
}

echo "This will permanently delete:"
printf '  %s\n' "$PROJECT"
read -r -p 'Type DELETE-WINDOWS-VM to continue: ' CONFIRM
[[ "$CONFIRM" == "DELETE-WINDOWS-VM" ]] || {
    echo "Cancelled."
    exit 1
}

rm -r --one-file-system -- "$PROJECT"
echo "Project directory removed."
~~~

For a second VM, update NAME, PROJECT and EXPECTED to that VM's independently verified values before running. Never copy this command unchanged for an arbitrary path.

### 8.4 What is not removed automatically

- The shared Dockur image remains available for other Windows VM containers. Do not remove it while another guest uses it.
- The installation ISO is stored outside the project at /home/deck/uup-box/...; this procedure does not delete it.
- Other Podman containers and projects are unaffected.
- No global prune command is required. Avoid podman system prune, podman volume prune, or broad podman rm -a for removing one guest.

After removal, list remaining containers:

~~~bash
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
~~~

## 9. Security and operational notes

- noVNC is an administrative console. Anyone able to reach an unprotected viewer may be able to interact with the Windows desktop.
- The user accepts LAN reachability. The current public firewalld zone already has broad TCP/UDP allowances for ports 1024-65535; this guide does not claim access is restricted to the single PC.
- Dockur documents PROTECT as enabling password protection for the web interface. Verify its behavior against the pinned image before relying on it.
- Do not publish guest RDP (3389) unless separately required and reviewed.
- Keep environment files mode 0600; do not commit them. Never print passwords or product keys.
- Use unique host ports and persistent directories for every guest.
- Stop a guest before changing its deployment configuration.
- Never remove a storage directory as part of routine container recreation.
- Disposable-lab policy: do not create Windows guest backups, snapshots or virtual-disk copies. Preserve useful configuration parameters and verified findings in documentation; rebuild a damaged guest rather than restoring a wounded one.

## 10. References

- Dockur environment variables: https://github.com/dockur/windows/blob/master/docs/environment.md
- Dockur project: https://github.com/dockur/windows
- Podman run and bind mounts: https://docs.podman.io/en/stable/markdown/podman-run.1.html
- Podman container removal: https://docs.podman.io/en/latest/markdown/podman-rm.1.html
- [Project installation and evidence log](./WINDOWS-VM-INSTALLATION-GUIDE.md)
- [Project README](../README.md)

---

*Living operations guide. Distinguish documented templates from commands actually executed on the Steam Deck.*


### 3.1 Verified PC-client access — 2026-11-12

The user confirmed that `http://192.168.1.161:8006/` opens successfully from PC client `192.168.1.169` in both Brave and Chrome at the same time. This is a mirrored view of one Windows guest console, not independent guest sessions. No guest RDP port was published as part of this change.

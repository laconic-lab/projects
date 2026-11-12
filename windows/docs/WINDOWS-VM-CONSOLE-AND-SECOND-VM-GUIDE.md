# Windows VM Console and Second-VM Deployment Guide

**Platform:** Steam Deck OLED / SteamOS / rootless Podman / dockur/windows  
**Current guest:** windows-vm in container windows-box  
**Status:** Operating guide and reproducible deployment reference; second-VM example is not executed.

## 1. Purpose and architecture

This guide explains how to operate the browser console, where VM resources are configured, and how to create another independent Windows guest without reusing the first guest's disk or identity.

The console is a display/input channel, not a complete VM management dashboard:

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

**Current-state warning:** the supplied runtime inspection still showed 127.0.0.1:8006 as the listener and Podman publication. The LAN URL becomes reachable only after the host start script is changed to publish 192.168.1.161:8006:8006 and the existing container is recreated. That host-side change has not yet been applied or tested.

## 2. Using the noVNC web console

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

## 3. Where CPU, RAM, disk and Windows setup parameters live

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

## 4. How the current unattended Windows installation worked

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

## 5. Second Windows VM: isolation rules

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

## 6. Lifecycle commands

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

## 7. Security and operational notes

- noVNC is an administrative console. Anyone able to reach an unprotected viewer may be able to interact with the Windows desktop.
- The user accepts LAN reachability. The current public firewalld zone already has broad TCP/UDP allowances for ports 1024-65535; this guide does not claim access is restricted to the single PC.
- Dockur documents PROTECT as enabling password protection for the web interface. Verify its behavior against the pinned image before relying on it.
- Do not publish guest RDP (3389) unless separately required and reviewed.
- Keep environment files mode 0600; do not commit them. Never print passwords or product keys.
- Use unique host ports and persistent directories for every guest.
- Stop a guest before changing its deployment configuration.
- Never remove a storage directory as part of routine container recreation.
- No backup or snapshot is included. Backup/restore remains deferred until the user declares the VM fully configured.

## 8. References

- Dockur environment variables: https://github.com/dockur/windows/blob/master/docs/environment.md
- Dockur project: https://github.com/dockur/windows
- [Project installation and evidence log](./WINDOWS-VM-INSTALLATION-GUIDE.md)
- [Project README](../README.md)

---

*Living operations guide. Distinguish documented templates from commands actually executed on the Steam Deck.*

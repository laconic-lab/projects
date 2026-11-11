# Pi-hole on SteamOS — Installation Guide

**Project:** Pi-hole on Steam Deck OLED  
**Repository:** `laconic-lab/projects`  
**Document:** `pi-hole/docs/INSTALLATION.md`  
**Status:** Draft — installation procedure requires validation  
**Last reviewed:** 2026-11-03

---

## Contents

- [1. Purpose](#1-purpose)
- [2. Target architecture](#2-target-architecture)
- [3. Installation prerequisites](#3-installation-prerequisites)
- [4. Persistent storage preparation](#4-persistent-storage-preparation)
- [5. Rootless Podman networking](#5-rootless-podman-networking)
- [6. Firewall preparation](#6-firewall-preparation)
- [7. Pi-hole image selection](#7-pi-hole-image-selection)
- [8. Credential handling — mandatory validation gate](#8-credential-handling-mandatory-validation-gate)
- [9. Container configuration](#9-container-configuration)
- [10. Initial container verification](#10-initial-container-verification)
- [11. DNS and administration testing](#11-dns-and-administration-testing)
- [12. Lifecycle management](#12-lifecycle-management)
- [13. Backup preparation](#13-backup-preparation)
- [14. Installation completion checklist](#14-installation-completion-checklist)
- [15. Installation boundaries](#15-installation-boundaries)
- [16. Evidence and validation status](#16-evidence-and-validation-status)
- [17. Change history](#17-change-history)

## 1. Purpose

This document describes how to install Pi-hole on SteamOS using rootless Podman and `pasta` networking.

It is intended for a **fresh installation**, not for repairing, recreating or replacing an existing Pi-hole deployment.

The existing installation is documented separately in:

`Pi-hole on SteamOS — Architecture & Operations.md`

### Operating principles

1. Diagnose before modifying.  
2. Use read-only checks before installation.  
3. Run Podman as the normal `deck` user.  
4. Avoid privileged containers and host networking.  
5. Preserve persistent data independently of the container lifecycle.  
6. Never expose passwords in shell history, terminal output, logs or Git.  
7. Do not enable automatic startup before lifecycle testing.  
8. Verify every installation stage before proceeding.  
9. Never recreate an existing container without inspecting it first.

---

## 2. Target architecture

The intended architecture is:

```text
                 LOCAL LAN
              192.168.1.0/24
                      |
              Steam Deck OLED
                      |
                  SteamOS
                      |
                 firewalld
                      |
                pasta / passt
                      |
                Rootless Podman
                      |
                   pihole
                      |
                  Pi-hole FTL
                      |
                DNS upstreams
```

### Components

| Component | Responsibility |
| ----- | ----- |
| SteamOS | Host operating system |
| Distrobox | Optional project environment and data organisation |
| Podman | Rootless container runtime |
| pasta | Rootless container networking |
| firewalld | Host firewall |
| systemd user service | Optional lifecycle management |
| Pi-hole FTL | DNS filtering and resolution |

**Important:** The Distrobox is not required to remain running for the Pi-hole Podman container to operate.

The host owns the Podman container lifecycle.

---

## 3. Installation prerequisites

### 3.1 Hardware and host

The installation target should have:

* Steam Deck OLED running SteamOS.  
* A working wired LAN connection.  
* A stable LAN IPv4 address.  
* A normal non-root user account.  
* Rootless Podman.  
* `firewalld` available if using the documented firewall procedure.

The existing installation used:

| Property | Existing configuration |
| ----- | ----- |
| User | `deck` |
| UID | `1000` |
| LAN address | `192.168.1.161` |
| Ethernet interface | `enp4s0f3u1u4` |
| LAN subnet | `192.168.1.0/24` |
| Admin PC | `192.168.1.169` |
| Time zone | `Europe/Paris` |

These are installation-specific values. A fresh installation must verify its own network configuration.

### 3.2 Read-only preflight

Run these checks before creating directories, changing sysctl settings or modifying firewall rules.

```bash
echo "===== USER ====="
id

echo
echo "===== OPERATING SYSTEM ====="
cat /etc/os-release

echo
echo "===== NETWORK ====="
ip -br address

echo
echo "===== PODMAN ====="
podman --version
podman info --format 'Rootless={{.Host.Security.Rootless}} NetworkBackend={{.Host.NetworkBackend}}'

echo
echo "===== FIREWALL ====="
firewall-cmd --state
firewall-cmd --get-active-zones

echo
echo "===== EXISTING PI-HOLE CONTAINERS ====="
podman ps -a --filter name=pihole

echo
echo "===== EXISTING DATA DIRECTORIES ====="
ls -ld /home/deck/pihole-box \
       /home/deck/pihole-box/etc-pihole \
       /home/deck/pihole-box/etc-dnsmasq.d 2>/dev/null
```

Do not proceed if:

* Podman is operating as root rather than rootless.  
* Another DNS service already occupies the intended LAN address and ports.  
* An existing Pi-hole container or data directory is found and has not been inspected.  
* The expected network interface or address is incorrect.  
* The firewall configuration is unclear.

### 3.3 Port availability

Inspect the intended ports:

```bash
sudo ss -lntup | grep -E ':(53|8080|8443)([[:space:]]|$)'
```

The intended host-side ports are:

| Host port | Protocol | Purpose |
| ----- | ----- | ----- |
| 53 | TCP | DNS |
| 53 | UDP | DNS |
| 8080 | TCP | HTTP administration |
| 8443 | TCP | HTTPS administration |

Do not terminate an existing listener merely to make installation possible. Identify its owner first.

---

## 4. Persistent storage preparation

### 4.1 Directory layout

The existing project uses:

```text
/home/deck/pihole-box/
├── etc-pihole/
└── etc-dnsmasq.d/
```

The directories are bind-mounted into the Pi-hole container.

The Distrobox itself is not a runtime dependency of the Pi-hole container.

### 4.2 Create directories

Only after confirming that the paths do not contain an existing installation:

```bash
mkdir -p /home/deck/pihole-box/etc-pihole
mkdir -p /home/deck/pihole-box/etc-dnsmasq.d
```

Verify:

```bash
ls -ld /home/deck/pihole-box
ls -ld /home/deck/pihole-box/etc-pihole
ls -ld /home/deck/pihole-box/etc-dnsmasq.d
```

Do not recursively change ownership or permissions without first inspecting the existing state and the requirements of the selected Pi-hole image.

### 4.3 Persistence requirement

The following host directories must survive container recreation:

* `/home/deck/pihole-box/etc-pihole`  
* `/home/deck/pihole-box/etc-dnsmasq.d`

The container's writable layer is not a substitute for persistent configuration storage.

---

## 5. Rootless Podman networking

### 5.1 Network mode

The intended network mode is `pasta`, the rootless networking mechanism used by Podman.

Do not switch to:

* Host networking.  
* Privileged container networking.  
* An unverified custom network configuration.

### 5.2 Port 53 requirement

Rootless networking normally restricts binding to ports below 1024\.

The existing SteamOS installation uses:

```text
net.ipv4.ip_unprivileged_port_start=53
```

Persistent configuration:

```text
/etc/sysctl.d/99-pihole.conf
```

Expected content:

```text
net.ipv4.ip_unprivileged_port_start=53
```

This is a host-wide kernel setting.

Before applying it on a fresh installation:

1. Inspect the current sysctl value.  
2. Inspect existing sysctl configuration files.  
3. Assess the impact on other host applications.  
4. Confirm that the chosen rootless networking design requires it.  
5. Obtain approval before changing it.

Read-only inspection:

```bash
sysctl net.ipv4.ip_unprivileged_port_start

grep -R "ip_unprivileged_port_start" \
    /etc/sysctl.conf /etc/sysctl.d 2>/dev/null
```

Do not overwrite another sysctl configuration file or duplicate an existing setting.

---

## 6. Firewall preparation

### 6.1 Intended DNS access

The intended policy is to allow DNS only from the local IPv4 LAN:

```text
192.168.1.0/24
```

Required rules:

* TCP port 53 from the LAN.  
* UDP port 53 from the LAN.

The administration interfaces use ports 8080 and 8443\.

Their exposure must be assessed separately. Do not assume that opening DNS also authorizes unrestricted administration access.

### 6.2 Inspect before changing

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=public --list-rich-rules
```

The existing installation uses the `public` zone, but a fresh installation must verify its active zone and interface association.

### 6.3 Firewall policy

Do not replace the complete firewall configuration.

Only add the specifically required rules after confirming:

* The correct active zone.  
* The correct LAN subnet.  
* The correct network interface.  
* No conflicting or broader rules.

Keep runtime and permanent configurations consistent.

---

## 7. Pi-hole image selection

The existing installation used:

```text
docker.io/pihole/pihole:latest
```

The `latest` tag is mutable.

For reproducible installations, record:

* Image repository.  
* Image tag.  
* Image digest.  
* Pi-hole version.  
* Installation date.

Do not assume that the current `latest` image will always produce the same installation.

Before creating a production container, inspect the official Pi-hole Docker documentation and confirm that the selected image version supports the intended configuration.

Official documentation:

* [https\://docs.pi-hole.net/docker/](https://docs.pi-hole.net/docker/)  
* [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)  
* [https\://github.com/pi-hole/docker-pi-hole](https://github.com/pi-hole/docker-pi-hole)

---

## 8. Credential handling — mandatory validation gate

The web administration password must not be included directly in:

* A shell command.  
* Shell history.  
* A Git-tracked Compose file.  
* A public script.  
* A terminal transcript.  
* A diagnostic output.  
* A container inspection report.

The previous installation used `FTLCONF_webserver_api_password` as an environment variable. This is not an acceptable reason to repeat the old plaintext command.

Pi-hole documents `WEBPASSWORD_FILE` in conjunction with Docker Compose secrets.

However, compatibility with the selected rootless Podman setup must be tested before adopting that method.

### Required validation

Before container creation, confirm:

1. Whether the selected Pi-hole image supports the intended file-based password method.  
2. Whether Podman secrets expose the file at the expected location.  
3. Whether the secret remains readable by the Pi-hole startup process.  
4. Whether the secret is absent from ordinary container environment inspection.  
5. Whether logs reveal the password.  
6. Whether the configuration survives a container restart.

**Do not substitute an unverified secret-management method.**

If a secure method cannot be validated, stop at this stage and resolve credential handling before creating the production container.

---

## 9. Container configuration

The intended container configuration is:

| Setting | Intended value |
| ----- | ----- |
| Container name | `pihole` |
| Runtime | Rootless Podman |
| Image | Official Pi-hole image |
| Network | `pasta` |
| Privileged | Disabled |
| Persistent `/etc/pihole` | Required |
| Persistent `/etc/dnsmasq.d` | Preserved if required |
| DNS TCP | Host 53 → container 53 |
| DNS UDP | Host 53 → container 53 |
| HTTP administration | Host 8080 → container 80 |
| HTTPS administration | Host 8443 → container 443 |
| DHCP | Disabled |
| NTP server | Disabled |
| Automatic restart | Not enabled initially |
| Host network | Not used |

### Capability policy

The existing container has:

```text
Privileged=false
CapAdd=["CAP_NET_ADMIN"]
CapDrop=[]
```

This is an observed configuration, not a universal installation requirement.

Pi-hole's current documentation describes the purpose of its capabilities and notes that `NET_ADMIN` is primarily relevant to DHCP and related network functions.

For a fresh installation without DHCP, assess whether `NET_ADMIN` is actually required before adding it.

Do not automatically copy the existing capability set without reviewing the selected image version and intended features.

### Container creation

The final Podman creation command is intentionally not included in this draft.

It must be generated only after the following have been validated:

* Image version and digest.  
* Password secret handling.  
* Host port binding.  
* Required capabilities.  
* Persistent mounts.  
* Network mode.  
* Initial DNS configuration.

This prevents a copied command from silently reintroducing the old plaintext credential or unnecessary permissions.

---

## 10. Initial container verification

After the approved container creation procedure, inspect the result.

### Container state

```bash
podman ps -a --filter name=pihole
```

### Container identity

```bash
podman inspect --format \
'Name={{.Name}}
Image={{.ImageName}}
Status={{.State.Status}}
Privileged={{.HostConfig.Privileged}}' pihole
```

### Port mappings

```bash
podman port pihole
```

### Persistent mounts

```bash
podman inspect --format \
'{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}' pihole
```

### Capabilities

```bash
podman inspect --format \
'CapAdd={{json .HostConfig.CapAdd}}
CapDrop={{json .HostConfig.CapDrop}}
Privileged={{.HostConfig.Privileged}}
SecurityOpt={{json .HostConfig.SecurityOpt}}' pihole
```

Never dump the complete container environment into a terminal transcript or documentation.

---

## 11. DNS and administration testing

### 11.1 DNS listener

Inspect host-side listeners:

```bash
sudo ss -lntup | grep -E ':(53|8080|8443)([[:space:]]|$)'
```

Expected host bindings should match the intended LAN address and ports.

### 11.2 DNS query

From a LAN client:

```bash
nslookup example.com 192.168.1.161
```

Alternatively:

```bash
dig @192.168.1.161 example.com
```

A successful response confirms that the client can reach Pi-hole and receive a DNS response.

It does not independently prove that blocking is working.

### 11.3 Administration interface

The intended administration addresses are:

```text
http://192.168.1.161:8080/admin/
https://192.168.1.161:8443/admin/
```

Verify:

* The administration page loads.  
* Authentication is enabled.  
* The intended password works.  
* The Query Log is accessible.  
* DNS queries appear in the log.  
* The administration interface is not exposed beyond the intended network.

---

## 12. Lifecycle management

### 12.1 Initial policy

Do not enable automatic startup immediately after container creation.

First verify:

1. Manual container start.  
2. DNS resolution.  
3. Administration access.  
4. Persistent configuration.  
5. Manual container stop.  
6. Manual container restart.  
7. Data persistence after restart.

### 12.2 systemd user service

The existing installation uses:

```text
/home/deck/.config/systemd/user/pihole.service
```

The service waits for the expected Ethernet address and starts the existing container.

This service should be created only after the container has passed the initial tests.

Do not copy the existing unit unchanged without checking:

* Network interface name.  
* Expected IPv4 address.  
* Podman executable path.  
* Container name.  
* Startup timeout.  
* Shutdown timeout.

### 12.3 Automatic startup

Automatic startup requires a separate approval.

Before enabling it, verify:

* The service starts the existing container.  
* The service does not recreate it.  
* The Ethernet interface is ready before startup.  
* The service stops the correct container.  
* Shutdown and suspend behaviour are understood.  
* No duplicate lifecycle manager is active.

Do not enable both a custom systemd lifecycle and an independently configured restart mechanism without understanding their interaction.

---

## 13. Backup preparation

Before declaring the installation complete, establish a backup procedure.

At minimum, preserve:

```text
/home/deck/pihole-box/etc-pihole
/home/deck/pihole-box/etc-dnsmasq.d
```

Also record:

* Image reference and digest.  
* Container configuration.  
* Port mappings.  
* Capability configuration.  
* Sysctl configuration.  
* Firewall rules.  
* systemd unit.  
* Credential recovery procedure.

Do not include plaintext credentials in the backup manifest or Git repository.

The complete backup and restore procedure belongs in:

`BACKUP-AND-RECOVERY.md`

A backup is not considered verified until its contents can be inspected and a restoration procedure has been tested.

---

## 14. Installation completion checklist

* Host prerequisites verified.  
* Existing containers and data checked.  
* Rootless Podman confirmed.  
* Network interface and address confirmed.  
* Required ports inspected.  
* Persistent directories prepared.  
* Port 53 sysctl requirement assessed.  
* Firewall policy reviewed.  
* Pi-hole image version and digest recorded.  
* Credential handling validated.  
* Container created with approved configuration.  
* Privileged mode confirmed disabled.  
* Persistent mounts verified.  
* Port mappings verified.  
* DNS resolution tested.  
* Administration authentication tested.  
* Query Log verified.  
* Manual stop and restart tested.  
* Backup procedure established.  
* Automatic startup separately approved and tested.

---

## 15. Installation boundaries

The following actions require separate approval:

| Action | Approval |
| ----- | ----- |
| Create persistent directories | Yes |
| Change host sysctl | Yes |
| Modify firewall rules | Yes |
| Pull a new image | Yes |
| Create the container | Yes |
| Add capabilities | Yes |
| Create a systemd unit | Yes |
| Enable automatic startup | Yes |
| Change DNS upstreams | Yes |
| Enable DHCP | Yes |
| Delete or overwrite existing data | Explicit approval required |

This guide does not authorize modification of an existing Pi-hole installation.

---

## 16. Evidence and validation status

| Item | Status |
| ----- | ----- |
| Existing SteamOS architecture | Verified |
| Existing rootless Podman deployment | Verified |
| Existing pasta networking | Verified |
| Existing persistent mount locations | Verified |
| Existing host port-53 configuration | Verified |
| Existing firewall arrangement | Previously inspected |
| Fresh-install procedure | Draft |
| Fresh-install image digest policy | To validate |
| File-based password handling with Podman | To validate |
| Minimum required capabilities | To validate |
| Fresh-install container command | Not yet approved |
| systemd installation procedure | To validate |
| Backup restoration test | To verify |

---

## 17. Change history

| Version | Date | Description |
| ----- | ----- | ----- |
| 1.0-draft | 2026-11-03 | Initial installation guide based on the existing SteamOS architecture and current Pi-hole documentation |

---

**End of document**


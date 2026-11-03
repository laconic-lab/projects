# **Pi-hole on SteamOS — Architecture & Operations**

**Project:** Pi-hole on Steam Deck OLED  
**Repository:** `laconic-lab/projects`  
**Branch:** `main`  
**Document:** `pi-hole/PI-HOLE-STEAMOS-ARCHITECTURE.md`  
**Status:** Architecture inspected; documentation draft  
**Last reviewed:** 2026-11-03

---

## **1\. Purpose**

This document describes the architecture, configuration, operation, security boundaries and recovery procedures of the Pi-hole installation running on SteamOS.

The installation uses:

* SteamOS as the host operating system.  
* Distrobox as the environment for project-related tools and persistent data organisation.  
* Rootless Podman to run the Pi-hole container.  
* `pasta` networking to publish container services on the Steam Deck's LAN address.  
* `firewalld` to control network access.  
* A systemd user service to manage the container lifecycle.

This document is intended to be the authoritative technical reference for the existing installation.

### **Operating principles**

1. Diagnose before modifying.  
2. Prefer read-only inspection.  
3. Preserve existing Pi-hole configuration and databases.  
4. Do not recreate or delete containers as a routine troubleshooting measure.  
5. Keep Pi-hole and `pihole-box` protected from automated shutdown or cleanup.  
6. Do not expose credentials in terminal output, logs, documentation or Git.  
7. Do not introduce automatic startup or additional services without explicit approval.  
8. Verify changes after any approved modification.

---

## **2\. Architecture overview**

```
                         LOCAL LAN
                      192.168.1.0/24
                             |
                 +-----------+-----------+
                 |                       |
          Admin PC                 Steam Deck OLED
        192.168.1.169              192.168.1.161
                                         |
                                  SteamOS host
                                         |
                             Ethernet: enp4s0f3u1u4
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
                                  DNS :53
                                         |
                             Configured upstreams
                         Google / Cloudflare / Quad9
```

### **Component responsibilities**

| Component | Responsibility |
| ----- | ----- |
| SteamOS | Host operating system and network interfaces |
| Distrobox | Project environment and persistent data directories |
| Podman | Rootless container runtime |
| pasta | Container network connectivity and host port forwarding |
| firewalld | Host network access control |
| systemd user service | Pi-hole container startup and shutdown |
| Pi-hole FTL | DNS resolution, blocking and query processing |
| Pi-hole web server | Administration interface |

**Important:** Pi-hole continues to run independently of whether the `pihole-box` Distrobox is currently running. The container is managed by Podman on the host.

---

## **3\. Host environment**

### **3.1 Hardware and operating system**

| Property | Value |
| ----- | ----- |
| Device | Steam Deck OLED |
| Host OS | SteamOS |
| User | `deck` |
| User ID | `1000` |
| LAN IPv4 | `192.168.1.161` |
| Ethernet interface | `enp4s0f3u1u4` |
| LAN subnet | `192.168.1.0/24` |
| Admin PC | `192.168.1.169` |
| Time zone | `Europe/Paris` |

The Pi-hole installation uses the wired Ethernet connection.

### **3.2 Host-side storage**

Podman's rootless storage:

```
/home/deck/.local/share/containers/storage
```

Podman's runtime directory:

```
/run/user/1000/containers
```

The Pi-hole project data is stored separately from the Podman container storage.

---

## **4\. Distrobox environment**

### **4.1 Container**

| Property | Value |
| ----- | ----- |
| Distrobox name | `pihole-box` |
| Distribution | Arch Linux |
| Purpose | Project environment and data organisation |
| Current observed state | Exited |

### **4.2 Persistent data directories**

```
/home/deck/pihole-box/
├── etc-pihole/
└── etc-dnsmasq.d/
```

These directories are mounted into the Pi-hole container.

The Distrobox itself is not required to remain running for Pi-hole DNS service operation.

**Operational distinction:** stopping `pihole-box` does not mean stopping the Pi-hole Podman container.

Both the Distrobox and Pi-hole container are protected project components. Automated shutdown and cleanup operations must not remove or modify them.

---

## **5\. Podman container**

### **5.1 Container identity**

| Property | Value |
| ----- | ----- |
| Container name | `pihole` |
| Image | `docker.io/pihole/pihole:latest` |
| Runtime | Rootless Podman |
| Network mode | `pasta` |
| Privileged mode | Disabled |
| Restart policy | `unless-stopped` |
| Last inspected state | Running |
| Last inspected uptime | 43 hours |

The `latest` image tag is mutable. The exact image digest and installed Pi-hole version should be recorded separately when required for reproducibility.

### **5.2 Capabilities and security**

Last inspected configuration:

```
Privileged=false
CapAdd=["CAP_NET_ADMIN"]
CapDrop=[]
SecurityOpt=[]
```

Interpretation:

* The container is not running in privileged mode.  
* `CAP_NET_ADMIN` is explicitly added.  
* No explicit capability drops are configured.  
* No additional Podman security options are configured.

The presence of `CAP_NET_ADMIN` is a security-relevant permission and should be documented rather than silently removed. Any future capability change requires compatibility testing and explicit approval.

### **5.3 Persistent volume mounts**

| Host directory | Container directory | Mode |
| ----- | ----- | ----- |
| `/home/deck/pihole-box/etc-pihole` | `/etc/pihole` | Read/write |
| `/home/deck/pihole-box/etc-dnsmasq.d` | `/etc/dnsmasq.d` | Read/write |

These directories contain persistent configuration and DNS-related data.

Do not delete, recreate or overwrite them when troubleshooting container startup.

### **5.4 Container recreation**

The existing container is an established installation.

The following actions are not routine troubleshooting:

* `podman rm`  
* `podman rm -f`  
* `podman run --replace`  
* Removing Podman volumes  
* Recreating the container from an assumed configuration

Any recreation must first include a full inspection of the existing configuration, image, mounts, network settings, capabilities, environment variables and backups.

---

## **6\. Network architecture**

### **6.1 Published ports**

The container publishes the following services on the Steam Deck's LAN IPv4 address:

| Host address | Host port | Container port | Protocol | Purpose |
| ----- | ----- | ----- | ----- | ----- |
| `192.168.1.161` | 53 | 53 | TCP | DNS |
| `192.168.1.161` | 53 | 53 | UDP | DNS |
| `192.168.1.161` | 8080 | 80 | TCP | Web administration |
| `192.168.1.161` | 8443 | 443 | TCP | HTTPS administration |

Administration URLs:

```
http://192.168.1.161:8080/admin/
https://192.168.1.161:8443/admin/
```

The HTTP and HTTPS administration endpoints are published on the LAN address. Their access should remain subject to the host firewall and Pi-hole authentication.

### **6.2 Exposed versus published ports**

The Pi-hole image declares additional ports, including UDP 67 and UDP 123\.

The inspected Podman port mappings do not publish these ports to the host.

An image-declared or exposed container port is not equivalent to a published LAN service.

DHCP is not part of the current Pi-hole configuration.

### **6.3 pasta networking**

Podman uses `pasta` for container networking.

The host-side listener process has been observed as:

```
passt.avx2
```

It provides the host-side port forwarding for the Pi-hole container.

The inspected process listens on:

```
192.168.1.161:53       TCP / UDP
192.168.1.161:8080     TCP
192.168.1.161:8443     TCP
```

The host listeners are bound to the Deck's LAN IPv4 address.

### **6.4 Host DNS listeners**

`systemd-resolved` also listens on port 53, but only on loopback:

```
127.0.0.53:53
127.0.0.54:53
```

The Pi-hole forwarding listener uses:

```
192.168.1.161:53
```

These are different local addresses. The inspection did not show a direct listener conflict between `systemd-resolved` and the published Pi-hole LAN DNS service.

---

## **7\. Port 53 and unprivileged port binding**

The SteamOS host has the following sysctl setting:

```
net.ipv4.ip_unprivileged_port_start = 53
```

Persistent configuration:

```
/etc/sysctl.d/99-pihole.conf
```

Expected file content:

```
net.ipv4.ip_unprivileged_port_start=53
```

This allows processes without the traditional privileged-port restriction to bind ports beginning at 53\.

The setting is part of the existing rootless Podman networking arrangement.

**Security consideration:** this is a host-wide kernel setting, not a Pi-hole-only permission. It changes the privileged-port boundary for processes on the host. Do not change or remove it without first assessing the consequences for the existing networking configuration.

---

## **8\. Firewall configuration**

### **8.1 Firewall**

The host uses `firewalld`.

Last inspected state:

* Service running.  
* Active/default zone: `public`.  
* Ethernet interface: `enp4s0f3u1u4`.  
* Runtime and permanent configurations were consistent.

### **8.2 DNS access**

The LAN subnet is permitted to access DNS:

```
192.168.1.0/24
```

Allowed services:

```
TCP 53
UDP 53
```

The firewall also contains an SSH allowance for the administrative PC:

```
192.168.1.169/32
```

### **8.3 Other inspected firewall rules**

The previous audit identified:

* A source-specific rejection rule for TCP port 7011\.  
* Service `dhcpv6-client`.  
* TCP port range `1024-65535`.  
* UDP port range `1024-65535`.  
* Forwarding enabled.  
* Masquerading disabled.

The purpose and necessity of the broad port-range rules have not been established in this Pi-hole audit.

**Do not remove or alter them as part of Pi-hole maintenance.** They require a separate firewall investigation.

### **8.4 Firewall recovery**

The existing recovery script checks for `firewalld`, verifies the active zone and ensures the persistent LAN DNS rules exist.

It does not replace the entire firewall configuration.

---

## **9\. Lifecycle management**

### **9.1 systemd user service**

Unit:

```
/home/deck/.config/systemd/user/pihole.service
```

Observed configuration:

```
[Unit]
Description=Pi-hole container
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/bash -c 'until /usr/bin/ip -4 addr show dev enp4s0f3u1u4 | /usr/bin/grep -q "192.168.1.161/"; do /usr/bin/sleep 2; done; /usr/bin/sleep 5'
ExecStart=/usr/bin/podman start pihole
ExecStop=/usr/bin/podman stop --time 10 pihole
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

The startup precondition waits for the Ethernet interface to obtain the expected IPv4 address and then waits an additional five seconds.

### **9.2 Service behaviour**

| Setting | Meaning |
| ----- | ----- |
| `Type=oneshot` | Executes the start command and exits |
| `RemainAfterExit=yes` | Keeps the unit logically active after the start command exits |
| `ExecStart` | Starts the existing container |
| `ExecStop` | Stops the container with a 10-second grace period |
| `TimeoutStartSec=120` | Maximum startup duration |
| `TimeoutStopSec=30` | Maximum shutdown duration |

The unit's active state does not mean that a continuously running systemd process is supervising Pi-hole.

The container's actual state must be checked separately.

### **9.3 User linger**

Observed:

```
Linger=yes
```

This allows the user's systemd manager to remain active after logout.

The service is enabled under:

```
default.target
```

### **9.4 Podman restart policy**

The container reports:

```
RestartPolicy=unless-stopped
RestartRetries=0
```

However, the user-level Podman restart service was inspected as:

```
Loaded: loaded
Active: inactive (dead)
Enabled: disabled
```

The current documented startup mechanism is therefore the dedicated `pihole.service`.

The presence of the container restart policy should be recorded, but it must not be mistaken for proof that `podman-restart.service` is currently starting the container.

Do not alter either mechanism without testing the startup and shutdown sequence.

### **9.5 Manual lifecycle commands**

**Status**

```
systemctl --user status pihole.service --no-pager
podman ps --filter name=pihole
```

**Start**

```
systemctl --user start pihole.service
```

**Stop**

```
systemctl --user stop pihole.service
```

**Logs**

```
journalctl --user -u pihole.service -n 100 --no-pager
podman logs --tail 100 pihole
```

These commands are for intentional lifecycle operations. A status check should not be followed automatically by a start or stop operation.

---

## **10\. DNS configuration**

### **10.1 Upstream providers**

The inspected Pi-hole FTL upstream configuration contains:

| Provider | IPv4 | IPv6 |
| ----- | ----- | ----- |
| Google | `8.8.8.8`, `8.8.4.4` | `2001:4860:4860::8888`, `2001:4860:4860::8844` |
| Cloudflare | `1.1.1.1`, `1.0.0.1` | `2606:4700:4700::1111`, `2606:4700:4700::1001` |
| Quad9 | `9.9.9.9`, `149.112.112.112` | `2620:fe::fe`, `2620:fe::9` |

The configuration was read using:

```
podman exec pihole pihole-FTL --config dns.upstreams
```

The output confirms the configured addresses, not the current availability or performance of every upstream.

### **10.2 DNS operation**

Pi-hole FTL was previously observed:

* Listening on IPv4 and IPv6 port 53\.  
* Blocking enabled.  
* Database initialized.  
* Gravity loaded.

The historical query statistics are not a permanent baseline and should not be treated as current performance figures.

### **10.3 Blocklists**

Previously recorded configuration included:

* Firebog lists.  
* Hagezi lists.  
* Approximately 2,986,246 domains.

These are historical audit values. The current exact list contents and domain count should be retrieved from Pi-hole before publishing them as a live measurement.

Gravity updates are separate maintenance operations and are intentionally excluded from routine status and recovery checks.

---

## **11\. Persistent data and backup strategy**

### **11.1 Data preservation**

The persistent data directories are:

```
/home/deck/pihole-box/etc-pihole
/home/deck/pihole-box/etc-dnsmasq.d
```

They must be preserved during:

* Container restarts.  
* Distrobox shutdown.  
* Host maintenance.  
* Image updates.  
* Container troubleshooting.

### **11.2 Backup principles**

A valid backup should preserve:

* Pi-hole configuration.  
* DNS settings.  
* Blocklist configuration.  
* Gravity-related data where appropriate.  
* Custom dnsmasq configuration.  
* Relevant ownership and permissions.

Backups should be taken before modifying configuration, updating the image or performing recovery operations.

A backup should be verified before relying on it.

### **11.3 Do not assume container storage is the backup**

The Podman container's writable layer is not the primary persistent configuration store.

The two bind-mounted host directories are the important persistent data locations.

---

## **12\. Security considerations**

### **12.1 Credentials**

The container has an environment variable named:

```
FTLCONF_webserver_api_password
```

Its value is a secret and must never be printed, copied into documentation or committed to Git.

The password was exposed in an earlier terminal output. It must be considered compromised until rotated.

The rotation status has not been verified in this document.

Future inspection commands must display environment variable names only, never their values.

### **12.2 Container privileges**

Current inspected configuration:

* Rootless Podman.  
* Privileged mode disabled.  
* `CAP_NET_ADMIN` added.  
* No explicit capability drops.  
* No additional security options.

This is not equivalent to a fully hardened container. Security decisions must account for the actual capability set, mounts and network exposure.

### **12.3 Network exposure**

Pi-hole DNS is reachable on the LAN through TCP and UDP port 53\.

The web administration interfaces are published on ports 8080 and 8443\.

Firewall restrictions and Pi-hole authentication are therefore important parts of the security boundary.

### **12.4 No unnecessary permissions**

Do not introduce:

* Host filesystem mounts beyond documented requirements.  
* Host network mode.  
* Privileged container mode.  
* Additional capabilities without justification.  
* Unnecessary DHCP functionality.  
* Additional published ports.

Any proposed security change must be evaluated against the existing working installation.

---

## **13\. Installation architecture — historical reconstruction**

The original installation command was previously inspected.

Its architecture included:

* Rootless Podman.  
* The Pi-hole image.  
* TCP and UDP DNS port publication.  
* HTTP and HTTPS administration port publication.  
* Europe/Paris time zone.  
* Two persistent bind mounts.  
* `CAP_NET_ADMIN`.  
* `unless-stopped` restart policy.  
* `pasta` networking.

**The original command must not be copied directly into a new installation procedure.**

It included a plaintext credential in an environment variable. A safe replacement installation procedure must use a secure credential-management approach and must be validated against the current Pi-hole image documentation.

The installation procedure also requires explicit documentation of:

1. Distrobox creation and data-directory preparation.  
2. Rootless Podman prerequisites.  
3. Host port 53 configuration.  
4. Firewall configuration.  
5. Container creation.  
6. systemd user service installation.  
7. Persistent data verification.  
8. DNS and web-interface testing.  
9. Recovery preparation.

These steps should be reconstructed and validated before being published as a reproducible installation guide.

---

## **14\. Verification command reference**

All commands in this section are inspection-oriented unless explicitly indicated.

### **14.1 Container state**

```
podman ps --filter name=pihole
podman inspect --format \
'Name={{.Name}} Image={{.ImageName}} Status={{.State.Status}}' pihole
```

### **14.2 Port publication**

```
podman port pihole
sudo ss -lntup | grep -E ':(53|8080|8443)([[:space:]]|$)'
```

### **14.3 Persistent mounts**

```
podman inspect --format \
'{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}' pihole
```

### **14.4 Capability configuration**

```
podman inspect --format \
'CapAdd={{json .HostConfig.CapAdd}}
CapDrop={{json .HostConfig.CapDrop}}
Privileged={{.HostConfig.Privileged}}
SecurityOpt={{json .HostConfig.SecurityOpt}}' pihole
```

### **14.5 systemd state**

```
systemctl --user status pihole.service --no-pager
systemctl --user is-enabled pihole.service
loginctl show-user deck -p Linger
```

### **14.6 Firewall**

```
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=public --list-rich-rules
```

### **14.7 Port 53 sysctl**

```
sysctl net.ipv4.ip_unprivileged_port_start
cat /etc/sysctl.d/99-pihole.conf
```

### **14.8 DNS tests**

From a LAN client:

```
nslookup example.com 192.168.1.161
```

From the Steam Deck host, if `dig` is installed:

```
dig @192.168.1.161 example.com
```

A successful response confirms that the queried client can reach Pi-hole and receive a DNS response. It does not independently verify blocklist effectiveness.

---

## **15\. Recovery procedure**

### **15.1 Existing recovery script**

Repository location:

```
pi-hole/scripts/pihole-update-recovery.sh
```

Repository:

```
https://github.com/laconic-lab/projects
```

Raw script:

```
https://raw.githubusercontent.com/laconic-lab/projects/refs/heads/main/pi-hole/scripts/pihole-update-recovery.sh
```

The script is a recovery procedure for an existing installation. It is not an installation or container-recreation script.

### **15.2 Recovery script responsibilities**

The reviewed script:

1. Checks the existing Pi-hole container.  
2. Checks the host sysctl configuration.  
3. Verifies the required port 53 setting.  
4. Checks firewalld availability and its active zone.  
5. Ensures the persistent LAN DNS firewall rules exist.  
6. Reloads and verifies the firewall configuration.  
7. Checks the systemd service state.  
8. Starts the existing container if it is stopped.  
9. Verifies that the container is running.  
10. Provides administration and DNS test instructions.

It does not:

* Recreate or remove the container.  
* Delete persistent Pi-hole data.  
* Replace the Pi-hole database.  
* Change upstream DNS providers.  
* Perform a Gravity update.  
* Restore an old `.env` file.  
* Rebuild the Distrobox.

### **15.3 Recovery safety**

Before running recovery:

* Confirm that the existing container is still present.  
* Confirm that persistent directories exist.  
* Inspect the script version.  
* Review any proposed firewall changes.  
* Ensure the credential is not exposed in terminal output.

Recovery should preserve the current installation rather than rebuild it unnecessarily.

---

## **16\. Known observations and troubleshooting**

### **16.1 pasta UDP-flow warning**

A previous journal inspection showed warnings similar to:

```
Couldn't open flow specific socket: Address already in use
```

The affected traffic involved outgoing UDP DNS packets to configured upstream resolvers.

The previous source port was `55893`, within the host ephemeral range:

```
32768–60999
```

A later socket inspection found no current socket using that source port.

The latest service journal query did not reproduce the warning.

**Classification:** historical/intermittent; exact cause unconfirmed.

No change to upstream DNS, ephemeral port range or published port mappings is justified by the available evidence.

### **16.2 Cloudflare IPv6 warning**

A previous Pi-hole log reported a TCP connection warning involving:

```
2620:fe::fe
```

This address is one of the configured Quad9 IPv6 upstream addresses, not Cloudflare. The historical warning should therefore be attributed to the address itself rather than assumed to be a Cloudflare issue.

The warning alone does not establish a persistent DNS failure.

### **16.3 Clock and database observations**

A previous database import warning showed timestamps that differed by several hours.

A subsequent host/container clock comparison found their clocks aligned, with the host reporting synchronization enabled.

The historical database timestamp discrepancy remains unexplained.

The database was not deleted or rebuilt.

### **16.4 Container capabilities**

The container lacks `CAP_SYS_TIME` and `CAP_SYS_NICE`.

Previous logs showed related warnings.

These permissions have not been added. No evidence has established that they are required for normal DNS operation.

### **16.5 systemd-resolved**

The host's local DNS resolver listens on loopback only. The Pi-hole published listener uses the LAN IPv4 address.

No port conflict was found during the latest listener inspection.

---

## **17\. Operational boundaries**

The following actions require separate diagnosis and explicit approval:

| Action | Approval required |
| ----- | ----- |
| Restart Pi-hole | Yes |
| Stop Pi-hole | Yes |
| Update Pi-hole image | Yes |
| Recreate container | Yes |
| Delete container | Yes |
| Delete persistent data | Yes |
| Change upstream DNS | Yes |
| Change firewall rules | Yes |
| Change sysctl settings | Yes |
| Change capabilities | Yes |
| Change systemd lifecycle | Yes |
| Rotate API password | Yes |
| Update Gravity | Yes |

Routine read-only status checks do not require a configuration change.

Pi-hole and `pihole-box` must remain protected from automated cleanup and shutdown procedures.

---

## **18\. Evidence and maintenance status**

This document separates observed facts from historical records and unresolved questions.

| Item | Evidence status |
| ----- | ----- |
| SteamOS host and LAN address | Verified |
| Distrobox identity and data directories | Verified |
| Rootless Podman container | Verified |
| Container image and restart policy | Verified |
| Container capabilities | Verified |
| Persistent bind mounts | Verified |
| pasta host-side listeners | Verified |
| Published ports | Verified |
| Host DNS listeners | Verified |
| systemd lifecycle | Verified |
| User linger | Verified |
| Firewall DNS rules | Previously inspected |
| Upstream DNS addresses | Verified |
| Exact image digest | To verify |
| Current Pi-hole version | To verify |
| Current blocklist domain count | To verify |
| API password rotation | Outstanding / not verified |
| Exact cause of pasta UDP warning | Unresolved |
| Purpose of broad firewall port ranges | To investigate separately |
| Reproducible installation procedure | To reconstruct and validate |
| Backup restoration test | To verify |

---

## **19\. Change history**

| Version | Date | Description |
| ----- | ----- | ----- |
| 1.0 | 2026-11-03 | Initial architecture documentation draft based on read-only inspection and historical recovery records |

---

**End of document**


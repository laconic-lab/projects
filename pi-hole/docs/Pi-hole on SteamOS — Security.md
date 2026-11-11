# Pi-hole on SteamOS — Security

**Document:** `pi-hole/docs/SECURITY.md`  
**Status:** Draft — review required  
**Scope:** Rootless Podman Pi-hole deployment on SteamOS  
**Last reviewed:** 2026-11-03

## Contents

- [1. Purpose](#1-purpose)
- [2. Architecture and trust boundaries](#2-architecture-and-trust-boundaries)
- [3. Confirmed security configuration](#3-confirmed-security-configuration)
- [4. Container privilege and capabilities](#4-container-privilege-and-capabilities)
- [5. Host-wide low-port setting](#5-host-wide-low-port-setting)
- [6. Network exposure and firewall](#6-network-exposure-and-firewall)
- [7. Persistent data and filesystem access](#7-persistent-data-and-filesystem-access)
- [8. Credentials and secrets](#8-credentials-and-secrets)
- [9. Service lifecycle and automatic startup](#9-service-lifecycle-and-automatic-startup)
- [10. Updates and image integrity](#10-updates-and-image-integrity)
- [11. Logging and diagnostics](#11-logging-and-diagnostics)
- [12. Threat assessment](#12-threat-assessment)
- [13. Security verification checklist](#13-security-verification-checklist)
- [14. Approval boundaries](#14-approval-boundaries)
- [15. Outstanding security items](#15-outstanding-security-items)
- [16. References](#16-references)
- [Change history](#change-history)

## 1. Purpose

This document defines the security boundaries, known risks, and operational safeguards for the Pi-hole deployment on the Steam Deck.

The objective is to provide LAN DNS filtering without unnecessarily expanding access to the SteamOS host, user files, credentials, or unrelated projects.

Security decisions follow these principles:

* Least privilege.  
* Read-only inspection before modification.  
* LAN-only network exposure.  
* No unnecessary host filesystem access.  
* No privileged container.  
* No credential exposure in commands, logs, or documentation.  
* Manual and controlled maintenance.  
* Explicit approval before security-sensitive changes.

This is a deployment-specific security record, not a guarantee that the container or host is immune to compromise.

## 2. Architecture and trust boundaries

```text
                 LAN: 192.168.1.0/24
                          |
              +-----------+-----------+
              |                       |
         Admin PC                Other LAN clients
       192.168.1.169                  |
              |                       |
       Admin interface                 DNS
       TCP 8080 / 8443              TCP/UDP 53
              |                       |
              +-----------+-----------+
                          |
                  Steam Deck host
                  SteamOS / deck
                          |
                  Rootless Podman
                          |
                    Pi-hole
                   container
                          |
              +-----------+-----------+
              |                       |
          /etc/pihole            /etc/dnsmasq.d
              |                       |
              +-----------+-----------+
                          |
                 Persistent host data
```

### Trust boundaries

| Component | Trust classification | Security boundary |
| ----- | ----- | ----- |
| SteamOS host | High trust | Must not be unnecessarily exposed to the container |
| `deck` account | Host user | Container runs rootless under this account |
| Podman runtime | Container boundary | Limits container access, but does not eliminate host risk |
| Pi-hole container | Lower trust than host | Should receive only required capabilities and mounts |
| Persistent Pi-hole data | Sensitive application data | Must be protected against unauthorized access and accidental deletion |
| LAN clients | Partially trusted | DNS service is available to the LAN |
| Admin PC | Administrative endpoint | Web administration should be restricted to trusted LAN access |

The Distrobox named `pihole-box` is used for project organisation and data storage. Its presence does not mean that the Distrobox must be running for the Podman container to operate.

## 3. Confirmed security configuration

The following reflects the documented deployment state. It should be rechecked before significant changes.

| Control | Documented state | Assessment |
| ----- | ----- | ----- |
| Container execution | Rootless Podman | Positive |
| Privileged mode | Disabled | Positive |
| Container network | Rootless `pasta` | Positive |
| Host networking | Not used | Positive |
| DHCP | Disabled | Reduces required network privileges |
| Persistent storage | Two dedicated Pi-hole directories | Positive, subject to permissions review |
| DNS exposure | Bound to Deck LAN address | LAN-scoped |
| Admin interface | TCP 8080 and 8443 on Deck LAN address | Requires trusted-LAN firewall protection |
| Host port restriction | `net.ipv4.ip_unprivileged_port_start=53` | Host-wide security consideration |
| Automatic restart | Container restart policy documented as `unless-stopped` | Review against manual lifecycle preference |
| Container capabilities | `CAP_NET_ADMIN` added | Requires justification and testing |
| Firewall | `firewalld`, public zone | Rules and exposure require continued review |
| API password | Previously exposed in terminal output | Treat as compromised until rotated |

A documented setting is not proof that the current live system still has that setting. Verify the active state before relying on it.

## 4. Container privilege and capabilities

### 4.1 Rootless execution

The container is intended to run as a rootless Podman container under the `deck` account.

Rootless execution reduces the consequences of container compromise compared with a privileged container running as host root. It does not provide complete isolation from the host user or from resources deliberately made available to the container.

Do not change the deployment to:

* `privileged: true`  
* Host network mode  
* Host PID or IPC namespaces without a documented requirement  
* A host Docker or Podman socket mount  
* Broad host filesystem mounts  
* Unrestricted host device access

### 4.2 `CAP_NET_ADMIN`

The current deployment adds `CAP_NET_ADMIN`.

This capability is powerful because it permits network administration operations within the container's applicable network context. It should not be retained merely because it appears in an example configuration.

Pi-hole's official Docker documentation identifies `NET_ADMIN` as required for DHCP functionality. DHCP is disabled in this deployment. However, the exact minimum capability set for this particular rootless Podman and `pasta` configuration has not been established.

**Required action before changing capabilities:**

1. Inspect the current container capability set.  
2. Review the current Pi-hole image documentation.  
3. Establish which capabilities are actually required for DNS-only operation.  
4. Test any proposed reduction without removing the existing working configuration prematurely.  
5. Verify DNS, web administration, and container health after an approved change.

Do not remove capabilities based only on assumptions.

Reference: [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)

## 5. Host-wide low-port setting

The host uses:

```text
net.ipv4.ip_unprivileged_port_start=53
```

This permits unprivileged processes to bind ports starting at 53, rather than the usual lower boundary of 1024\.

This is a host-wide kernel setting, not a container-only setting. It changes the binding restrictions for unprivileged processes on the Steam Deck.

Security implications:

* It is broader than a Pi-hole-specific permission.  
* Other unprivileged processes may also be able to bind ports below 1024\.  
* The setting should not be assumed to be harmless simply because Pi-hole requires DNS port 53\.  
* Its persistence is configured through `/etc/sysctl.d/99-pihole.conf`.

The setting's continued necessity should be reviewed against the current Podman networking configuration.

Do not remove or alter it without first establishing whether the current DNS port publishing method still depends on it.

## 6. Network exposure and firewall

### 6.1 Published ports

The documented service bindings are:

| Host address | Protocol | Purpose |
| ----- | ----- | ----- |
| `192.168.1.161:53` | TCP | DNS |
| `192.168.1.161:53` | UDP | DNS |
| `192.168.1.161:8080` | TCP | HTTP administration |
| `192.168.1.161:8443` | TCP | HTTPS administration |

The DNS service is intended for LAN clients. The administration interface is intended for trusted administration from the LAN.

Do not bind these services to `0.0.0.0` or expose them to the public internet without a separate security assessment.

### 6.2 Firewall policy

The documented firewall uses `firewalld`, with the Ethernet interface in the `public` zone.

The documented Pi-hole DNS rules restrict TCP and UDP port 53 to the LAN subnet.

Security requirements:

* Keep DNS access restricted to the intended LAN.  
* Keep administrative access restricted to trusted devices or a suitably narrow trusted network.  
* Do not add broad inbound rules to solve an isolated connectivity problem.  
* Inspect existing rules before adding duplicates.  
* Verify the active zone and interface before changing firewall rules.

The architecture record also identifies broad TCP and UDP port ranges from 1024 to 65535\. Their purpose is not established in the current documentation.

**Unresolved:** Investigate those broad rules before treating the firewall as fully reviewed. Do not remove them without first identifying their origin and purpose.

### 6.3 No public DNS exposure

The deployment is not intended to operate as an internet-accessible open resolver.

Do not configure router port forwarding for Pi-hole DNS or its administration interface.

## 7. Persistent data and filesystem access

The container uses two persistent host directories:

```text
/home/deck/pihole-box/etc-pihole
    -> /etc/pihole

/home/deck/pihole-box/etc-dnsmasq.d
    -> /etc/dnsmasq.d
```

Both are mounted read/write because Pi-hole needs to maintain its configuration and application data.

Security requirements:

* Keep mounts limited to these application directories.  
* Do not mount all of `/home/deck`.  
* Do not mount `/home/deck/.ssh`, `.config`, browser profiles, or unrelated project directories.  
* Do not expose Steam credentials, browser credential databases, or other application secrets.  
* Preserve the existing data directories during container replacement or image updates.  
* Inspect ownership and permissions before changing them.

The Distrobox directory name does not grant the container permission to access the entire Distrobox or host home directory.

## 8. Credentials and secrets

### 8.1 API password exposure

The Pi-hole API/web password was previously exposed in terminal output.

**Security classification: compromised until rotation is verified.**

The current rotation status is not confirmed. Do not assume that the password is safe merely because it is no longer displayed.

Required actions:

1. Confirm whether the password has been rotated.  
2. If not, plan a controlled rotation.  
3. Verify that the new credential works.  
4. Avoid displaying it in terminal output, screenshots, logs, or documentation.  
5. Do not copy the credential into GitHub.

Do not include the password itself in this document.

### 8.2 Environment variables and inspection output

Pi-hole supports environment-based configuration, including `FTLCONF_webserver_api_password`.

Environment variables can be visible through container inspection and may appear in diagnostic output. Avoid commands that print the complete container environment when investigating configuration.

Pi-hole documentation also describes `WEBPASSWORD_FILE` in the context of Docker Compose or Docker Swarm secrets.

That does not by itself establish that a particular Podman secret implementation is compatible with the selected image and configuration.

**Unresolved:** Validate the intended secret-delivery mechanism before changing the current credential configuration. Do not claim that Podman secrets work with this deployment until tested.

Reference: [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)

### 8.3 Credential handling rules

* Never place real credentials in GitHub documentation.  
* Never paste API passwords or provider keys into shared command transcripts.  
* Do not include secrets in diagnostic bundles.  
* Avoid logging complete environment variables.  
* Restrict permissions on any local secret files.  
* Back up secrets only through a separately reviewed and protected process.

## 9. Service lifecycle and automatic startup

The architecture record documents a user-level systemd unit named `pihole.service`, with linger enabled.

The container's documented restart policy is `unless-stopped`.

These are separate mechanisms and should not be confused:

* Podman restart policy governs container restart behaviour.  
* The user systemd unit starts and stops the container through a host service.  
* User lingering permits user services to operate independently of an active login session.

For future changes, the preferred operational policy is controlled and deliberate lifecycle management.

Do not introduce additional startup mechanisms or duplicate service definitions.

Before changing startup behaviour, inspect:

* The current container restart policy.  
* The user systemd unit.  
* The unit's enabled state.  
* Whether another service is already managing the container.

Any change to automatic startup or restart behaviour requires explicit approval.

## 10. Updates and image integrity

The documented container image is:

```text
docker.io/pihole/pihole:latest
```

A mutable tag such as `latest` can refer to different image versions over time.

Security and operational risks include:

* Unexpected application changes.  
* Configuration behaviour changes.  
* New vulnerabilities or regressions.  
* Difficulty reproducing a previous deployment.

Recommended update procedure:

1. Inspect the currently running image and version.  
2. Review the upstream release notes.  
3. Identify the proposed image version or digest.  
4. Confirm that persistent data is backed up.  
5. Review configuration and capability changes.  
6. Obtain approval before pulling or replacing the running image.  
7. Verify service operation after the update.

Do not combine an image update with unrelated firewall, sysctl, capability, or data-directory changes.

Official image documentation: [https\://docs.pi-hole.net/docker/](https://docs.pi-hole.net/docker/)

## 11. Logging and diagnostics

Logs can contain operational details and may expose configuration or credentials if commands are used carelessly.

Diagnostic requirements:

* Do not publish unredacted environment output.  
* Do not share API passwords, tokens, or secret file contents.  
* Review command output before attaching it to an issue or repository.  
* Prefer targeted inspection over complete container dumps.  
* Preserve relevant error messages while redacting sensitive values.

A command that appears to be a status check can still disclose secrets. Treat inspection output as potentially sensitive.

## 12. Threat assessment

| Threat | Existing mitigation | Remaining concern |
| ----- | ----- | ----- |
| Container compromise | Rootless Podman, non-privileged container | Container still has access to mounted application data |
| Excessive container privileges | Privileged mode disabled | `CAP_NET_ADMIN` needs review |
| Host filesystem exposure | Dedicated persistent mounts | Must verify actual mounts and permissions |
| Unauthorized DNS use | LAN-bound service and firewall rules | Confirm rules remain LAN-restricted |
| Unauthorized administration | LAN-bound admin ports | Confirm firewall restrictions and password rotation |
| Credential disclosure | No credentials in documentation | Previously exposed password remains a rotation concern |
| Host port binding exposure | Host sysctl permits unprivileged low ports | Host-wide scope requires review |
| Unexpected service startup | Existing systemd and restart mechanisms documented | Multiple lifecycle mechanisms need coordination |
| Unreviewed firewall exposure | `firewalld` active | Broad high-port rules remain unexplained |
| Malicious or faulty update | Persistent data and manual review process | Mutable `latest` tag reduces reproducibility |

## 13. Security verification checklist

Run checks as read-only inspections first. Do not modify the system merely because a check reports a difference.

* Confirm container is rootless.  
* Confirm privileged mode is disabled.  
* Confirm host networking is not used.  
* Inspect actual published port bindings.  
* Inspect actual persistent mounts.  
* Inspect container capabilities.  
* Confirm DHCP remains disabled.  
* Verify firewall zone and Ethernet interface.  
* Verify DNS rules are limited to the intended LAN.  
* Identify the purpose of broad TCP/UDP port-range rules.  
* Verify the low-port sysctl value and its persistence.  
* Verify the current image version or digest.  
* Confirm the API password has been rotated.  
* Verify that credentials are not exposed in logs or diagnostic output.  
* Review systemd and Podman restart behaviour.  
* Confirm that no unrelated host directories or credentials are mounted.

## 14. Approval boundaries

The following actions require explicit approval before execution:

* Changing container capabilities.  
* Changing container privilege or namespace configuration.  
* Changing published network ports.  
* Modifying firewall rules.  
* Modifying host sysctl settings.  
* Changing persistent mount paths or permissions.  
* Rotating credentials.  
* Changing image versions or replacing the container.  
* Changing systemd startup or restart behaviour.  
* Deleting, recreating, or restoring persistent Pi-hole data.

Read-only inspection and documentation review may be performed first.

## 15. Outstanding security items

| Item | Status |
| ----- | ----- |
| API password rotation | Not verified |
| Minimum capability set for DNS-only operation | Not established |
| Purpose of broad TCP/UDP firewall ranges | Unknown |
| Need for host-wide low-port sysctl | Requires review |
| Podman secret compatibility with selected Pi-hole image | Not tested |
| Current image digest and update policy | Requires verification |
| Current filesystem ownership and permissions | Requires live inspection |
| Current firewall and container state | Must be rechecked before changes |

These items must remain visible as unresolved until supported by evidence.

## 16. References

* Pi-hole Docker documentation: [https\://docs.pi-hole.net/docker/](https://docs.pi-hole.net/docker/)  
* Pi-hole Docker configuration: [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)  
* Pi-hole FTL configuration: [https\://docs.pi-hole.net/ftldns/configfile/](https://docs.pi-hole.net/ftldns/configfile/)  
* Podman documentation: [https\://docs.podman.io/](https://docs.podman.io/)

## Change history

| Date | Change |
| ----- | ----- |
| 2026-11-03 | Initial security documentation draft based on the documented SteamOS deployment and identified unresolved risks. |


# **Pi-hole on SteamOS — Troubleshooting**

**Document:** `pi-hole/docs/TROUBLESHOOTING.md`  
**Status:** Draft — review required  
**Scope:** Rootless Podman Pi-hole deployment on SteamOS  
**Last reviewed:** 2026-11-03

## **1\. Purpose**

This document provides a diagnosis-first procedure for common Pi-hole failures on SteamOS.

The objective is to identify the failing layer before making changes.

The deployment contains several independent components:

```
LAN client
    |
    v
Steam Deck Ethernet
    |
    v
SteamOS firewall
    |
    v
Host port publishing / Podman networking
    |
    v
Pi-hole container
    |
    v
Pi-hole FTL / DNS service
    |
    v
Configured upstream DNS
```

A failure at one layer should not automatically trigger changes to another.

## **2\. Troubleshooting rules**

1. Start with read-only inspection.  
2. Identify whether the issue affects one client or the entire LAN.  
3. Distinguish DNS failure from web administration failure.  
4. Inspect host, container, and Distrobox separately.  
5. Do not assume that `pihole-box` must be running.  
6. Do not restart a working service merely to collect information.  
7. Do not update Gravity as a generic troubleshooting step.  
8. Do not change upstream DNS without evidence.  
9. Do not delete or recreate persistent data to resolve an unknown problem.  
10. Obtain explicit approval before changes to firewall, sysctl, capabilities, container configuration, or persistent data.

## **3\. Deployment reference**

| Item | Documented value |
| ----- | ----- |
| Host | Steam Deck OLED / SteamOS |
| Host user | `deck` |
| Host LAN address | `192.168.1.161` |
| Ethernet interface | `enp4s0f3u1u4` |
| LAN subnet | `192.168.1.0/24` |
| Admin PC | `192.168.1.169` |
| Container | `pihole` |
| Distrobox | `pihole-box` |
| DNS TCP | `192.168.1.161:53` |
| DNS UDP | `192.168.1.161:53` |
| HTTP administration | `http://192.168.1.161:8080/admin/` |
| HTTPS administration | `https://192.168.1.161:8443/admin/` |
| Container network | Rootless Podman / `pasta` |
| Firewall | `firewalld` |
| User service | `pihole.service` |

These are documented reference values. Verify the live configuration before using them.

## **4\. Initial diagnostic collection**

### **4.1 Host network**

**STEAM DECK — host SSH**

```
echo "===== HOST ADDRESS ====="
ip -br addr

echo
echo "===== HOST INTERFACES ====="
ip -br link

echo
echo "===== ROUTING ====="
ip route

echo
echo "===== DNS LISTENERS ====="
sudo ss -lntup | grep -E '(:53|:8080|:8443)\b'
```

Check:

* Ethernet interface is present and UP.  
* Expected LAN address is assigned.  
* Default route exists.  
* DNS and administration listeners are bound to the expected addresses.  
* No unexpected process is occupying the required ports.

Do not assume that a listener on loopback is a conflict with a listener bound to the LAN address.

### **4.2 Container state**

```
echo "===== CONTAINER STATUS ====="
podman ps -a --filter name=pihole

echo
echo "===== CONTAINER STATE ====="
podman inspect pihole \
  --format '{{.State.Status}}'

echo
echo "===== PORT BINDINGS ====="
podman port pihole

echo
echo "===== PERSISTENT MOUNTS ====="
podman inspect pihole \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

These checks should not print the complete container environment or secrets.

### **4.3 Firewall state**

```
echo "===== FIREWALL STATUS ====="
sudo firewall-cmd --state

echo
echo "===== ACTIVE ZONES ====="
sudo firewall-cmd --get-active-zones

echo
echo "===== PUBLIC ZONE ====="
sudo firewall-cmd --zone=public --list-all
```

Verify that the expected Ethernet interface belongs to the intended zone and that DNS access is appropriately restricted.

Do not modify rules during initial diagnosis.

### **4.4 Service state**

```
echo "===== USER SERVICE ====="
systemctl --user status pihole.service --no-pager

echo
echo "===== USER SERVICE ENABLEMENT ====="
systemctl --user is-enabled pihole.service
```

A systemd service status and a container status are related but not interchangeable.

## **5\. DNS troubleshooting**

### **Symptom A — No DNS resolution**

Possible causes:

* Pi-hole container is stopped.  
* FTL is not responding.  
* Host port publishing is missing.  
* Firewall blocks TCP or UDP 53\.  
* Host LAN address changed.  
* Client is using another DNS server.  
* Upstream DNS is unavailable.

#### **Step 1 — Test locally on the Deck**

```
dig @192.168.1.161 example.com
```

If `dig` is unavailable, use an already installed DNS diagnostic tool. Do not install packages as part of initial diagnosis.

#### **Step 2 — Test from the LAN admin PC**

```
nslookup example.com 192.168.1.161
```

Compare the results.

| Deck test | Admin PC test | Likely investigation area |
| ----- | ----- | ----- |
| Fails | Fails | Container, FTL, listener, or upstream |
| Works | Fails | Firewall, network path, or host port publishing |
| Works | Works | Investigate affected client configuration |
| Fails | Works | Local host test environment or local resolver behaviour |

A successful DNS response does not alone prove that Pi-hole filtering is active. Check the Pi-hole query log separately.

### **Symptom B — DNS works but filtering does not**

Possible causes:

* Client is not using the Pi-hole DNS server.  
* Client uses encrypted DNS or another configured resolver.  
* The queried domain is not on an active blocking list.  
* The domain is allowlisted.  
* The query is cached.  
* Pi-hole blocking is disabled.

Checks:

1. Confirm the DNS server configured on the client.  
2. Inspect the Pi-hole query log.  
3. Confirm the client query reaches Pi-hole.  
4. Inspect the domain's response and blocking status.  
5. Review allowlist and blocking settings.

Do not update Gravity simply because one domain is not blocked.

### **Symptom C — Intermittent DNS failures**

Possible causes:

* Network instability.  
* Container restart or service interruption.  
* Upstream DNS latency or unavailability.  
* Client-side DNS caching.  
* UDP transport problems.  
* Port publishing or firewall inconsistencies.

Collect timestamps and compare:

* Pi-hole query log.  
* Container logs.  
* Container restart history.  
* Host network state.  
* Upstream response behaviour.

Do not change the ephemeral port range or networking backend without evidence.

## **6\. Web administration troubleshooting**

### **Symptom A — Administration page unavailable**

Expected addresses:

```
http://192.168.1.161:8080/admin/
https://192.168.1.161:8443/admin/
```

Possible causes:

* Container stopped.  
* Web server or FTL unavailable.  
* Port publishing changed.  
* Firewall blocks the connection.  
* Host address changed.  
* Browser or certificate issue.

Checks:

```
podman ps -a --filter name=pihole

podman port pihole

sudo ss -lntp | grep -E '(:8080|:8443)\b'
```

From Windows PowerShell:

```
Test-NetConnection 192.168.1.161 -Port 8080
Test-NetConnection 192.168.1.161 -Port 8443
```

Interpret the result:

* Both ports fail: inspect container state, bindings, firewall, and host address.  
* HTTP works, HTTPS fails: investigate the HTTPS listener and certificate configuration.  
* Both ports work but the page fails: investigate the web application and browser response.

Do not expose the administration interface to the internet as a workaround.

### **Symptom B — Login fails**

Possible causes:

* Incorrect password.  
* Password changed.  
* Credential configuration differs from the expected configuration.  
* Authentication configuration issue.

Do not paste passwords into diagnostic commands or transcripts.

Remember that the previously exposed API password must be treated as compromised until rotation has been verified.

## **7\. Container troubleshooting**

### **Symptom A — Container is exited**

First inspect:

```
podman ps -a --filter name=pihole

podman inspect pihole \
  --format '{{.State.Status}} {{.State.ExitCode}}'
```

Inspect recent logs:

```
podman logs --tail 100 pihole
```

Look for:

* Configuration errors.  
* Permission errors.  
* Port binding errors.  
* Database problems.  
* Network initialization failures.  
* Application startup failures.

Do not immediately remove and recreate the container.

### **Symptom B — Container repeatedly restarts**

Inspect:

```
podman ps -a --filter name=pihole

podman logs --tail 150 pihole

podman inspect pihole \
  --format '{{.HostConfig.RestartPolicy.Name}}'
```

Investigate the first relevant error rather than repeatedly restarting the service.

Do not disable restart behaviour or modify systemd until the actual restart mechanism is identified.

### **Symptom C — Persistent data permission errors**

Inspect:

```
stat -c '%A %U:%G %n' \
  /home/deck/pihole-box/etc-pihole \
  /home/deck/pihole-box/etc-dnsmasq.d
```

Check:

* Ownership.  
* Directory permissions.  
* File permissions.  
* Whether the expected host directories are mounted.  
* Whether the container's runtime UID/GID expectations changed.

Do not apply recursive ownership changes without understanding the existing ownership and container user mapping.

## **8\. Host networking troubleshooting**

### **Symptom A — Port 53 cannot be published**

Inspect:

```
sysctl net.ipv4.ip_unprivileged_port_start

sudo ss -lntup | grep -E '(:53)\b'

podman port pihole
```

Possible causes:

* Host port 53 is already occupied.  
* Low-port binding policy changed.  
* Rootless networking configuration changed.  
* Container port publishing failed.  
* Host network service behaviour changed.

The documented host setting is:

```
net.ipv4.ip_unprivileged_port_start=53
```

This setting is host-wide. Do not change it merely because a port-binding error appears.

Identify the process holding the port and determine whether the conflict is real before proposing a change.

### **Symptom B — DNS listener appears on loopback**

The host has historically used `systemd-resolved` listeners on:

```
127.0.0.53:53
127.0.0.54:53
```

A loopback-only listener does not automatically conflict with Pi-hole bound to:

```
192.168.1.161:53
```

Inspect the actual address and protocol bindings before concluding that port 53 is occupied.

### **Symptom C — `pasta` UDP warning**

A historical warning was observed:

```
Couldn't open flow specific socket: Address already in use
```

Its cause was not established.

Do not assume this warning proves DNS failure.

Investigate:

* Whether DNS queries actually fail.  
* Whether the warning repeats.  
* Whether the container is restarting.  
* Whether another process is using the relevant socket.  
* Whether the warning is associated with a specific traffic flow.

Do not change the ephemeral port range or replace the networking backend without reproducible evidence.

## **9\. Firewall troubleshooting**

The documented firewall uses `firewalld` and the `public` zone.

Inspect:

```
sudo firewall-cmd --state

sudo firewall-cmd --get-active-zones

sudo firewall-cmd --zone=public --list-all

sudo firewall-cmd --list-all-zones
```

Check:

* Correct Ethernet interface.  
* Correct active zone.  
* LAN-restricted DNS rules.  
* Correct protocol and destination port.  
* Unexpected duplicate rules.  
* Unexpected broad port ranges.

The architecture record identifies broad TCP and UDP ranges from 1024 to 65535 whose purpose remains unknown.

Do not remove them during routine Pi-hole troubleshooting. Investigate their origin separately.

## **10\. Upstream DNS troubleshooting**

If clients can reach Pi-hole but external names fail to resolve, investigate upstream DNS.

Possible causes:

* Upstream resolver unavailable.  
* Network connectivity failure.  
* DNS forwarding issue.  
* IPv4 or IPv6 routing problem.  
* Incorrect upstream configuration.

Inspect the configured upstreams through the Pi-hole administration interface or targeted configuration inspection.

The documented historical configuration included Google, Cloudflare, and Quad9 resolvers over IPv4 and IPv6. Confirm the live settings before relying on that list.

Important distinction:

```
2620:fe::fe
```

is a Quad9 IPv6 resolver address, not a Cloudflare address.

Do not change upstreams merely because a single query fails. Establish whether the failure is repeatable and whether it affects one resolver or all configured upstreams.

## **11\. Distrobox troubleshooting**

The Distrobox `pihole-box` is not the Podman container.

Its state can be inspected independently:

```
distrobox list

podman ps -a --filter name=pihole
```

A stopped Distrobox does not necessarily indicate that Pi-hole is stopped.

Do not enter, start, recreate, or delete the Distrobox as a generic Pi-hole troubleshooting step.

The persistent data directories are host paths used by the container. Their availability must be checked directly.

## **12\. Recovery script warning**

The repository script:

`pi-hole/scripts/pihole-update-recovery.sh`

is not a read-only diagnostic script.

It can:

* Create or restore the host sysctl configuration.  
* Apply a host sysctl value.  
* Add persistent firewalld rules.  
* Reload firewalld.  
* Start the existing Pi-hole container or service.

It does not back up application data or rebuild a deleted container.

Review the script before execution. Do not use it as the first step in diagnosing an unknown failure.

## **13\. Escalation and change control**

If read-only diagnosis does not identify the problem:

1. Record the exact symptom.  
2. Record the time and affected client.  
3. Collect relevant host and container status.  
4. Capture only relevant log lines.  
5. Redact credentials and sensitive information.  
6. Identify the failing layer.  
7. Propose the smallest corrective action.  
8. Obtain approval before modifying the system.  
9. Verify the result after the approved change.

The following require explicit approval:

* Restarting or stopping Pi-hole.  
* Modifying firewall rules.  
* Modifying host sysctl settings.  
* Changing container capabilities.  
* Changing port bindings or networking.  
* Updating or replacing the image.  
* Changing upstream DNS.  
* Changing persistent data or permissions.  
* Restoring backups.  
* Deleting or recreating containers or directories.

## **14\. Quick diagnostic reference**

| Symptom | First checks |
| ----- | ----- |
| No DNS for all clients | Container state, port 53, FTL, firewall |
| One client cannot resolve | Client DNS configuration |
| DNS works but no blocking | Query log, client resolver, allowlist |
| Admin page unavailable | Container, ports 8080/8443, firewall |
| Login fails | Authentication configuration, credential status |
| Container exited | Container state and recent logs |
| Repeated restarts | Logs and restart policy |
| Port 53 conflict | `ss`, sysctl, actual bind addresses |
| Intermittent DNS | Query timestamps, network, upstreams |
| Pi-hole works while Distrobox is stopped | Expected; inspect Podman independently |

## **15\. Outstanding diagnostic items**

| Item | Status |
| ----- | ----- |
| Historical `pasta` UDP warning | Cause unresolved |
| Broad TCP/UDP firewall ranges | Purpose unresolved |
| API password rotation | Not verified |
| Minimum capability set | Not established |
| Host low-port sysctl necessity | Requires review |
| Current image digest | Requires verification |
| Backup restore test | Not documented as completed |

Do not treat historical warnings as current faults without reproducing them.

## **16\. References**

* Pi-hole Docker documentation: [https\://docs.pi-hole.net/docker/](https://docs.pi-hole.net/docker/)  
* Pi-hole Docker configuration: [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)  
* Pi-hole troubleshooting: [https\://docs.pi-hole.net/main/post-install/](https://docs.pi-hole.net/main/post-install/)  
* Podman documentation: [https\://docs.podman.io/](https://docs.podman.io/)  
* Project architecture and operations: `pi-hole/docs/Pi-hole on SteamOS — Architecture & Operations.md`  
* Recovery helper: `pi-hole/scripts/pihole-update-recovery.sh`

## **Change history**

| Date | Change |
| ----- | ----- |
| 2026-11-03 | Initial troubleshooting documentation draft based on the documented SteamOS deployment and historical diagnostic findings. |


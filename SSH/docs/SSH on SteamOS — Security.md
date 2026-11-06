# SSH on SteamOS — Security

**Scope:** Host OpenSSH and adjacent SteamOS Devkit/debug services  
**Status:** Security posture documented; findings require review  
**Last audited:** 2026-11-06

## 1. Security objectives

Provide authenticated remote administration to the Steam Deck from trusted LAN clients while minimizing unnecessary host exposure.

Principles: least privilege; public-key authentication; no root SSH login; restricted account and network access; protected private keys; deliberate lifecycle; read-only diagnosis before modification; explicit approval for security-sensitive changes.

## 2. Positive controls verified

| Control | Observed state |
|---|---|
| SSH syntax | `sshd -t` exit code 0 |
| Service | Active and enabled |
| Allowed SSH user | `deck` only |
| Public-key authentication | Enabled |
| Password authentication | Disabled |
| Keyboard-interactive authentication | Disabled |
| Root login | Disabled |
| Address family | IPv4 only |
| `.ssh` directory | `0700`, owned by deck |
| `authorized_keys` | `0600`, owned by deck |
| SSH firewall rule | Allows `192.168.1.169/32` |

These are configuration observations, not a penetration test.

## 3. Important security findings

### 3.1 Broad high-port firewall allowances

**High-priority review.**

The active and permanent `public` zone contains:

```
1024-65535/tcp
1024-65535/udp
```

This is a broad allowance covering almost the entire unprivileged port range. It can undermine narrower service-specific rules because other high-port listeners may be reachable depending on the actual firewall evaluation and network path.

The audit observed listeners including TCP 32000 (SteamOS Devkit), TCP 8081 (Steam web debug port-forwarding socket), TCP/UDP 1716 (KDE Connect), and UDP 27036 (Steam). Pi-hole listeners were also present on the Deck's LAN address.

The audit did not perform a complete remote reachability test for every listener. The broad range and observed listeners warrant investigation; they do not prove that every listener is reachable from every network.

**Required decision:** establish why the range exists, which applications depend on it, and what source scopes are intended. Do not remove or narrow it until dependencies, rollback, and user approval have been addressed.

### 3.2 SSH forwarding defaults

Effective settings include:

```
AllowTcpForwarding yes
AllowAgentForwarding yes
GatewayPorts no
X11Forwarding no
PermitTunnel no
```

TCP and agent forwarding are enabled. They can support useful SSH tunnels, but also provide capabilities that should be understood. Their actual use has not been assessed. Do not disable them without checking current workflows and obtaining approval.

### 3.3 Client policy mismatch

The SSH firewall rich rule permits `192.168.1.169/32`. Two public keys exist, including one labelled for Windows. The supplied audit does not establish the Windows PC's current source address or intended firewall authorization.

A key in `authorized_keys` does not guarantee that a client's packets can reach TCP port 22.

### 3.4 SteamOS Devkit key pairing

The installed Devkit package includes an approval hook that requests pairing approval through the Steam client and invokes a SteamOS helper to enable SSH. Its sample install hook runs as root and adds approved public keys for requested users.

This is a privileged key-management path adjacent to OpenSSH. Consider it when reviewing SSH enablement and authorized keys. Do not delete or replace package-owned hooks as part of routine SSH hardening.

### 3.5 IPv4-only SSH

The daemon uses `AddressFamily inet` and listens on `0.0.0.0:22`. This excludes IPv6 SSH listening in the observed daemon configuration. Other host services do have IPv6 listeners, so this does not mean the host has no IPv6 exposure.

## 4. Adjacent listeners observed

| Listener | Process / unit | Notes |
|---|---|---|
| TCP 22 | `sshd` | OpenSSH host administration |
| TCP 32000 | SteamOS Devkit Python service | Runs as `deck`; package-managed |
| TCP 8081 | `steam-web-debug-portforward.socket` | Proxies to loopback TCP 8080 |
| TCP/UDP 1716 | `kdeconnectd` | KDE Connect |
| UDP 27036 | `steam` | Steam process |
| TCP/UDP 53 | `passt.avx2` | Pi-hole DNS forwarding |
| TCP 8080, 8443 | `passt.avx2` | Pi-hole web interfaces |

This is a snapshot, not a complete inventory of transient listeners. These services are separate from OpenSSH and should be reviewed within their own package/project context.

## 5. Key and host identity

- Never publish private client keys or private host keys.
- Keep `/home/deck/.ssh` permissions restrictive.
- Identify a key's owner and purpose before removal.
- Compare fingerprints through a trusted channel.
- Treat unexpected host-key changes as a security event.
- Review logs before sharing them.

Public fingerprints are recorded in the architecture document. A fingerprint identifies a public key; it does not grant authentication by itself.

## 6. Read-only security checks

```bash
sudo /usr/bin/sshd -t
sudo /usr/bin/sshd -T
systemctl status sshd --no-pager -l
sudo ss -lntup
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --permanent --zone=public --list-all
sudo firewall-cmd --get-active-zones
stat -c '%A %a %U:%G %n' ~/.ssh ~/.ssh/authorized_keys
ssh-keygen -lf ~/.ssh/authorized_keys
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Run on the SteamOS host. These are inspection commands; do not modify settings during evidence collection.

## 7. Remediation governance

Before changing SSH or firewall settings:

1. State the exact finding and affected service.
2. Identify dependent workflows and client devices.
3. Capture current runtime and permanent configuration.
4. Back up the exact files to be changed.
5. Prepare a rollback plan that does not depend on the SSH session being modified.
6. Obtain explicit approval.
7. Apply one scoped change at a time.
8. Validate syntax and runtime state.
9. Test from intended clients and confirm other required services still work.

No remediation was performed during this audit.

## 8. Residual uncertainty

Not established: remote reachability from each LAN client; reachability from outside the LAN; Windows source IP; actual use of forwarding; business need for the broad high-port range; complete Devkit pairing history; full IPv6 firewall reachability.

This document is not a security certification or penetration-test report.

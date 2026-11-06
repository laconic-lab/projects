# SSH on SteamOS — Architecture & Operations

**Project:** Steam Deck LAN SSH administration  
**Host:** Steam Deck OLED — SteamOS — `Laco`  
**Account:** `deck` (UID 1000)  
**Status:** Existing configuration audited  
**Last audited:** 2026-11-06

## 1. Purpose

This document describes the observed host OpenSSH configuration, LAN access model, firewall integration, and adjacent SteamOS development services. It documents the existing system; it is not authorization to change it.

Operating principles: diagnose before modifying; prefer read-only inspection; preserve working access and existing keys; back up before approved changes; never publish private keys or secrets; distinguish OpenSSH from SteamOS Devkit.

## 2. Architecture

```
Linux Mint client (192.168.1.169) --+
                                    +-- LAN / TCP 22 --> firewalld
Windows client --------------------+                    |
                                                         v
Steam Deck OLED / Laco (192.168.1.161) <------------- sshd
                                                         |
                                                  user: deck
                                                         |
                                          ~/.ssh/authorized_keys
```

The firewall SSH rich rule specifically permits source `192.168.1.169/32`. A Windows public key is present, but the audit did not establish the Windows PC's current source address or prove its firewall reachability.

## 3. Host and network profile

| Property | Audited value |
|---|---|
| Device | Steam Deck OLED |
| OS | SteamOS |
| Kernel | `7.2.7-valve2-2-neptune-72-g31504582a073` |
| Hostname | `Laco` |
| User | `deck` (UID 1000) |
| IPv4 | `192.168.1.161/24` |
| Subnet | `192.168.1.0/24` |
| Interface | `enp4s0f3u1u4` |
| Mint client | `192.168.1.169` |
| IPv4 gateway | `192.168.1.254` |

The wired interface was UP and Wi-Fi `wlan0` was DOWN during the audit. IPv6 addresses and a default IPv6 route were present, but sshd is configured for IPv4 only.

## 4. OpenSSH service

- Unit: `sshd.service`
- State: active and enabled
- Main process: `/usr/bin/sshd -D`
- Listener: `0.0.0.0:22/tcp`
- `sshd -t`: exit code 0

Configuration files:

- `/etc/ssh/sshd_config` — main file, includes drop-ins.
- `/etc/ssh/sshd_config.d/00-lan-admin.conf` — local administration policy.
- `/etc/ssh/sshd_config.d/99-archlinux.conf` — packaged defaults.
- `00-lan-admin.conf.bak-mint-setup` — existing backup file, not an active `.conf` drop-in.

The local policy contains:

```
AddressFamily inet
AllowUsers deck
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

The packaged drop-in sets `KbdInteractiveAuthentication no`, `UsePAM yes`, and `PrintMotd no`. A comment in the local file says password authentication was initially intended to be temporary; the effective observed setting is nevertheless `PasswordAuthentication no`.

## 5. Effective settings

| Directive | Effective value |
|---|---|
| Port | `22` |
| AddressFamily | `inet` |
| ListenAddress | `0.0.0.0:22` |
| AllowUsers | `deck` |
| PubkeyAuthentication | `yes` |
| PasswordAuthentication | `no` |
| KbdInteractiveAuthentication | `no` |
| PermitRootLogin | `no` |
| UsePAM | `yes` |
| AuthorizedKeysFile | `.ssh/authorized_keys` |
| MaxAuthTries | `6` |
| AllowTcpForwarding | `yes` |
| AllowAgentForwarding | `yes` |
| X11Forwarding | `no` |
| GatewayPorts | `no` |
| PermitTunnel | `no` |

TCP and agent forwarding remain enabled by effective defaults. Their actual use and necessity have not yet been assessed.

## 6. Client keys and host identity

Observed permissions:

```
/home/deck/.ssh                 0700 deck:deck
/home/deck/.ssh/authorized_keys 0600 deck:deck
```

Authorized ED25519 fingerprints:

| Key comment | Fingerprint |
|---|---|
| `windows-pc-steamdeck` | `SHA256:Q34WfjkhD3G8k/cYSE4ksNubyIrTBndXzSHp+3lo7ZQ` |
| `Linux-Mint-to-Steam-Deck` | `SHA256:pFpy9JttHiixRdUseIYi76aAXTD+PWp4UlkiEDFHL64` |

Server ED25519 host-key fingerprint:

```
SHA256:CgY3GLIC7bEaWP7O05IrjOjkWAa38l+qeLrPoO1+UdA
```

These fingerprints identify public keys; they are not private keys. Clients should verify the host identity through a trusted channel.

## 7. Firewall integration

The active firewall is `firewalld`, enabled and running. The wired interface is assigned to the active default `public` zone.

Observed SSH rule:

```
rule family="ipv4" source address="192.168.1.169/32" service name="ssh" accept
```

Runtime and permanent listings both showed the rule. The zone also contains an inverted-source rejection for TCP port 7011.

**Important security finding:** the public zone additionally allows TCP and UDP ports `1024-65535`. This broad range is an independent exposure requiring review. A source-restricted SSH rule does not prove that other high-port listeners are similarly restricted. No firewall changes were made.

## 8. SteamOS Devkit — separate component

Installed package: `steamos-devkit-service`, version `0.20250916.0-1`.

- Unit: `steamos-devkit-service.service`
- State: active and enabled
- Process: `/usr/bin/python /usr/share/steamos-devkit/steamos-devkit-service.py`
- User: `deck`
- Listener: TCP 32000

The package includes `approve-ssh-key` and `install-ssh-key` hooks. The approval hook validates that Steam is running, requests pairing approval through the Steam client, and then invokes a SteamOS helper to enable SSH. The sample install hook runs as root and installs approved public keys for requested users.

This is a SteamOS development-tooling key-pairing path, not an ordinary SSH login. Its existence matters when reviewing SSH enablement and authorized keys. The audit did not establish the full pairing history.

A separate `steam-web-debug-portforward.socket` is enabled on `[::]:8081`; its static service proxies to `127.0.0.1:8080` under a dynamic user. It is not the SSH daemon.

## 9. Operational inspection

Read-only checks:

```bash
systemctl is-active sshd
systemctl is-enabled sshd
systemctl status sshd --no-pager -l
sudo /usr/bin/sshd -t
sudo /usr/bin/sshd -T
sudo ss -lntup
sudo firewall-cmd --zone=public --list-all
stat -c '%A %a %U:%G %n' ~/.ssh ~/.ssh/authorized_keys
ssh-keygen -lf ~/.ssh/authorized_keys
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

## 10. Findings and pending review

1. Determine the purpose and dependencies of the broad TCP/UDP high-port firewall allowances.
2. Establish whether SSH TCP and agent forwarding are required by current workflows.
3. Confirm the Windows client's current source IP and intended firewall authorization.
4. Establish whether Steam Devkit key pairing is intentionally retained and how it is managed.
5. Assess the exposure of adjacent listeners on ports 32000 and 8081.
6. Review IPv6 firewall exposure separately; IPv4-only sshd does not mean the entire host is IPv4-only.

No remediation is implied. Any host or firewall change requires diagnosis, a backup/rollback plan, and explicit approval.

## 11. Evidence limits

Verified in the 2026-11-06 audit: service state, syntax validation, effective SSH settings, configuration files, key permissions and fingerprints, IPv4 listener, firewall zone output, network addresses/routes, Devkit package/service/hooks, and debug socket configuration.

Not established: complete external port reachability, Windows client reachability, actual forwarding use, Devkit pairing history, rationale for the high-port range, and full IPv6 reachability. This is not a penetration test or security certification.

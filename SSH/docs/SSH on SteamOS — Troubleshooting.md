# SSH on SteamOS — Troubleshooting

**Scope:** SteamOS host OpenSSH and LAN connectivity.  
**Status:** Diagnostic reference based on the 2026-11-06 audit.

## Contents

- [1. Before troubleshooting](#1-before-troubleshooting)
- [2. Quick status checks](#2-quick-status-checks)
- [3. Client cannot reach the Deck](#3-client-cannot-reach-the-deck)
- [4. Connection times out or is refused](#4-connection-times-out-or-is-refused)
- [5. Public-key authentication fails](#5-public-key-authentication-fails)
- [6. Host-key warning](#6-host-key-warning)
- [7. Authentication logs](#7-authentication-logs)
- [8. Forwarding and tunnels](#8-forwarding-and-tunnels)
- [9. SteamOS Devkit distinction](#9-steamos-devkit-distinction)
- [10. Firewall caution](#10-firewall-caution)
- [11. Focused escalation snapshot](#11-focused-escalation-snapshot)

## 1. Before troubleshooting

Start with read-only diagnostics. Determine whether the failure is client-side, network/firewall-side, daemon-side, authentication-side, or host-key-related. Do not change SSH settings or firewall rules merely because a connection failed. Keep an existing working session open during approved changes. Never share private keys, passwords, or unredacted sensitive logs.

## 2. Quick status checks

On the SteamOS host:

```bash
systemctl is-active sshd
systemctl is-enabled sshd
systemctl status sshd --no-pager -l
sudo /usr/bin/sshd -t
sudo ss -lntp | grep -E 'State|sshd|:22[[:space:]]'
```

Expected audited state: `sshd.service` active and enabled; syntax check exit code 0; listener `0.0.0.0:22`.

## 3. Client cannot reach the Deck

Inspect the host network and firewall:

```bash
ip -br addr
ip route
sudo ss -lntup
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
```

Confirm that the Deck still uses `192.168.1.161`, the client is on the intended LAN, sshd listens on TCP 22, and the active zone is attached to the expected interface. The audited SSH rich rule explicitly permits `192.168.1.169/32`.

From Windows PowerShell:

```powershell
Test-NetConnection 192.168.1.161 -Port 22
```

A successful TCP test does not prove authentication will succeed. A Windows public key being present in `authorized_keys` does not prove that its current source address is allowed by the firewall.

## 4. Connection times out or is refused

| Symptom | Possible area | Next read-only check |
|---|---|---|
| Timeout | Routing, firewall, wrong source address | Check client address, routes, active zone and rules |
| Connection refused | No listener or service failure | Check `systemctl status sshd` and `ss -lntp` |
| Host unreachable | Address or network path | Check `ip -br addr` and routes |
| Mint works, Windows fails | Client source rule or Windows network | Verify Windows source IP and firewall path |

## 5. Public-key authentication fails

Inspect effective policy:

```bash
sudo /usr/bin/sshd -T | grep -E '^(allowusers|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|authorizedkeysfile) '
stat -c '%A %a %U:%G %n' ~/.ssh ~/.ssh/authorized_keys
ssh-keygen -lf ~/.ssh/authorized_keys
```

Expected audited values: `AllowUsers deck`, public-key authentication enabled, password and keyboard-interactive authentication disabled, root login disabled, `.ssh` mode `0700`, and `authorized_keys` mode `0600`.

Do not enable password authentication as a workaround. Verify the client is selecting the intended private key and that its public counterpart is authorized.

## 6. Host-key warning

If the client reports that the remote host identification changed:

1. Stop; do not bypass the warning.
2. Obtain the current server fingerprint locally.
3. Compare it against a trusted record.
4. Determine whether the host was reinstalled or keys intentionally regenerated.
5. Update client trust records only after verification.

Audited ED25519 fingerprint:

```text
SHA256:CgY3GLIC7bEaWP7O05IrjOjkWAa38l+qeLrPoO1+UdA
```

## 7. Authentication logs

```bash
sudo journalctl -u sshd --no-pager -n 100
```

Look for accepted/failed public-key authentication, username mismatch, source address mismatch, permissions errors, and daemon startup errors. The audit showed successful public-key logins from `192.168.1.169`; that historical observation does not prove current client reachability. Review logs before sharing them.

## 8. Forwarding and tunnels

Effective settings permit TCP and agent forwarding. If a tunnel fails, inspect the client command, destination binding, effective server policy, and target service. Do not assume forwarding is disabled. Prefer loopback binding plus a deliberately configured SSH tunnel when that is the project's documented access model.

## 9. SteamOS Devkit distinction

The Devkit service is separate from `sshd.service`. The package-managed service runs as `deck` and listens on TCP 32000. Its pairing hook can request Steam client approval and invoke a helper to enable SSH and install a public key. If keys appear unexpectedly or SSH enablement changes, inspect the Devkit service and package-owned hooks before editing `authorized_keys`.

The `steam-web-debug-portforward.socket` on port 8081 is also separate from SSH.

## 10. Firewall caution

The audited public zone permits TCP and UDP ports `1024-65535`. This broad allowance is an unresolved security finding. Do not add more broad rules or treat the SSH source restriction as a complete host firewall policy. Compare runtime and permanent configuration, identify service dependencies, and obtain approval before changing rules.

## 11. Focused escalation snapshot

```bash
systemctl status sshd --no-pager -l
sudo /usr/bin/sshd -t
sudo /usr/bin/sshd -T | grep -E '^(port|addressfamily|listenaddress|allowusers|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|authorizedkeysfile|allowtcpforwarding|allowagentforwarding) '
sudo ss -lntp | grep -E 'sshd|:22([[:space:]]|$)'
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
```

Do not include private keys or secrets. Review output before posting publicly.

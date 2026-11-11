# SSH on SteamOS — Installation & Client Setup

**Project:** Steam Deck LAN SSH administration  
**Status:** Existing host deployment documented; client setup reference  
**Last audited:** 2026-11-06

## Contents

- [1. Purpose](#1-purpose)
- [2. Existing host baseline](#2-existing-host-baseline)
- [3. Client connection](#3-client-connection)
- [4. Host identity verification](#4-host-identity-verification)
- [5. Authorized client keys](#5-authorized-client-keys)
- [6. Client key management principles](#6-client-key-management-principles)
- [7. Firewall dependency](#7-firewall-dependency)
- [8. Fresh installation warning](#8-fresh-installation-warning)

## 1. Purpose

The Steam Deck already has an operational host SSH service. This document records the verified host baseline and client connection model. It is not authorization to reinstall OpenSSH, replace keys, enable password authentication, or change firewall policy.

Read [Architecture & Operations](./SSH%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md) and [Security](./SSH%20on%20SteamOS%20%E2%80%94%20Security.md) first.

## 2. Existing host baseline

Verified during the audit:

- Host: SteamOS / `Laco`
- Account: `deck`
- LAN IPv4: `192.168.1.161`
- SSH port: TCP 22
- Service: `sshd.service`, active and enabled
- Authentication: public-key only
- Password and keyboard-interactive authentication: disabled
- Root login: disabled
- Allowed account: `deck`
- Listener: `0.0.0.0:22`
- Syntax validation: `sshd -t` returned exit code 0

## 3. Client connection

From a trusted client with the matching private key installed locally:

```bash
ssh deck@192.168.1.161
```

SFTP:

```bash
sftp deck@192.168.1.161
```

The Linux Mint client was observed at `192.168.1.169`; that exact address is explicitly allowed by the audited SSH firewall rich rule.

A Windows public key is present in `authorized_keys`, but the audit did not provide a current Windows source IP. The key entry alone does not guarantee network reachability through the firewall.

## 4. Host identity verification

Audited ED25519 host-key fingerprint:

```text
SHA256:CgY3GLIC7bEaWP7O05IrjOjkWAa38l+qeLrPoO1+UdA
```

Compare the fingerprint presented by the client with a trusted value obtained independently. If a previously trusted host key changes unexpectedly, stop and investigate. Do not bypass a host-key warning blindly.

## 5. Authorized client keys

The Deck's `/home/deck/.ssh/authorized_keys` contained two ED25519 public keys:

| Comment | Fingerprint |
|---|---|
| `windows-pc-steamdeck` | `SHA256:Q34WfjkhD3G8k/cYSE4ksNubyIrTBndXzSHp+3lo7ZQ` |
| `Linux-Mint-to-Steam-Deck` | `SHA256:pFpy9JttHiixRdUseIYi76aAXTD+PWp4UlkiEDFHL64` |

Observed permissions: `.ssh` is `0700`, and `authorized_keys` is `0600`, both owned by `deck:deck`.

Never copy a client private key onto the Deck. The server stores the corresponding public keys only.

## 6. Client key management principles

- Keep each client's private key on that client.
- Prefer distinct keys per client.
- Protect private-key files with restrictive permissions and a passphrase where appropriate.
- Verify a public-key fingerprint before authorizing it.
- Identify the owner and purpose of each key before removal.
- Back up the current authorized-key file before an approved edit.
- Do not replace the complete file merely to add one key.
- Do not publish private key material.

## 7. Firewall dependency

The audited SSH rich rule explicitly allows `192.168.1.169/32`. It does not establish that all other client addresses are permitted.

The public zone also contains broad TCP/UDP allowances for ports `1024-65535`. This is a separate security finding and must not be treated as evidence that SSH or other services are safely restricted.

No firewall modification instructions are provided because the intended policy for all clients and the broad port range remain unresolved.

## 8. Fresh installation warning

A fresh SteamOS installation or recovery may have different package versions, configuration, host keys, firewall state, and Devkit integration. Do not blindly copy the audited configuration.

Before a future deployment:

1. Confirm supported package and service names on the target SteamOS build.
2. Inspect configuration include order and existing drop-ins.
3. Establish the intended client allowlist and firewall policy.
4. Generate host keys on the target host; never copy another machine's private host keys.
5. Install only verified client public keys.
6. Validate configuration with `sshd -t` before applying it.
7. Keep a second administrative session and local recovery path available while testing.
8. Verify access from each intended client.
9. Record the actual resulting state.

This guide deliberately does not provide a blind install script: the current task documents an existing installation and does not authorize a fresh deployment.

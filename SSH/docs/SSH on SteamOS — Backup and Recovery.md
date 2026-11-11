# SSH on SteamOS — Backup and Recovery

**Scope:** OpenSSH host configuration, authorized client keys, host identity, and firewall dependencies.  
**Status:** Recovery guidance; no recovery drill performed.  
**Last audited:** 2026-11-06

## Contents

- [Purpose](#purpose)
- [Critical items](#critical-items)
- [Backup principles](#backup-principles)
- [Read-only checks](#read-only-checks)
- [Recovery scenarios](#recovery-scenarios)
- [Restore governance](#restore-governance)
- [Limitations](#limitations)

## Purpose

Preserve the ability to recover SSH access without exposing private key material or accidentally locking out the administrator. This document does not authorize changes. Obtain approval before restoring or modifying configuration.

## Critical items

- `/etc/ssh/sshd_config` — main daemon configuration.
- `/etc/ssh/sshd_config.d/00-lan-admin.conf` — local access policy.
- `/etc/ssh/sshd_config.d/99-archlinux.conf` — packaged defaults.
- `/home/deck/.ssh/authorized_keys` — authorized client public keys.
- `/etc/ssh/ssh_host_ed25519_key` — private server host key; secret, never commit to Git.
- `/etc/ssh/ssh_host_ed25519_key.pub` — public server host key.
- `/etc/firewalld/zones/public.xml` — persistent firewall zone.
- Runtime firewalld state and systemd enablement — must be recorded separately.

The existing `00-lan-admin.conf.bak-mint-setup` file exists, but verify its contents and suitability before relying on it as a rollback copy.

## Backup principles

Before an approved change:

1. Identify the exact files and services affected.
2. Record service state and effective configuration.
3. Create timestamped backups outside the Git working tree.
4. Preserve ownership, permissions, and file contents.
5. Verify every backup is readable and matches its original.
6. Store private host keys only in a protected location with restrictive permissions.
7. Never print private key contents or copy them into chat.
8. Preserve local console access or another recovery route.

A file backup alone does not capture runtime firewall state, enabled services, package versions, or client known-host records.

## Read-only checks

```bash
systemctl is-active sshd
systemctl is-enabled sshd
sudo /usr/bin/sshd -t
sudo /usr/bin/sshd -T
sudo find /etc/ssh -maxdepth 2 -type f -printf '%M %u:%g %p\\n' | sort
stat -c '%A %a %U:%G %n' ~/.ssh ~/.ssh/authorized_keys
ssh-keygen -lf ~/.ssh/authorized_keys
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --permanent --zone=public --list-all
sudo ss -lntup
```

Review output before saving or sharing it. Do not publish private key contents or unredacted sensitive logs.

## Recovery scenarios

### SSH configuration fails validation

Inspect the exact syntax error and relevant file. Compare against a verified backup. Restore only the specific known-good file when the cause and target are unambiguous and restoration is approved. Validate with `sshd -t` before applying the configuration. Keep an existing session open until a new connection is tested.

### SSH service unavailable

Use local Steam Deck access if remote SSH is unavailable. Inspect `systemctl status sshd --no-pager -l`, `journalctl -u sshd --no-pager -n 100`, and `ss -lntp`. Establish why the service stopped and whether SteamOS Devkit or another lifecycle mechanism is involved before starting or enabling anything.

### Client key rejected

Inspect the client account and selected private key, public-key fingerprint, `authorized_keys` ownership and permissions, effective authentication settings, firewall source rule, actual client source address, and authentication logs. Never replace the entire authorized-key file as a shortcut.

### Host key changed

Verify the current server fingerprint locally through a trusted channel. Do not instruct clients to ignore a host-key warning until the change is explained. Restoring a host private key changes server identity and is a sensitive recovery operation.

### Firewall blocks SSH

Use local console access. Compare runtime and permanent firewalld state and inspect active zone/interface mapping. Do not flush firewall rules or replace the complete zone configuration. Preserve unrelated DNS, SteamOS, and project rules. The broad TCP/UDP high-port allowances observed during the audit are a separate finding, not a safe recovery mechanism.

## Restore governance

Verify backup provenance and integrity, confirm it belongs to this host and intended configuration, preserve the failed state for diagnosis where practical, obtain explicit approval, and restore only the required component. Verify syntax, ownership, permissions, service state, listener, firewall, and client connectivity afterwards.

## Limitations

No complete SSH recovery drill was performed, and no backup archive was created during this documentation task. This document records a recovery approach; it does not claim a tested recovery package exists.

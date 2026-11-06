# Steam Deck SSH — LAN Administration

Documentation for the existing OpenSSH service on the Steam Deck OLED (SteamOS host `Laco`, account `deck`).

## Documentation

- [Architecture and Operations](./docs/SSH%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Installation and Client Setup](./docs/SSH%20on%20SteamOS%20%E2%80%94%20Installation%20%26%20Client%20Setup.md)
- [Security](./docs/SSH%20on%20SteamOS%20%E2%80%94%20Security.md)
- [Backup and Recovery](./docs/SSH%20on%20SteamOS%20%E2%80%94%20Backup%20and%20Recovery.md)
- [Troubleshooting](./docs/SSH%20on%20SteamOS%20%E2%80%94%20Troubleshooting.md)

## Audited baseline — 2026-11-06

- `sshd.service` active and enabled; syntax check passed.
- Public-key authentication only; password and keyboard-interactive authentication disabled.
- `AllowUsers deck`; root login disabled.
- IPv4 listener `0.0.0.0:22`.
- Two ED25519 client public keys in `/home/deck/.ssh/authorized_keys`.
- SSH firewall rich rule explicitly permits `192.168.1.169/32`.
- The public firewall zone also permits TCP and UDP `1024-65535`; this is a separate, high-priority security review item.
- SteamOS Devkit key-pairing hooks and service are documented separately from OpenSSH.

No host configuration was changed as part of the audit. The documents distinguish verified observations from unresolved questions and proposed future work.

## Operating rules

Diagnose before modifying. Back up before approved edits. Never publish private keys or secrets. Do not change SSH, firewall, service, or key configuration without explicit approval.

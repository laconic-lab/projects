# Pi-hole on SteamOS — LAN DNS

Pi-hole provides network-wide DNS filtering for the local network, hosted by the Steam Deck OLED. The project uses **rootless Podman** for the Pi-hole application container, with SteamOS remaining the host and Distrobox used for project tooling and persistent data organisation.

## Documentation

- [Architecture and operations](./docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Architecture%20%26%20Operations.md)
- [Installation guide](./docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Installation%20Guide.md)
- [Security](./docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Security.md)
- [Backup and recovery](./docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Backup%20and%20Recovery.md)
- [Troubleshooting](./docs/Pi-hole%20on%20SteamOS%20%E2%80%94%20Troubleshooting.md)

## Architecture at a glance

```text
LAN clients
    |
Steam Deck / SteamOS host
    |
firewalld — pasta networking
    |
rootless Podman
    |
Pi-hole container — DNS :53 / administration UI
    |
persistent configuration and DNS data
```

The Distrobox named `pihole-box` is not the Pi-hole service runtime. The Podman container is managed independently on the host; stopping the Distrobox does not itself stop Pi-hole.

## Documented operating model

- DNS is provided on TCP/UDP port 53.
- Administration is published on the Deck's configured web ports; consult the architecture document for the audited bindings.
- DHCP is not part of the documented configuration.
- Persistent Pi-hole and dnsmasq data are stored outside the disposable container layer.
- The service has a persistent lifecycle; it is distinct from manually launched application projects.

## Operational safeguards

Diagnose before modifying. Prefer read-only checks. Preserve the existing container and persistent data. Back up before approved changes. Do not recreate the container, remove volumes, alter firewall rules, or change capabilities as routine troubleshooting. Never publish credentials or secrets.

## Status and evidence

The architecture document records the inspected configuration and its evidence date. It is a technical record, **not live telemetry**; verify current container, service, port and firewall state before relying on it. Review the security and recovery documents before maintenance.

---
*Project documentation index — Steam Deck Lab.*

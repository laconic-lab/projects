# Waydroid — Android-on-Deck Feasibility Research

This project investigates whether Android workloads can run on the Steam Deck OLED while Linux Mint and Windows act as remote display and input clients. SSH is part of the intended control and secure transport model.

This is a **feasibility investigation**, not an approved or completed Waydroid installation.

## Documentation

- [Consolidated SSH feasibility audit](./1.audit/1.0_Waydroid-SSH-Consolidated-Audit.md)
- [Historical audit source](./1.audit/_1.0_%20Waydroid%20SSH%20Feasibility%20Audit.md)
- [Audit material directory](./1.audit/)

## Intended architecture

```text
Linux Mint client                 Windows client
 SSH / display / input             SSH / display / input
          \                           /
           \                         /
             Steam Deck / SteamOS
                      |
           isolated container runtime
                      |
             Android / Waydroid
                      |
          project-specific secure transport
```

The intended constraints are strict:

- Waydroid must run in a container environment if feasible.
- No native Waydroid installation on SteamOS.
- No privileged container or broad host filesystem, network, PID or IPC sharing.
- Reuse the existing KDE Wayland session; do not add another compositor without demonstrated need.
- Avoid host-wide firewall, forwarding, kernel, service or package changes merely to force success.
- Existing Deck projects and services remain protected.
- Manual lifecycle; no autostart unless explicitly approved.

## Current recorded verdict

**Conditionally promising, not proven.** The consolidated audit records positive BinderFS and namespace experiments, but important end-to-end requirements remain untested, including actual nested LXC operation, Binder transactions, Android service stability, GPU use, Wayland/D-Bus/audio handoff, ADB and scrcpy transport.

The audit's latest recorded operation is a pending capability-isolation test. No installation or persistent host modification is authorized by the audit.

## How to continue

Read the consolidated audit before proposing another test. It preserves completed evidence, unresolved blockers and the next recorded investigation point. Do not repeat completed tests without checking the audit, and do not turn a promising feasibility result into permission to install or modify SteamOS.

---
*Project documentation index — Steam Deck Lab.*

# Windows VM Connections and Credential Naming Convention

**Platform:** Steam Deck OLED / SteamOS / rootless Podman / Dockur Windows / QEMU-KVM  
**Current VM:** `windows-box` container; `windows-vm` guest  
**Status:** noVNC verified from PC; RDP publication and guest-side readiness pending  
**Policy:** manual lifecycle only; no boot autostart, automatic restart, Windows guest backups or snapshots.

## 1. Identity naming convention

Use these role labels consistently in documentation, configuration tables and diagnostics. They are labels for identity categories, not literal account names.

| Role label | Meaning | Current mapping / status |
|---|---|---|
| `container-user` | Host/runtime identity involved in rootless Podman and the container's QEMU/Dockur processes | Podman is invoked by host account `deck`. The effective UID/name of QEMU and helper processes inside the container must be inspected; do not assume it is also `deck`. |
| `console-user` | Optional identity/credential used only to authenticate to the noVNC web interface | None configured. `PROTECT=N`; no console login prompt is intended. |
| `win-user` | Windows local account inside the guest | Current account name: `DeckVM`. Its password is supplied through Dockur's `USERNAME` / `PASSWORD` environment variables. |
| SMB share identity | Identity used by Windows to access Dockur's `host.lan\Data` share | Dockur documents the share path but does not define it as the Windows `win-user` credential. Do not assume credentials; inspect the actual prompt/behavior if Windows asks. |

### Important distinction about the current password

The `PASSWORD` key in `windows-box.env` is the password for the Windows local account `DeckVM` (`win-user`). It is **not** a Podman password, QEMU/KVM password, container-user password, Samba database password, or noVNC console password.

`AUTOLOGIN=Y` automatically signs the Windows account in; it does not remove the account password or make the credential unnecessary for RDP.

The environment file is stored locally with mode `0600`, owned by `deck`. This limits ordinary access to the host account and root, but the value remains plaintext at rest. Anyone who gains access as `deck` or root can read it. Do not display, paste, log, or commit it. The real environment file is not stored in this repository.

The generic template uses placeholders only. Generate/choose a unique `win-user` password locally for each guest. A future secret-management design can be considered if the lab grows beyond this simple protected local file.

## 2. Connection matrix

Current Deck host LAN address: `192.168.1.161`  
PC client: `192.168.1.169`

| Connection | Where used | Address / path | Port | Credential category | Current state |
|---|---|---|---:|---|---|
| noVNC browser console | PC browser to Windows guest display | `http://192.168.1.161:8006/` | TCP 8006 | No `console-user`; `PROTECT=N` | VERIFIED working in Brave and Chrome; both mirror one session |
| noVNC loopback | Browser on Deck itself | `http://127.0.0.1:8006/` | TCP 8006 | No `console-user` | Not listening on loopback after binding specifically to LAN IP; no change requested |
| RDP | Windows App / Remote Desktop client on PC | Intended target `192.168.1.161` | TCP 3389 (UDP optional) | `win-user`: `DeckVM` plus its Windows password | NOT YET PUBLISHED / troubleshooting |
| Dockur shared folder | Windows File Explorer inside guest | `\\host.lan\Data` (mapped as `Z:` in current guest) | Internal Dockur/Samba integration | SMB identity not yet verified; do not assume `win-user` | Drive visible in guest; actual host path is the `/shared` bind mount |
| Host SFTP | PC WinSCP to Steam Deck | `192.168.1.161` | TCP 22 | Steam Deck SSH identity (not `win-user`) | Existing host SSH service; host files require host account permissions |

RDP's destination is the **Steam Deck host address**, not a separately reachable Windows guest LAN address. The guest currently uses Dockur user-mode networking (`NETWORK=user` / `passt` observed). The host must publish a port to the container, and Dockur must forward that port from the container to the Windows guest.

## 3. noVNC authentication and allowlists

- Dockur documents `PROTECT` as enabling password protection for its web interface.
- The current configuration keeps `PROTECT=N`, as requested. There is no separate `console-user` configured.
- Dockur's documented environment variable list does not describe an IP allowlist for noVNC.
- Access control at the network boundary is handled by SteamOS listeners and firewalld, not by a Windows user or a Podman account.
- There is no special physical-console bypass identity. If noVNC is unprotected, any client able to reach the published endpoint can interact with the guest.
- The Deck's local browser can use the LAN address `192.168.1.161`; the previous loopback endpoint is no longer bound. No restoration is requested.

The inspected firewalld public zone previously had broad TCP/UDP allowances covering 3389 and 8006. Do not infer that access is limited to PC `192.168.1.169` merely because it is the intended client. Reassess the actual firewall before making a claim about a source-IP allowlist.

## 4. Environment file terms

| Variable | Meaning |
|---|---|
| `NETWORK=user` | Dockur QEMU user-mode networking. Guest services are not directly bridged onto the home LAN. Custom guest ports require Dockur user-port forwarding. |
| `DISPLAY=web` | Selects Dockur's web-based display backend. Other documented backends include `vnc`, `disabled` and `none`; this is a display backend choice, not Windows display resolution. |
| `WEB=Y` | Enables the browser web interface. |
| `WEB_PORT=8006` | Port inside the container for the web interface; host publication is separately set in the Podman start command. |
| `PROTECT=N` | Leaves the browser console without Dockur's optional password protection. It is not the Windows account password. |
| `USERNAME=DeckVM` | Creates/configures the Windows local `win-user`. |
| `PASSWORD=...` | Password for that Windows local account. Secret; never publish its value. |
| `AUTOLOGIN=Y` | Automatically signs in to Windows after boot; does not erase the account password. |
| `SAMBA=Y` | Enables Dockur's host-folder sharing service. It is not a database and does not mean Windows is connected to a database. |
| `HOST=windows-vm` | Windows computer name/hostname; unrelated to the Deck's LAN IP. |

Dockur documents the shared-folder path as `\\host.lan\Data`. In this deployment, Podman bind-mounts `/home/deck/WindowsVM/shared` to container `/shared`. Thus the Windows share is backed by that one project directory, not by the entire Deck home directory. It is read/write in the current deployment. Use it for exchange files and audit output, not secrets.

## 5. RDP design for this user-mode deployment

Dockur's current environment reference defines `USER_PORTS` as additional ports forwarded to Windows when user-mode networking is active. Its project examples publish TCP and UDP 3389 at the container boundary. For this deployment, the expected design is:

1. Verify that Windows has Remote Desktop enabled, a listener on TCP 3389, and an enabled inbound firewall rule.
2. Verify Dockur is running in user-mode networking and inspect existing `USER_PORTS`.
3. Add `3389` to `USER_PORTS` in the local environment file.
4. Add host publication for TCP 3389 (UDP may also be published for RDP transport performance) bound specifically to `192.168.1.161`.
5. Recreate only the Podman container object using the existing host-backed storage. Do not delete or alter the guest disk.
6. Verify `podman port`, the host listener, and a TCP connection from PC `192.168.1.169`.
7. Connect the PC Remote Desktop client to `192.168.1.161` using the `win-user` credentials.

No change has been made yet. The exact local start script must be inspected before editing because it is not committed in this repository. Do not change the guest networking mode or add host firewall rules as a shortcut. The existing host firewall policy is broad and must be considered when assessing LAN exposure.

## 6. Password expiration

Dockur's documented `PASSWORD` variable sets the initial Windows account password; it does not document a "password never expires" switch.

If the user wants a non-expiring password for this disposable local sandbox, configure that property inside Windows after installation (for example, through the local account's account properties or a targeted PowerShell command). Treat it as a Windows account policy decision, not a Dockur/container setting. Do not apply it to the Steam Deck host or the container-user identity. Document the choice per guest.

## 7. Manual lifecycle and disposable guest policy

- User starts the guest by explicitly invoking the local start script.
- `--restart=no`; no systemd/Quadlet/cron/desktop autostart or automatic restart.
- User shuts down the guest deliberately; verify the exact Dockur/QEMU stop semantics rather than assuming container stop always equals clean Windows shutdown.
- No Windows guest backups, snapshots or copies of `data.img`.
- Preserve configuration knowledge, scripts and test evidence in Git; keep populated secret-bearing environment files local.
- Recreate a damaged disposable guest when appropriate instead of restoring a "wounded duck".

## 8. References

- [Dockur environment variables](https://github.com/dockur/windows/blob/master/docs/environment.md)
- [Dockur README: shared folders, account settings and published ports](https://github.com/dockur/windows#readme)
- [Windows VM lifecycle philosophy](./WINDOWS-VM-LIFECYCLE-AND-SCRIPT-PHILOSOPHY.md)
- [Disposable I/O and SSD lab](./WINDOWS-VM-DISPOSABLE-IO-AND-SSD-LAB.md)
- [Generic per-VM environment template](../templates/windows-vm.env.example)

---

*Document current behavior separately from proposed RDP configuration. Update the status only after the guest and host connectivity tests pass.*

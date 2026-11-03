# **Pi-hole on SteamOS — Backup and Recovery**

**Document:** `pi-hole/docs/BACKUP-AND-RECOVERY.md`  
**Status:** Draft — review required  
**Scope:** Rootless Podman Pi-hole deployment on SteamOS  
**Last reviewed:** 2026-11-03

## **1\. Purpose**

This document defines how to protect Pi-hole configuration and data, verify backups, and recover the service after common failures.

The main objectives are:

* Preserve Pi-hole configuration and persistent data.  
* Keep backups separate from the live application directories.  
* Avoid accidental deletion during container maintenance.  
* Recover service operation without unnecessarily rebuilding the deployment.  
* Distinguish application-data recovery from host configuration recovery.  
* Require explicit approval before destructive restoration or replacement.

**A running container is not a backup. A recovery script is not a complete backup.**

## **2\. Deployment data layout**

The documented deployment stores Pi-hole data in two host directories:

```
/home/deck/pihole-box/
│
├── etc-pihole/
│   └── Pi-hole persistent configuration and data
│
└── etc-dnsmasq.d/
    └── dnsmasq configuration
```

These directories are mounted into the container:

| Host directory | Container directory | Purpose |
| ----- | ----- | ----- |
| `/home/deck/pihole-box/etc-pihole` | `/etc/pihole` | Pi-hole persistent configuration and data |
| `/home/deck/pihole-box/etc-dnsmasq.d` | `/etc/dnsmasq.d` | dnsmasq configuration |

The Distrobox named `pihole-box` is not required to be running for the Podman container to use these host directories.

The actual live paths and mounts must be verified before performing a backup or restore.

## **3\. What must be backed up**

### **3.1 Application data**

| Item | Backup requirement |
| ----- | ----- |
| `/etc/pihole` host directory | Required |
| `/etc/dnsmasq.d` host directory | Required |
| Custom Pi-hole configuration | Preserve |
| Custom DNS records and local configuration | Preserve |
| Blocklists and allowlists | Preserve through application data or documented export |
| Application database and associated state | Preserve consistently |

The precise contents vary by Pi-hole version and configuration. Do not assume that copying only one configuration file is sufficient.

### **3.2 Host configuration**

The deployment also depends on host-level configuration:

| Item | Location | Backup purpose |
| ----- | ----- | ----- |
| Low-port sysctl | `/etc/sysctl.d/99-pihole.conf` | Documents host DNS port-binding configuration |
| User systemd unit | `/home/deck/.config/systemd/user/pihole.service` | Documents service lifecycle |
| Firewall configuration | firewalld configuration and active rules | Documents LAN access policy |
| Container definition | Podman configuration or deployment record | Reconstructs runtime settings |
| Image reference | Image name, version and digest | Reproducible deployment |

Host configuration should be recorded separately from the Pi-hole application data.

Do not restore an entire host configuration directory just to recover Pi-hole.

### **3.3 Credentials**

Credentials require separate handling.

* Do not store API passwords in ordinary backup archives.  
* Do not include secrets in GitHub.  
* Do not include passwords in diagnostic output.  
* If a protected secret backup is required, define its encryption, access control, and recovery procedure separately.  
* Treat the previously exposed Pi-hole API password as compromised until rotation is verified.

A restored application configuration must not silently reintroduce a compromised credential.

## **4\. Backup principles**

1. Inspect the live container and mount paths before copying anything.  
2. Keep backups outside the live Pi-hole data directories.  
3. Use a destination with sufficient free space.  
4. Preserve file ownership, permissions, timestamps, and directory structure.  
5. Prefer a consistent backup made while Pi-hole is stopped, or use an application-supported backup/export method.  
6. Record the Pi-hole version and image digest with the backup.  
7. Verify archive integrity and inspect the archive contents.  
8. Never overwrite the only known-good backup.  
9. Keep at least one backup independent of the Steam Deck's internal storage when practical.  
10. Do not delete old backups automatically.

## **5\. Backup procedure**

### **5.1 Read-only preflight**

**STEAM DECK — host SSH**

Inspect the container and its mounts:

```
podman ps -a --filter name=pihole

podman inspect pihole \
  --format '{{.State.Status}}'

podman inspect pihole \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'

df -h /home/deck
```

Confirm:

* The container is the expected Pi-hole container.  
* Both persistent mount paths are correct.  
* The backup destination is not inside either live data directory.  
* Sufficient storage is available.  
* No unexpected mount has been introduced.

Do not print the full container environment as part of the backup inspection.

### **5.2 Consistent backup**

For a straightforward filesystem backup, stop Pi-hole cleanly before copying its persistent data.

This causes DNS service interruption. Schedule it accordingly and obtain approval before stopping the service.

After confirming the service is stopped, copy both data directories into a new, uniquely named backup directory.

Example destination structure:

```
/home/deck/Pi-hole-Backups/
└── YYYY-MM-DD_HH-MM/
    ├── etc-pihole/
    ├── etc-dnsmasq.d/
    └── backup-info.txt
```

The destination above is an example. Confirm the actual backup location and available space before creating it.

The backup metadata should record:

* Date and time.  
* Pi-hole version.  
* Container image and digest.  
* Container configuration reference.  
* Source paths.  
* Backup method.  
* Whether the container was stopped.  
* Backup verification result.

Do not include credentials or secret environment values.

### **5.3 Archive verification**

After copying:

* Confirm both directories exist in the backup.  
* Compare file counts and sizes with the source.  
* Inspect ownership and permissions.  
* Verify that the archive or copy can be read.  
* Confirm that the backup is independent of the live directories.

A successful copy command alone is not proof of a valid backup.

### **5.4 Restart after backup**

Only after the backup has been verified should the service be started again.

Use the existing approved lifecycle mechanism. Do not start a second container or create another service definition.

Verify DNS and web administration after startup.

## **6\. Recovery categories**

Choose the narrowest recovery procedure that matches the failure.

| Failure | Recovery target |
| ----- | ----- |
| Pi-hole process stopped | Start existing container |
| Container stopped unexpectedly | Inspect logs and start existing container if safe |
| Web administration unavailable | Diagnose web service, ports, and container health |
| DNS unavailable | Diagnose DNS listener, networking, firewall, and upstreams |
| Configuration damaged | Restore selected application data from a verified backup |
| Persistent data lost | Restore both required data directories |
| Container removed or damaged | Rebuild container using reviewed configuration and existing data |
| Host firewall or sysctl changed | Recover host settings separately |
| Steam Deck storage failure | Restore from an independent backup and rebuild the deployment |

Do not rebuild the container to solve a problem that only requires restarting the existing service.

## **7\. Application-data restoration**

Restoring Pi-hole data is a destructive operation because it can overwrite current configuration and database state.

**Approval required before restoration.**

### **7.1 Pre-restore checks**

* Identify the exact failure.  
* Confirm the selected backup date.  
* Verify the backup integrity.  
* Confirm both expected source directories exist in the backup.  
* Inspect current live data.  
* Create a separate backup of current live data if it remains readable.  
* Confirm destination ownership and permissions.  
* Confirm the target Pi-hole version is compatible with the backup.  
* Confirm the container is stopped.

Do not merge an old backup into live directories without understanding the consequences.

### **7.2 Restore procedure**

1. Stop the existing Pi-hole service using the approved lifecycle method.  
2. Preserve the current live directories as a separate recovery snapshot.  
3. Restore the selected backup's `etc-pihole` contents to the corresponding host directory.  
4. Restore the selected backup's `etc-dnsmasq.d` contents to the corresponding host directory.  
5. Verify ownership and permissions.  
6. Confirm the container mounts still point to the intended directories.  
7. Start the existing container.  
8. Check Pi-hole logs and service status.  
9. Verify DNS queries from a LAN client.  
10. Verify web administration.  
11. Confirm expected configuration and local DNS records.

Do not delete the pre-restore snapshot until the recovered service has been verified and a new backup has been created.

## **8\. Container recovery**

If the container itself is damaged or removed, the persistent data directories should be treated as independent assets.

Before rebuilding:

* Verify that both persistent data directories are intact.  
* Identify the previously used image version or digest.  
* Reconstruct the exact port bindings.  
* Reconstruct the intended rootless network configuration.  
* Review capabilities.  
* Review environment variables and secret handling.  
* Review restart policy.  
* Review firewall and sysctl dependencies.  
* Confirm no unrelated host directories are mounted.

Do not use a generic upstream Compose example without comparing it against the deployment's actual security requirements.

Do not remove persistent data volumes or directories during container replacement.

## **9\. Host configuration recovery**

Host configuration is separate from Pi-hole application data.

### **9.1 Sysctl**

The documented setting is:

```
/etc/sysctl.d/99-pihole.conf
```

It contains the low-port configuration:

```
net.ipv4.ip_unprivileged_port_start=53
```

This is a host-wide setting. Restore it only after confirming that the current Podman networking method requires it.

### **9.2 Firewall**

The documented deployment uses firewalld with LAN-restricted DNS rules.

Before restoring firewall configuration:

* Inspect the active zone.  
* Inspect the active interface.  
* Inspect current rules.  
* Identify the source and purpose of each rule.  
* Preserve unrelated firewall policy.

Do not replace the complete firewall configuration with a Pi-hole-only backup.

### **9.3 User systemd service**

The documented service is:

```
/home/deck/.config/systemd/user/pihole.service
```

Before restoring it, verify that its commands still match the actual container name and lifecycle policy.

Do not create a duplicate unit.

## **10\. Existing recovery script**

Repository script:

`pi-hole/scripts/pihole-update-recovery.sh`

This script is a host-configuration and service recovery helper. It is **not** a complete application-data backup or container rebuild script.

Documented operations include:

* Checking the existing Pi-hole container.  
* Creating or restoring `/etc/sysctl.d/99-pihole.conf`.  
* Applying the host sysctl value.  
* Adding persistent LAN DNS firewall rules when required.  
* Reloading firewalld.  
* Starting the existing container or service when stopped.

It does not:

* Back up `/etc/pihole`.  
* Back up `/etc/dnsmasq.d`.  
* Restore the Pi-hole database.  
* Recreate a deleted container.  
* Rebuild the Distrobox.  
* Delete Pi-hole application data.  
* Update Gravity.  
* Change DNS upstreams.

The script must be reviewed before execution because it performs modifications to host configuration and service state.

Do not describe it as read-only.

## **11\. Recovery verification**

After any recovery, verify the following independently.

### **Container**

* Expected container exists.  
* Container is running.  
* Correct image version is in use.  
* Rootless execution is preserved.  
* Privileged mode remains disabled.  
* Expected persistent mounts are present.  
* Expected port bindings are present.

### **DNS**

* DNS responds on TCP port 53\.  
* DNS responds on UDP port 53\.  
* LAN clients can resolve domains.  
* Pi-hole query processing is functioning.  
* No unintended public DNS exposure exists.

### **Administration**

* Web administration is accessible from the trusted LAN.  
* Authentication works.  
* No credentials are exposed in logs or diagnostic output.

### **Persistence**

* Configuration survives a controlled container restart.  
* Local DNS records are present.  
* Custom lists and settings are present.  
* A fresh verified backup can be created.

## **12\. Backup and recovery checklist**

### **Backup**

* Live mount paths verified.  
* Container identity verified.  
* Backup destination verified.  
* Storage capacity checked.  
* Service interruption approved if required.  
* Both persistent data directories copied.  
* Backup metadata recorded.  
* Backup integrity checked.  
* Backup stored independently of live data.

### **Recovery**

* Failure identified.  
* Correct recovery category selected.  
* Backup verified.  
* Current live data preserved where possible.  
* Restore approved.  
* Correct directories restored.  
* Ownership and permissions verified.  
* Container and DNS tested.  
* Administration tested.  
* New backup created after successful recovery.

## **13\. Outstanding items**

| Item | Status |
| ----- | ----- |
| Independent backup destination | Requires confirmation |
| Backup retention policy | Not defined |
| Automated backup schedule | Not configured or approved |
| Backup encryption | Requires policy |
| Restore test | Not documented as completed |
| Pi-hole version compatibility policy | Requires definition |
| API password rotation | Not verified |
| Complete container rebuild procedure | Separate future procedure |

Do not mark a backup strategy as operational until a restore test has succeeded.

## **14\. References**

* Pi-hole Docker documentation: [https\://docs.pi-hole.net/docker/](https://docs.pi-hole.net/docker/)  
* Pi-hole Docker configuration: [https\://docs.pi-hole.net/docker/configuration/](https://docs.pi-hole.net/docker/configuration/)  
* Podman documentation: [https\://docs.podman.io/](https://docs.podman.io/)  
* Project architecture and operations: `pi-hole/docs/Pi-hole on SteamOS — Architecture & Operations.md`  
* Recovery helper: `pi-hole/scripts/pihole-update-recovery.sh`

## **Change history**

| Date | Change |
| ----- | ----- |
| 2026-11-03 | Initial backup and recovery documentation draft based on the documented SteamOS deployment. |


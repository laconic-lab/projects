# Dell Precision M4800 — Disk, Partition & UEFI Inventory

**Document type:** Hardware/storage reference  
**Last evidence update:** 2026-11-18  
**Related operational record:** [EFI Dual-Boot Roadbook](EFI-DUAL-BOOT-ROADBOOK.md)  
**Status:** Updated 2026-11-18 — full LIV-REPAIR-10 disk, partition-table and NVRAM output received.

---

## 1. Purpose and safety boundaries

This document is the reference map for the three storage devices detected in the Dell Precision M4800 during the Linux Mint dual-boot repair.

It records:

- Physical disk identity (model, serial and capacity).
- Observed Linux device names and every detected partition.
- Filesystem, label, UUID and PARTUUID where available.
- EFI System Partitions (ESPs), known EFI loader files and firmware boot entries.
- The last fully verified UEFI boot order.

**Important:** Linux device names such as `/dev/sda`, `/dev/sdb` and `/dev/sdc` are discovery-time names. They can change when disks are enabled, disabled, moved or enumerated differently. Identify a disk by model, serial, capacity and partition GUID—not by `sdX` alone.

### Permanent scope boundaries

- **Kingston:** Linux Mint system disk. Its root, home, swap and EFI partitions are in active use.
- **Crucial:** Windows 11 Pro system disk. Its own independent EFI partition is retained.
- **WDC:** Data disk containing a BitLocker partition. It is not part of the boot repair. Do not mount, unlock, format, repartition or otherwise modify it as part of EFI work.
- Do not overwrite or repurpose either ESP. The Kingston ESP contains historical files as well as the repaired Mint boot files; the Crucial ESP is the independent Windows boot path.

---

## 2. Physical disk register

Latest inventory supplied by the user: **LIV-REPAIR-10, 2026-11-18 04:51:45 UTC**.

| Logical role | Observed device | Model | Serial | Reported capacity | State at inventory |
|---|---|---|---|---:|---|
| Windows system disk | `/dev/sda` | Crucial MX500 `CT500MX500SSD1` | `1811E13386E5` | 465.8 GiB | Detected |
| Data disk | `/dev/sdb` | WDC `WD10JPVX-75JC3T0` | `WX71EA45CJ8N` | 931.5 GiB | Detected; BitLocker partition; not mounted |
| Linux Mint system disk | `/dev/sdc` | Kingston `SKC600MS1024G` | `50026B76872EB687` | 953.9 GiB | Detected; Mint running from it |

The WDC was intended to remain disabled during the staged reintroduction of the Windows disk, but LIV-REPAIR-10 shows that it was visible to Linux. It was not mounted in the supplied inventory. Its presence is documented, not treated as permission to access it. Its partition table is MBR/DOS (disk identifier `0x5626013f`), with one type-7 HPFS/NTFS/exFAT partition; Linux identifies the on-disk content as BitLocker.

---

## 3. Partition inventory — Crucial MX500 (Windows)

**Physical identity:** `CT500MX500SSD1`, serial `1811E13386E5`, 465.8 GiB.  
**Observed Linux device:** `/dev/sda` during LIV-REPAIR-10.

| Partition | Approx. size | Type / filesystem | Label | UUID | PARTUUID | Role |
|---|---:|---|---|---|---|---|
| `/dev/sda1` | 16 MiB | GPT Microsoft Reserved (no filesystem shown) | — | — | `2843e2d6-4ce0-4b6c-b919-a8c143cad3f9` | Windows MSR |
| `/dev/sda2` | 463.9 GiB | NTFS | — | `20A49BD9A49BAFB0` | `eaff03e1-3b3d-4247-9e09-9a4d0c42a616` | Windows OS/data volume |
| `/dev/sda3` | 1 GiB | FAT32 / vfat | `EFI-WIN` | `D2C8-E433` | `775149ef-10c2-4c7b-8192-fe8786b1ad41` | **Windows EFI System Partition** |
| `/dev/sda4` | 880 MiB | NTFS | — | `3C6061836061452C` | `7169d14f-d50f-4d69-a861-64af10365aa4` | Windows recovery partition |

### Crucial EFI details

- The Crucial ESP is partition 3, label `EFI-WIN`, UUID `D2C8-E433`.
- Its PARTUUID, `775149ef-10c2-4c7b-8192-fe8786b1ad41`, exactly matches the partition GUID in firmware entry **Boot0003 — Windows Boot Manager**.
- Windows boot files were previously rebuilt onto this dedicated Crucial ESP using `bcdboot C:\Windows /s S: /f UEFI /v`; Windows reported success and the BCD was verified.
- A prior isolated test with Crucial enabled and Kingston disabled successfully booted Windows. This establishes that the Crucial has an independent working Windows boot path.
- The full LIV-REPAIR-10 report confirms the Crucial partition table and firmware target. A fresh read-only directory listing of this ESP is still pending. Do not infer its present file listing from the partition inventory alone.

Expected Windows loader path recorded in NVRAM:

```
\EFI\Microsoft\Boot\bootmgfw.efi
```

The Crucial ESP must remain the authoritative Windows EFI path. Do not use the historical Microsoft loader found on the Kingston ESP as the final Windows chainload target.

---

## 4. Partition inventory — WDC data disk

**Physical identity:** `WD10JPVX-75JC3T0`, serial `WX71EA45CJ8N`, 931.5 GiB.  
**Observed Linux device:** `/dev/sdb` during LIV-REPAIR-10.

| Partition | Approx. size | Type / filesystem | Label | UUID | PARTUUID | Role |
|---|---:|---|---|---|---|---|
| `/dev/sdb1` | 931.5 GiB | BitLocker | — | Not reported | `5626013f-01` | Encrypted data partition |

- No mountpoint was shown in LIV-REPAIR-10.
- No unlock, mount, filesystem repair, partitioning or write operation is authorized by this inventory.
- Keep this disk out of all Windows EFI and GRUB repair operations.

---

## 5. Partition inventory — Kingston SKC600MS1024G (Linux Mint)

**Physical identity:** `SKC600MS1024G`, serial `50026B76872EB687`, 953.9 GiB.  
**Observed Linux device:** `/dev/sdc` during LIV-REPAIR-10.  
**Earlier repair-session device:** `/dev/sda` while the other disks were disabled.

| Partition | Approx. size | Filesystem | Label | UUID | PARTUUID | Role / mount |
|---|---:|---|---|---|---|---|
| `/dev/sdc1` | 1 GiB | FAT32 / vfat | — | `2CE5-D0E8` | `da38cc52-46f9-4f68-85dd-fc2555c3c0ed` | Kingston ESP; mounted at `/boot/efi` |
| `/dev/sdc2` | 16 GiB | Linux swap | — | `d6475051-4ba4-4aa2-966a-309575fe1d13` | `6108e354-d7b3-4445-886e-29d1685c6ade` | Active swap |
| `/dev/sdc3` | 500 GiB | ext4 | — | `19705670-12b0-4218-b537-1664f375df4c` | `2af4a8a8-e720-483a-a26b-e81fd0eace88` | Mint root; mounted at `/` |
| `/dev/sdc4` | 436.9 GiB | ext4 | — | `7b6ff1ad-f835-4440-966c-d2c147008b2f` | `cc766ad4-92fa-47bc-8652-ff3b348157e9` | Mint home; mounted at `/home` |

The UUIDs and mount roles were confirmed by LIV-REPAIR-09. The device names and PARTUUIDs above reflect the later LIV-REPAIR-10 enumeration.

### Kingston EFI directory register

The Kingston ESP contains a mixture of historical boot material and the repaired Mint boot path. The following directories/files were observed or verified during the repair:

| EFI path | Recorded purpose / status |
|---|---|
| `EFI/ubuntu/` | Repaired Mint/Ubuntu-family signed UEFI boot path |
| `EFI/ubuntu/shimx64.efi` | Loader targeted by Boot0000; successful standalone Mint boot confirmed |
| `EFI/ubuntu/grubx64.efi` | Signed GRUB binary installed during repair |
| `EFI/ubuntu/mmx64.efi` | Supporting MokManager binary |
| `EFI/ubuntu/BOOTX64.CSV` | Firmware loader registration metadata |
| `EFI/ubuntu/grub.cfg` | Small EFI-side GRUB configuration |
| `EFI/GRUB/grubx64.efi` | Historical GRUB loader; targeted by Boot0001; not the preferred repaired path |
| `EFI/Boot/bootx64.efi` | Historical fallback binary; byte-identical to the old Microsoft `bootmgfw.efi` at time of comparison; do not overwrite |
| `EFI/Microsoft/Boot/` | Historical Windows boot files and BCD retained on Kingston; not the final Windows route |
| Root `grub/` | GRUB support/configuration material retained on the Kingston ESP |
| `System Volume Information/` | Existing filesystem metadata directory |

The historical Kingston fallback binary and the Kingston Microsoft loader were byte-identical when checked, SHA-256:

```
d8d85f707b4c1da37642a91bc3860c405e8022a066dafd36348d515ad915ce43
```

This is why the generic fallback path must not be mistaken for the independent Crucial Windows boot path.

### Kingston EFI recovery archive

A verified archive of the Kingston ESP was created before the repair:

```
/media/mint/7b6ff1ad-f835-4440-966c-d2c147008b2f/laco/EFI-RECOVERY-BACKUP/kingston-efi-20261118T035437Z.tar
```

- Archive size: approximately 542 MiB.
- Archive comparison completed without differences; 581 source entries and 581 archive entries (excluding the archive root marker).
- SHA-256: `f724be2e16a11b6ce00ae3b4edb685cb7f169c04dd6085b984dddc4e59566507`.
- This is a same-physical-disk recovery copy, not an independent whole-disk backup. Retain it until dual boot is validated and a separate backup exists.

---

## 6. UEFI firmware boot-entry register

The following entries were present in the full `efibootmgr -v` output from LIV-REPAIR-08 at 04:45:10 UTC, after the successful Mint boot and after permanent boot-order correction.

| Entry | Active flag | Firmware label | Target disk / ESP | Loader / target | Meaning |
|---|---|---|---|---|---|
| `Boot0000` | `*` | Linux Mint (Kingston) | Kingston ESP PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed` | `\EFI\ubuntu\shimx64.efi` | **Preferred, tested Mint entry** |
| `Boot0003` | none in output | Windows Boot Manager | Crucial ESP PARTUUID `775149ef-10c2-4c7b-8192-fe8786b1ad41` | `\EFI\Microsoft\Boot\bootmgfw.efi` | Independent Windows firmware entry |
| `Boot0001` | `*` | grub | Kingston ESP PARTUUID `da38cc52-46f9-4f68-85dd-fc2555c3c0ed` | `\EFI\GRUB\grubx64.efi` | Historical Kingston GRUB entry; retained |
| `Boot000B` | `*` | UEFI: KINGSTON SKC600MS1024G | Kingston device/ESP path | Generic device path ending in `AMBO`; no explicit EFI filename | Generic Kingston firmware device entry |

The active marker `*` is reproduced from the firmware output; it is not a statement that an entry is currently selected or currently executing. `BootCurrent` identifies the entry used for the current boot. LIV-REPAIR-10 adds **Boot000C — UEFI: CT500MX500SSD1**, a generic device entry pointing to the Crucial ESP (same PARTUUID as Boot0003), with no explicit EFI filename.

### Last fully verified permanent BootOrder

```
BootOrder: 0000,0003,0001,000B,000C
```

Meaning:

1. **Boot0000 — Linux Mint (Kingston)** — first priority.
2. **Boot0003 — Windows Boot Manager (Crucial)** — second priority.
3. **Boot0001 — legacy Kingston GRUB** — retained fallback.
4. **Boot000B — generic Kingston device entry** — retained fallback.
5. **Boot000C — generic Crucial device entry** — newly present after Crucial detection; points to Crucial ESP but does not name an EFI loader.

At the time of LIV-REPAIR-08:
- `BootCurrent: 0000`.
- No `BootNext` was shown.
- The order was applied with `efibootmgr -o 0000,0003,0001,000B` and immediately verified with a second full `efibootmgr -v`.

**LIV-REPAIR-10 post-reconnection confirmation:** the complete report confirms `BootCurrent: 0000` and `BootOrder: 0000,0003,0001,000B,000C`. Boot0000 remains first and points to the Kingston Mint shim. Boot0003 remains the Crucial Windows Boot Manager entry. Boot000C is an additional generic Crucial device entry. No BootNext is shown.

### Historical temporary USB entry

During the Live USB repair session, `BootCurrent=000C` identified the Live USB boot. At that point the permanent order was `0003,000B,000C`, and BootNext was set once to `0000` for the first installed-Mint boot. The later permanent Mint-first order superseded that temporary state. Boot000C was not present in the full LIV-REPAIR-08 listing and is not included in the current permanent order.

---

## 7. Mint GRUB configuration and intended dual-boot behaviour

The installed Mint GRUB configuration was verified during the repair:

```
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=10
```

Saved default at LIV-REPAIR-07:

```
saved_entry=gnulinux-simple-19705670-12b0-4218-b537-1664f375df4c
```

This is the Mint root menu entry. The user's intended final behaviour is:

- Display the GRUB menu for 10 seconds.
- Remember the last selected operating system.
- If Windows was selected and Windows performs multiple automatic restarts during updates, keep Windows as the saved default until the user changes the selection.

**Not yet validated:** direct visual confirmation of the menu and timeout, and a final Windows chainload entry pointing to the Crucial ESP. The os-prober result from the repair phase pointed to historical Windows boot files on the Kingston ESP and must not be used as the final Windows menu entry.

---

## 8. Current verification matrix

| Item | Status | Evidence / next requirement |
|---|---|---|
| Kingston standalone Mint boot | **PASS** | User reached installed Mint Cinnamon through Boot0000 |
| Kingston root/home/EFI mounts | **PASS** | LIV-REPAIR-09: `/dev/sda3`, `/dev/sda4`, `/dev/sda1` in the then-current enumeration |
| Mint-first permanent BootOrder | **PASS — last verified** | LIV-REPAIR-08: `0000,0003,0001,000B`; refresh after drive reconnection |
| Crucial disk identity and partitions | **PASS** | LIV-REPAIR-10 model, serial and four-partition inventory |
| Crucial ESP matches Boot0003 | **PASS** | PARTUUID exact match |
| Independent Windows boot | **PASS — prior isolated test** | Crucial enabled, Kingston disabled; Windows booted |
| Crucial ESP current directory listing | Pending | Read-only mount/inspection still required |
| Fresh NVRAM state after disk reconnection | Pending | LIV-REPAIR-10 pasted output omitted firmware section |
| WDC data disk untouched | **No mount shown** | Visible as BitLocker; maintain strict no-touch boundary |
| Mint GRUB menu visual/10-second test | Pending | Configuration verified; visual behaviour not yet reported |
| Windows entry in Mint GRUB using Crucial ESP | Pending | Add explicit chainloader using Crucial ESP PARTUUID |
| Windows via Mint GRUB | Pending | Test only after reviewed entry creation |
| Saved-default behaviour across Windows restarts | Pending | Validate after chainload works |

---

## 9. Safe read-only refresh commands

When updating this document, do not assume the `sdX` names remain unchanged. First collect a new identity-based inventory.

```bash
REPORT="$HOME/Desktop/M4800-storage-efi-refresh.txt"
{
    echo "=== M4800 STORAGE / EFI REFRESH ==="
    date -u
    echo
    echo "=== PHYSICAL DISKS AND PARTITIONS ==="
    lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS
    echo
    echo "=== GPT PARTITION TABLES ==="
    sudo fdisk -l
    echo
    echo "=== UEFI ENTRIES AND ORDER ==="
    sudo efibootmgr -v
    echo
    echo "=== MOUNTED SYSTEM FILESYSTEMS ==="
    findmnt -T /
    findmnt -T /home
    findmnt -T /boot/efi
    echo
    echo "=== REFRESH COMPLETE ==="
} > "$REPORT" 2>&1
echo "Report saved: $REPORT"
cat "$REPORT"
```

For any ESP content inspection, identify the partition by model/serial and PARTUUID first. Mount it read-only and do not run boot repair, `grub-install`, `bcdboot`, formatting, filesystem repair or cleanup as part of an inventory operation.

---

## 10. Hardware reference

Dell's M4800 documentation describes its storage interfaces and supported configurations. The exact drive-bay arrangement in this individual machine should be confirmed physically rather than inferred from the generic specification.

- [Dell Precision M4800 Owner's Manual](https://www.dell.com/support/manuals/en-us/precision-m4800-workstation/precm4800om/technical-specification?guid=guid-915ef715-8d78-4f84-85f6-e409e146c093&lang=en-us)
- [Dell Precision M4800 Technical Specifications](https://i.dell.com/sites/doccontent/shared-content/data-sheets/en/Documents/CSG-EN-XX-ALL-Dell-Precision-M4800-Spec-Sheet.pdf)

---

## 11. Change log

| Date | Event |
|---|---|
| 2026-11-18 | Kingston Mint EFI repaired; standalone Mint boot succeeded (LIV-REPAIR-06) |
| 2026-11-18 | Post-boot NVRAM audit confirmed BootCurrent 0000; permanent order corrected (LIV-REPAIR-07/08) |
| 2026-11-18 | Root, home and EFI mounts verified (LIV-REPAIR-09) |
| 2026-11-18 | Crucial MX500, Kingston and WDC identities and partition layouts captured; full GPT/MBR tables and refreshed UEFI entries confirmed (LIV-REPAIR-10) |

**Maintenance rule:** update this inventory only from fresh command output. Preserve old identifiers and dates when device names or firmware order change; do not silently rewrite historical evidence.


### LIV-REPAIR-10 complete report — partition-table and NVRAM details

The complete user-provided report resolves the earlier partial-report caveat.

- Crucial `/dev/sda`: GPT disk GUID `23A3A82A-FD2B-11EF-A09E-9943B1E44900`; four partitions and sector ranges agree with the inventory.
- WDC `/dev/sdb`: DOS/MBR disk identifier `0x5626013f`; one type-7 partition spanning the data disk. Linux reports its content as BitLocker. No mountpoint.
- Kingston `/dev/sdc`: GPT disk GUID `CF840EE5-6114-4F08-A3E9-E1015E2CF245`; four partitions. `fdisk` displays unusual GPT type descriptions (“Linux root verity (S390X)”) for the two ext4 partitions, while `lsblk` and the mounted system identify them as ext4 root and home. Treat this as a GPT type-label observation, not evidence that the filesystems are S390X or verity; do not change partition type GUIDs during this repair.
- Refreshed firmware: `BootCurrent=0000`; `BootOrder=0000,0003,0001,000B,000C`.
- Boot000C is newly visible: `UEFI: CT500MX500SSD1`, generic Crucial device entry pointing to Crucial ESP PARTUUID `775149ef-10c2-4c7b-8192-fe8786b1ad41`. It is not the same as the explicit Windows loader entry Boot0003.
- Boot0000 Mint, Boot0001 historical grub, Boot0003 Windows Boot Manager, and Boot000B generic Kingston entry remain present.

No partitions were mounted or modified by this inventory. Next operation remains a read-only inspection of the Crucial ESP, using its PARTUUID to identify it; WDC remains out of scope.

# 01 — Investigation summary

Snapshot: 2026-11-01. Machine: Dell Precision M4800, Quadro K2100M (Kepler), Linux Mint 22.1 / Noble, running kernel `6.8.0-147-generic`.

## Established findings
1. Loaded NVIDIA driver is `470.256.02`.
2. Active-kernel module path: `/lib/modules/6.8.0-147-generic/updates/dkms/nvidia.ko.zst`.
3. DKMS:
   - `nvidia/470.256.02`, `6.8.0-147-generic`: installed
   - `nvidia/580.178.04`, `6.8.0-139-generic`: installed
   - `nvidia/580.178.04`, `6.8.0-147-generic`: built
   - `virtualbox/7.0.16`, `6.8.0-147-generic`: installed
4. APT 470-server → 535 → 580 transitional dependency chain was observed for both driver and DKMS packages.
5. APT autoremove proposed no removals; the dependencies explain why this is not a clean package state.
6. Main generic library links resolved to 470: CUDA, NVML, OpenCL and PTX JIT compiler.
7. Some 580 files remain, including `libcudadebugger.so.580.178.04` and `libnvidia-nvvm70.so.4`.
8. `libnvidia-nvvm.so.4.0.0` is not dpkg-owned but is recorded in `/var/lib/nvidia/log`; its timestamp matches the October 20 runfile activity. This is association evidence, not proof of the exact creating action.
9. NVIDIA installer database contains historical 580 and later 470-era records; do not treat its header as a clean single-version inventory.

## Not performed
No package install/remove/purge, DKMS removal/rebuild, runfile uninstaller, library-link change, initramfs update, boot change, or update-script modification.

## Remaining work
- Design and simulate a safe package transition.
- Account for runfile/APT DKMS identity overlap.
- Account for generic library links owned by the 580 package but currently resolving to 470 targets.
- Remove obsolete 580 DKMS registrations only through a reviewed plan.
- Verify 470 after correction and reboot.
- Investigate S3 resume separately.
